//
//  Elevation.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 22/03/2025.
//

import Foundation
import simd
import Combine
import Metal

class Elevation {
    var heightMap: [Float]
    let tileCount: Int
    var renderControl: RenderControl
    private var noiseGenerator: SimplexNoise

    // Metal properties
    private var metalDevice: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var continentMaskPipeline: MTLComputePipelineState!
    private var smoothingPipeline: MTLComputePipelineState!
    private var elevationPipeline: MTLComputePipelineState!
    private var permTableBuffer: MTLBuffer!

    // Persistent buffers for better performance
    private var positionsBuffer: MTLBuffer?
    private var tilePositions: [SIMD3<Float>]?
    private var continentMaskBuffer: MTLBuffer?
    private var smoothBuffer1: MTLBuffer?
    private var smoothBuffer2: MTLBuffer?
    private var elevationBuffer: MTLBuffer?
    private var finalSmoothBuffer: MTLBuffer?

    // Constants for elevation distribution
    private var seaLevel: Float = 0.0        // Zero is sea level
    private var deepOceanStartRatio: Float = 0.8 // Percentage into the ocean range where deep ocean starts
    private var oceanRatio: Float = 0.65         // Percentage of planet that should be ocean
    private var deepOceanLevel: Float = -0.8 // Lowest point in the ocean
    private var highPeakLevel: Float = 0.8    // Highest mountain peaks1

    // New parameter to control the scale/frequency of continents
    var continentScale: Float = 2.5

    init(tiles: Int, seed: Int = Int.random(in: 0..<10000), renderControl: RenderControl) {
        self.tileCount = tiles
        self.heightMap = [Float](repeating: 0, count: tiles)
        self.noiseGenerator = SimplexNoise(seed: seed)
        self.renderControl = renderControl
        self.continentScale = renderControl.elevationController[0]
        self.tilePositions = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: tiles)

