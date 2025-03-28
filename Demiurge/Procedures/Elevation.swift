//
//  Elevation.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 22/03/2025.
//

import Foundation
import MetalKit

class Elevation {
    var heightMap: [Float]
    let tileCount: Int
    private var noiseGenerator: SimplexNoise
    
    // Constants for elevation distribution
    private let seaLevel: Float = 0.0        // Zero is sea level
    private let oceanRatio: Float = 0.65     // Percentage of planet that should be ocean
    private let deepOceanLevel: Float = -0.7 // Lowest point in the ocean
    private let highPeakLevel: Float = 0.8   // Highest mountain peaks
    
    init(tiles: Int, seed: Int = Int.random(in: 0..<10000)) {
        self.tileCount = tiles
        self.heightMap = [Float](repeating: 0, count: tiles)
        self.noiseGenerator = SimplexNoise(seed: seed)
    }

    func generateElevation(from mesh: Mesh) {
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
            let continentFrequency: Float = 0.5  // Lower frequency for larger continents
            
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
            
            if isLand {
                // Land: Scale from sea level (0.0) up to mountain peaks (highPeakLevel)
                
                // How far above threshold are we (0-1 range)
                let landRatio = (continentValue - oceanThreshold) / (1.0 - oceanThreshold)
                
                // Generate detailed land terrain
                let detailNoise = generateLandTerrain(at: pos)
                
                // Combine base elevation with details
                // Higher base elevation = higher mountains
                elevation = landRatio * highPeakLevel * 0.7 + detailNoise * highPeakLevel * 0.3
                
                // Add mountains near coastlines
                let coastalDistance = abs(continentValue - oceanThreshold) * 15.0
                if coastalDistance < 1.0 {
                    // Mountain range factor (strongest at some distance from coast)
                    let mountainFactor = sin(coastalDistance * Float.pi)
                    let mountainNoise = sampleSphericalNoise(at: pos * 3.0 + SIMD3<Float>(1.5, 2.3, 3.1))
                    // Add some mountains along coastlines
                    elevation += mountainFactor * mountainNoise * highPeakLevel * 0.4
                }
                
                // Ensure minimum land elevation is at sea level
                elevation = max(seaLevel, elevation)
            } else {
                // Ocean: Scale from ocean threshold (0.0) down to deep ocean (deepOceanLevel)
                
                // How far below threshold are we (0-1 range)
                let oceanRatio = (oceanThreshold - continentValue) / oceanThreshold
                
                // Generate ocean floor terrain
                let oceanFloorNoise = generateOceanTerrain(at: pos)
                
                // Combine with base elevation and scale to ocean depth
                elevation = -oceanRatio * abs(deepOceanLevel) * 0.7 - oceanFloorNoise * abs(deepOceanLevel) * 0.3
                
                // Add trenches in some places
                let trenchNoise = sampleSphericalNoise(at: pos * 2.0 + SIMD3<Float>(3.7, 1.9, 2.6))
                if trenchNoise > 0.7 {
                    let trenchFactor = (trenchNoise - 0.7) / 0.3
                    elevation -= trenchFactor * abs(deepOceanLevel) * 0.5
                }
                
                // Ensure maximum ocean elevation is just below sea level
                elevation = min(seaLevel - 0.01, elevation)
            }
            
            // Store the final elevation
            heightMap[i] = elevation
        }
        
        // Apply final smoothing to reduce artifacts
        heightMap = spatialSmoothing(values: heightMap, positions: tilePositions, radius: 0.05, iterations: 1)
        
        // Print distribution stats for debugging
        printElevationStats()
    }
    
    private func printElevationStats() {
        let sorted = heightMap.sorted()
        let min = sorted.first ?? 0
        let max = sorted.last ?? 0
        let median = sorted[sorted.count/2]
        let q1 = sorted[sorted.count/4]
        let q3 = sorted[sorted.count*3/4]
        
        print("Elevation stats:")
        print("  Range: \(min) to \(max)")
        print("  Quartiles: \(q1) / \(median) / \(q3)")
        
        // Count distribution
        var deepOcean = 0, ocean = 0, shallows = 0, land = 0, hills = 0, mountains = 0, peaks = 0
        
        for h in heightMap {
            if h < -0.5 { deepOcean += 1 }
            else if h < -0.1 { ocean += 1 }
            else if h < 0.0 { shallows += 1 }
            else if h < 0.2 { land += 1 }
            else if h < 0.4 { hills += 1 }
            else if h < 0.7 { mountains += 1 }
            else { peaks += 1 }
        }
        
        print("  Distribution:")
        print("    Deep ocean: \(deepOcean) (\(Float(deepOcean)/Float(tileCount)*100)%)")
        print("    Ocean: \(ocean) (\(Float(ocean)/Float(tileCount)*100)%)")
        print("    Shallows: \(shallows) (\(Float(shallows)/Float(tileCount)*100)%)")
        print("    Land: \(land) (\(Float(land)/Float(tileCount)*100)%)")
        print("    Hills: \(hills) (\(Float(hills)/Float(tileCount)*100)%)")
        print("    Mountains: \(mountains) (\(Float(mountains)/Float(tileCount)*100)%)")
        print("    Peaks: \(peaks) (\(Float(peaks)/Float(tileCount)*100)%)")
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
        var amplitude: Float = 0.7  // Lower amplitude for smoother ocean floor
        var frequency: Float = 1.5
        let persistence: Float = 0.45
        let octaves = 4  // Fewer octaves for smoother results
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
        // Better noise function using multiple frequencies and offsets
        // This helps break up obvious patterns
        
        // Use multiple noise samples with different frequencies and phases
        let n1 = sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453
        let n2 = sin(x * 39.346 + y * 11.135 + z * 83.751) * 28563.1257
        let n3 = sin(x * 73.156 + y * 52.619 + z * 17.983) * 18743.9382
        
        let combinedNoise = sin(n1 + n2 + n3)
        return combinedNoise  // Returns value in range [-1, 1]
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