        setupMetal(seed: seed)
    }

    func reseed(seed: Int, newValues: [Float], mesh: Mesh) {
        self.continentScale = newValues[0]
        self.oceanRatio = newValues[1]
        
        setupMetal(seed: seed)
        self.noiseGenerator = SimplexNoise(seed: seed)
        
        generateElevation(from: mesh)
    }
    
    private func setupMetal(seed: Int) {
        // Get the default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.metalDevice = device

        // Create a command queue
        guard let queue = device.makeCommandQueue() else {
            fatalError("Could not create Metal command queue")
        }
        self.commandQueue = queue

        // Create permutation table buffer for noise generation
        var permArray = [Int](repeating: 0, count: 512)
        srand48(seed)

        // Generate the same permutation table as the CPU version
        var p = [Int](0..<256)
        for i in 0..<256 {
            let j = Int(drand48() * Double(256 - i)) + i
            p.swapAt(i, j)
        }

        for i in 0..<256 {
            permArray[i] = p[i]
            permArray[i + 256] = p[i]
        }

        // Create buffer with the permutation table
        self.permTableBuffer = device.makeBuffer(bytes: permArray,
                                                length: MemoryLayout<Int>.stride * permArray.count,
                                                options: [])

        // Load the Metal library
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default Metal library")
        }

        // Create the compute pipelines
        do {
            let continentMaskFunction = library.makeFunction(name: "generateContinentMask")!
            self.continentMaskPipeline = try device.makeComputePipelineState(function: continentMaskFunction)

            let smoothingFunction = library.makeFunction(name: "smoothValues")!
            self.smoothingPipeline = try device.makeComputePipelineState(function: smoothingFunction)

            let elevationFunction = library.makeFunction(name: "generateElevation")!
            self.elevationPipeline = try device.makeComputePipelineState(function: elevationFunction)
        } catch {
            fatalError("Failed to create compute pipeline: \(error)")
        }
        
        // Create persistent buffers
        createPersistentBuffers()
    }

    private func createPersistentBuffers() {
        // Create buffers only once for reuse
        if continentMaskBuffer == nil {
            continentMaskBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * tileCount, options: [])
        }
        
        if smoothBuffer1 == nil {
            smoothBuffer1 = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * tileCount, options: [])
        }
        
        if smoothBuffer2 == nil {
            smoothBuffer2 = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * tileCount, options: [])
        }
        
        if elevationBuffer == nil {
            elevationBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * tileCount, options: [])
        }
        
        if finalSmoothBuffer == nil {
            finalSmoothBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * tileCount, options: [])
        }
    }

    func modifyTerrain(newValues: [Float], mesh: Mesh) {
        self.continentScale = newValues[0]
        self.oceanRatio = newValues[1]

        generateElevation(from: mesh)
    }

    func generateElevationGPU(from mesh: Mesh) {
        var oceanWorld: Bool = oceanRatio >= 1.0

        // Always recalculate tile positions
        tilePositions = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: tileCount)

        for i in 0..<tileCount {
            let centerVertex = mesh.getVertex(forVertexIndex: mesh.tileIndex[i])
            let normalizedPosition = centerVertex.position.normalized()
            tilePositions![i] = normalizedPosition
        }

        // Create or update the positions buffer
        if positionsBuffer == nil {
            positionsBuffer = metalDevice.makeBuffer(bytes: tilePositions!,
                                                    length: MemoryLayout<SIMD3<Float>>.stride * tileCount,
                                                    options: [])
        } else {
            // Update the existing buffer with new data
            positionsBuffer?.contents().copyMemory(from: tilePositions!, byteCount: MemoryLayout<SIMD3<Float>>.stride * tileCount)
        }
        
        createPersistentBuffers()

        // Create an autorelease pool for temporary Metal objects
        autoreleasepool {
            // Create a single command buffer for all operations
            let commandBuffer = commandQueue.makeCommandBuffer()!
            
            // STEP 1: Generate continent mask
            let maskEncoder = commandBuffer.makeComputeCommandEncoder()!
            maskEncoder.setComputePipelineState(continentMaskPipeline)
            maskEncoder.setBuffer(positionsBuffer, offset: 0, index: 0)
            maskEncoder.setBuffer(continentMaskBuffer, offset: 0, index: 1)
            maskEncoder.setBuffer(permTableBuffer, offset: 0, index: 2)
            var scale = continentScale
            maskEncoder.setBytes(&scale, length: MemoryLayout<Float>.size, index: 3)
            var count = UInt32(tileCount)
            maskEncoder.setBytes(&count, length: MemoryLayout<UInt32>.size, index: 4)

            let threadsPerGrid = MTLSizeMake(tileCount, 1, 1)
            let threadsPerThreadgroup = MTLSizeMake(min(continentMaskPipeline.maxTotalThreadsPerThreadgroup, tileCount), 1, 1)
            maskEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            maskEncoder.endEncoding()
            
            // STEP 2: Apply smoothing iterations to continent mask
            var inputBuffer = continentMaskBuffer!
            var outputBuffer = smoothBuffer1!
            
            for i in 0..<3 {
                let smoothEncoder = commandBuffer.makeComputeCommandEncoder()!
                smoothEncoder.setComputePipelineState(smoothingPipeline)
                smoothEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
                smoothEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
                smoothEncoder.setBuffer(positionsBuffer, offset: 0, index: 2)
                var radius: Float = 0.2
                smoothEncoder.setBytes(&radius, length: MemoryLayout<Float>.size, index: 3)
                smoothEncoder.setBytes(&count, length: MemoryLayout<UInt32>.size, index: 4)
                
                // Allocate threadgroup memory for the optimized smoothing kernel
                let threadgroupMemoryLength = min(smoothingPipeline.maxTotalThreadsPerThreadgroup, tileCount)
                let posSharedMemSize = (MemoryLayout<Float>.stride * 3 * threadgroupMemoryLength + 15) & ~15
                let valSharedMemSize = (MemoryLayout<Float>.stride * 3 * threadgroupMemoryLength + 15) & ~15
                
                smoothEncoder.setThreadgroupMemoryLength(posSharedMemSize, index: 0)
                smoothEncoder.setThreadgroupMemoryLength(valSharedMemSize, index: 1)
                
                smoothEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
                smoothEncoder.endEncoding()
                
                // Swap buffers for next iteration
                let temp = inputBuffer
                inputBuffer = outputBuffer
                outputBuffer = (i == 1) ? smoothBuffer2! : temp
            }
            
            // Set up barrier to ensure smoothing is complete before reading values for threshold
            let barrierEncoder = commandBuffer.makeBlitCommandEncoder()!
            barrierEncoder.endEncoding()
            
            commandBuffer.commit()
            
            // Wait only at this point, after smoothing
            commandBuffer.waitUntilCompleted()
            
            // Calculate ocean threshold from smoothed continent mask
            var continentMaskFinal = [Float](repeating: 0, count: tileCount)
            let finalMaskPtr = inputBuffer.contents().bindMemory(to: Float.self, capacity: tileCount)
            for i in 0..<tileCount {
                continentMaskFinal[i] = finalMaskPtr[i]
            }

            let sortedElevations = continentMaskFinal.sorted()
            let thresholdIndex = Int(Float(tileCount) * oceanRatio)
            var oceanThreshold = thresholdIndex < sortedElevations.count ? sortedElevations[thresholdIndex] : 0.5
            
            // Create new command buffer for the rest of the work
            let finalCommandBuffer = commandQueue.makeCommandBuffer()!
            
            // STEP 3: Final elevation generation
            let elevEncoder = finalCommandBuffer.makeComputeCommandEncoder()!
            elevEncoder.setComputePipelineState(elevationPipeline)
            elevEncoder.setBuffer(positionsBuffer, offset: 0, index: 0)
            elevEncoder.setBuffer(inputBuffer, offset: 0, index: 1) // Final smoothed continent mask
            elevEncoder.setBuffer(elevationBuffer, offset: 0, index: 2)
            elevEncoder.setBuffer(permTableBuffer, offset: 0, index: 3)

            elevEncoder.setBytes(&oceanThreshold, length: MemoryLayout<Float>.size, index: 4)
            elevEncoder.setBytes(&seaLevel, length: MemoryLayout<Float>.size, index: 5)
            elevEncoder.setBytes(&highPeakLevel, length: MemoryLayout<Float>.size, index: 6)
            elevEncoder.setBytes(&deepOceanLevel, length: MemoryLayout<Float>.size, index: 7)
            elevEncoder.setBytes(&deepOceanStartRatio, length: MemoryLayout<Float>.size, index: 8)
            elevEncoder.setBytes(&oceanWorld, length: MemoryLayout<Bool>.size, index: 9)
            elevEncoder.setBytes(&count, length: MemoryLayout<UInt32>.size, index: 10)

            elevEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            elevEncoder.endEncoding()
            
            // Apply final smoothing
            let smoothEncoderFinal = finalCommandBuffer.makeComputeCommandEncoder()!
            smoothEncoderFinal.setComputePipelineState(smoothingPipeline)
            smoothEncoderFinal.setBuffer(elevationBuffer, offset: 0, index: 0)
            smoothEncoderFinal.setBuffer(finalSmoothBuffer, offset: 0, index: 1)
            smoothEncoderFinal.setBuffer(positionsBuffer, offset: 0, index: 2)
            var finalRadius: Float = 0.05
            smoothEncoderFinal.setBytes(&finalRadius, length: MemoryLayout<Float>.size, index: 3)
            smoothEncoderFinal.setBytes(&count, length: MemoryLayout<UInt32>.size, index: 4)
            
            let threadgroupMemoryLength = min(smoothingPipeline.maxTotalThreadsPerThreadgroup, tileCount)
            let posSharedMemSize = (MemoryLayout<Float>.stride * 3 * threadgroupMemoryLength + 15) & ~15
            let valSharedMemSize = (MemoryLayout<Float>.stride * 3 * threadgroupMemoryLength + 15) & ~15
            
            smoothEncoderFinal.setThreadgroupMemoryLength(posSharedMemSize, index: 0)
            smoothEncoderFinal.setThreadgroupMemoryLength(valSharedMemSize, index: 1)

            smoothEncoderFinal.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            smoothEncoderFinal.endEncoding()

            finalCommandBuffer.commit()
            finalCommandBuffer.waitUntilCompleted()
            
            let finalElevationPtr = finalSmoothBuffer!.contents().bindMemory(to: Float.self, capacity: tileCount)
            for i in 0..<tileCount {
                heightMap[i] = finalElevationPtr[i]
            }
            
        } // end autoreleasepool
    }

    func generateElevationCPU(from mesh: Mesh) {
        let oceanWorld: Bool = oceanRatio >= 1.0
        
        // Store tile center positions for later use
        var tilePositions = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: tileCount)

        // First pass: Generate continent masks with values in 0-1 range
        var rawContinentMask = [Float](repeating: 0, count: tileCount)

        for i in 0..<tileCount {
            let centerVertex = mesh.getVertex(forVertexIndex: mesh.tileIndex[i])
            let pos = centerVertex.position.normalized()
            tilePositions[i] = pos

            // Generate large-scale continent shapes (very low frequency)
            var continentValue: Float = 0
            var amplitude: Float = 1.0
            let persistence: Float = 0.5
            let continentFrequencyBase: Float = 0.5 // Base lower frequency
            let continentFrequency = continentFrequencyBase * continentScale // Apply the scale

            // Use 3 octaves for continents - fewer octaves = larger features
            for octave in 0..<3 {
                let freq = continentFrequency * pow(2.0, Float(octave))
                let noiseValue = sampleSphericalNoise(at: pos * freq)
                continentValue += noiseValue * amplitude
                amplitude *= persistence
            }

            // Normalize to 0-1
            continentValue = (continentValue + 1.0) * 0.5

            // Make continents more distinct with a curve
            continentValue = pow(continentValue, 1.2)

            rawContinentMask[i] = continentValue
        }

        // Smooth the continent mask
        let continentMask = spatialSmoothing(values: rawContinentMask, positions: tilePositions, radius: 0.2, iterations: 3)

        // Find threshold value that gives us desired ocean ratio
        let sortedElevations = continentMask.sorted()
        let thresholdIndex = Int(Float(tileCount) * oceanRatio)
        let oceanThreshold = thresholdIndex < sortedElevations.count ? sortedElevations[thresholdIndex] : 0.5

        // Second pass: Generate detailed terrain features with proper elevation range
        for i in 0..<tileCount {
            let pos = tilePositions[i]
            let continentValue = continentMask[i]

            // Determine if this is land or ocean
            let isLand = continentValue > oceanThreshold

            var elevation: Float

            if isLand && !oceanWorld{
                // Land: Scale from sea level (0.0) up to mountain peaks (highPeakLevel)

                // How far above threshold are we (0-1 range)
                let landRatio = (continentValue - oceanThreshold) / (1.0 - oceanThreshold)

                // Generate detailed land terrain
                let detailNoise = generateLandTerrain(at: pos)

                // Combine base elevation with details
                // Higher base elevation = higher mountains
                elevation = landRatio * highPeakLevel * 0.7 + detailNoise * highPeakLevel * 0.3

                // Add mountains near coastlines (modified logic)
                let coastalDistance = abs(continentValue - oceanThreshold) * 15.0
                if coastalDistance < 1.0 {
                    let mountainFactor = sin(coastalDistance * Float.pi).clamped(to: 0...1) // Ensure factor is not negative
                    let mountainNoise = sampleSphericalNoise(at: pos * 3.0 + SIMD3<Float>(1.5, 2.3, 3.1)) * 0.5 + 0.5 // Normalize noise to 0-1
                    // Blend mountain noise with existing elevation
                    elevation += mountainFactor * mountainNoise * highPeakLevel * 0.6 * (1.0 - landRatio * 0.5) // Reduce mountain height further inland
                }

                // Ensure minimum land elevation is at sea level
                elevation = max(seaLevel, elevation)
            } else {
                // Ocean: Scale from ocean threshold (0.0) down to deep ocean (deepOceanLevel)

                // How far below threshold are we (0-1 range)
                let oceanRatio = (oceanThreshold - continentValue) / oceanThreshold

                // Generate ocean floor terrain
                let oceanFloorNoise = generateOceanTerrain(at: pos)

                // Base ocean depth
                elevation = -oceanRatio * abs(deepOceanLevel) * 0.7 - oceanFloorNoise * abs(deepOceanLevel) * 0.3

                // Add trenches in deeper ocean areas
                // Deep ocean starts when oceanRatio is above deepOceanStartRatio
                if oceanRatio > deepOceanStartRatio {
                    let trenchNoise = sampleSphericalNoise(at: pos * 2.0 + SIMD3<Float>(3.7, 1.9, 2.6))
                    if trenchNoise > 0.6 { // Slightly lower threshold for trenches
                        let trenchFactor = (trenchNoise - 0.6) / 0.4 // Adjust factor range
                        elevation -= trenchFactor * abs(deepOceanLevel) * 0.6 // Deeper trenches
                    }
                }

                // Ensure maximum ocean elevation is just below sea level
                elevation = min(seaLevel - 0.01, elevation)
            }

            // Store the final elevation
            heightMap[i] = elevation
        }

        // Apply final smoothing to reduce artifacts
        heightMap = spatialSmoothing(values: heightMap, positions: tilePositions, radius: 0.05, iterations: 1)
    }
    
    func generateElevation(from mesh: Mesh) {
        #if targetEnvironment(simulator)
            print("Running in Simulator – using CPU generation")
            generateElevationCPU(from: mesh)
        #else
            print("Running on real device – using GPU generation")
            generateElevationGPU(from: mesh)
        #endif
    }

    private func printElevationStats() {
        let sorted = heightMap.sorted()
        let min = sorted.first ?? 0
        let max = sorted.last ?? 0
        let median = sorted[sorted.count/2]
        let q1 = sorted[sorted.count/4]
        let q3 = sorted[sorted.count*3/4]

        print("Elevation stats:")
        print("  Range: \(min) to \(max)")
        print("  Quartiles: \(q1) / \(median) / \(q3)")

        // Count distribution
        var deepOcean = 0, ocean = 0, shallows = 0, land = 0, hills = 0, mountains = 0, peaks = 0

        for h in heightMap {
            if h < deepOceanLevel + 0.1 { deepOcean += 1 } // Adjusted threshold
            else if h < -0.1 { ocean += 1 }
            else if h < 0.0 { shallows += 1 }
            else if h < 0.2 { land += 1 }
            else if h < 0.4 { hills += 1 }
            else if h < 0.7 { mountains += 1 }
            else { peaks += 1 }
        }

        print("  Distribution:")
        print("    Deep ocean: \(deepOcean) (\(Float(deepOcean)/Float(tileCount)*100)%)")
        print("    Ocean: \(ocean) (\(Float(ocean)/Float(tileCount)*100)%)")
        print("    Shallows: \(shallows) (\(Float(shallows)/Float(tileCount)*100)%)")
        print("    Land: \(land) (\(Float(land)/Float(tileCount)*100)%)")
        print("    Hills: \(hills) (\(Float(hills)/Float(tileCount)*100)%)")
        print("    Mountains: \(mountains) (\(Float(mountains)/Float(tileCount)*100)%)")
        print("    Peaks: \(peaks) (\(Float(peaks)/Float(tileCount)*100)%)")
    }

    // Generate detailed terrain for land areas
    private func generateLandTerrain(at pos: SIMD3<Float>) -> Float {
        var elevation: Float = 0
        var amplitude: Float = 1.0
        var frequency: Float = 2.0
        let persistence: Float = 0.5
        let octaves = 6
        var totalAmplitude: Float = 0

        for _ in 0..<octaves {
            let noiseValue = sampleSphericalNoise(at: pos * frequency)
            elevation += noiseValue * amplitude
            totalAmplitude += amplitude

            amplitude *= persistence
            frequency *= 2.0
        }

        // Normalize
        elevation = (elevation / totalAmplitude + 1.0) * 0.5

        // Add more variation to land (steeper mountains)
        elevation = pow(elevation, 1.2)

        return elevation
    }

    // Generate detailed terrain for ocean areas
    private func generateOceanTerrain(at pos: SIMD3<Float>) -> Float {
        var elevation: Float = 0
        var amplitude: Float = 0.7 // Lower amplitude for smoother ocean floor
        var frequency: Float = 1.5
        let persistence: Float = 0.45
        let octaves = 4 // Fewer octaves for smoother results
        var totalAmplitude: Float = 0

        for _ in 0..<octaves {
            let noiseValue = sampleSphericalNoise(at: pos * frequency)
            elevation += noiseValue * amplitude
            totalAmplitude += amplitude

            amplitude *= persistence
            frequency *= 2.0
        }

        // Normalize
        elevation = (elevation / totalAmplitude + 1.0) * 0.5

        // Make ocean floor smoother
        return elevation * 0.8
    }

    // Sample noise at a point on the sphere's surface
    private func sampleSphericalNoise(at point: SIMD3<Float>) -> Float {
        return noiseGenerator.noise(x: point.x, y: point.y, z: point.z)
    }

    // Smooth values spatially with multiple iterations
    private func spatialSmoothing(values: [Float], positions: [SIMD3<Float>], radius: Float, iterations: Int) -> [Float] {
        var result = values

        for _ in 0..<iterations {
            let original = result

            for i in 0..<tileCount {
                let pos = positions[i]
                var totalWeight: Float = 1.0
                var weightedSum: Float = original[i]

                // Sample a subset of points to avoid O(n²) complexity
                let sampleStep = max(1, tileCount / 200)
                for j in stride(from: 0, to: tileCount, by: sampleStep) {
                    if j != i {
                        let dist = length(pos - positions[j])
                        if dist < radius {
                            let weight = 1.0 - (dist / radius)
                            weightedSum += original[j] * weight
                            totalWeight += weight
                        }
                    }
                }

                result[i] = weightedSum / totalWeight
            }
        }

        return result
    }
}

// Simplex Noise implementation
class SimplexNoise {
    private var perm = [Int](repeating: 0, count: 512)
    private let grad3: [[Float]] = [
        [1,1,0], [-1,1,0], [1,-1,0], [-1,-1,0],
        [1,0,1], [-1,0,1], [1,0,-1], [-1,0,-1],
        [0,1,1], [0,-1,1], [0,1,-1], [0,-1,-1]
    ]

    init(seed: Int) {
        srand48(seed)

        // Initialize permutation table
        var p = [Int](0..<256)
        for i in 0..<256 {
            let j = Int(drand48() * Double(256 - i)) + i
            p.swapAt(i, j)
        }

        // Extend with a copy
        for i in 0..<256 {
            perm[i] = p[i]
            perm[i + 256] = p[i]
        }
    }

    func noise(x: Float, y: Float, z: Float) -> Float {
        // Find unit grid cell containing the point
        var i = Int(floor(x)) as Int
        var j = Int(floor(y)) as Int
        var k = Int(floor(z)) as Int

        // Wrap around to fit indices in the perm array
        i &= 255
        j &= 255
        k &= 255

        // Calculate offsets from the corner
        let xf = x - floor(x)
        let yf = y - floor(y)
        let zf = z - floor(z)

        // Hash function
        let hash = { (n: Int) -> Int in
            return self.perm[n & 511]
        }

        // Gradients at the 12 vertices of the cube
        let p = perm
        let g = grad3

        let gi000 = hash(p[i + 0] + j + 0 + k + 0) % 12
        let gi001 = hash(p[i + 0] + j + 0 + k + 1) % 12
        let gi010 = hash(p[i + 0] + j + 1 + k + 0) % 12
        let gi011 = hash(p[i + 0] + j + 1 + k + 1) % 12
        let gi100 = hash(p[i + 1] + j + 0 + k + 0) % 12
        let gi101 = hash(p[i + 1] + j + 0 + k + 1) % 12
        let gi110 = hash(p[i + 1] + j + 1 + k + 0) % 12
        let gi111 = hash(p[i + 1] + j + 1 + k + 1) % 12

        // Calculate dot product of offset vector and gradient vector
        let n000 = g[gi000][0] * xf + g[gi000][1] * yf + g[gi000][2] * zf
        let n100 = g[gi100][0] * (xf - 1) + g[gi100][1] * yf + g[gi100][2] * zf
        let n010 = g[gi010][0] * xf + g[gi010][1] * (yf - 1) + g[gi010][2] * zf
        let n001 = g[gi001][0] * xf + g[gi001][1] * yf + g[gi001][2] * (zf - 1)
        let n110 = g[gi110][0] * (xf - 1) + g[gi110][1] * (yf - 1) + g[gi110][2] * zf
        let n011 = g[gi011][0] * xf + g[gi011][1] * (yf - 1) + g[gi011][2] * (zf - 1)
        let n101 = g[gi101][0] * (xf - 1) + g[gi101][1] * yf + g[gi101][2] * (zf - 1)
        let n111 = g[gi111][0] * (xf - 1) + g[gi111][1] * (yf - 1) + g[gi111][2] * (zf - 1)

        // Compute fade curves for each of x, y, z
        let u = fade(t: xf)
        let v = fade(t: yf)
        let w = fade(t: zf)

        // Interpolate along x
        let nx00 = lerp(t: u, a: n000, b: n100)
        let nx01 = lerp(t: u, a: n001, b: n101)
        let nx10 = lerp(t: u, a: n010, b: n110)
        let nx11 = lerp(t: u, a: n011, b: n111)

        // Interpolate along y
        let nxy0 = lerp(t: v, a: nx00, b: nx10)
        let nxy1 = lerp(t: v, a: nx01, b: nx11)

        // Interpolate along z
        let nxyz = lerp(t: w, a: nxy0, b: nxy1)

        return nxyz // Returns value in range [-1, 1]
    }

    private func fade(t: Float) -> Float {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    private func lerp(t: Float, a: Float, b: Float) -> Float {
        return a + t * (b - a)
    }
}

extension SIMD3 where Scalar == Float {
    func normalized() -> SIMD3<Float> {
        let len = sqrt(x*x + y*y + z*z)
        return len > 0 ? self / len : self
    }
}

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
