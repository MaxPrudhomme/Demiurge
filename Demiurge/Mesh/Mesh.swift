//
//  Mesh.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 17/03/2025.
//

import MetalKit

struct Vertex {
    var position: SIMD3<Float>
}

class Mesh: ObservableObject {
    var vertexBuffer: MTLBuffer
    var vertexCount: Int
    
    var faceIndexBuffer: MTLBuffer
    var faceIndexCount: Int
    
    @Published var tileIndex: [Int]
    var tileCount: Int
    
    var edgeIndexBuffer: MTLBuffer
    var edgeIndexCount: Int
    
    var colorBuffer: MTLBuffer
    
    init(device: MTLDevice, vertices: [Vertex], faceIndices: [UInt32], edgeIndices: [UInt32], tileIndex: [Int], colors: [SIMD4<Float>], subdivisions: Int = 0, meshURL: URL? = nil) {
        var finalVertices = vertices
        var finalFaceIndices = faceIndices
        var finalEdgeIndices = edgeIndices
        var finalTileIndex = tileIndex
        var finalColors = colors
        
        if let url = meshURL {
            let loadedData = Mesh.loadMeshData(from: url)
            finalVertices = loadedData.vertices
            finalFaceIndices = loadedData.faceIndices
            finalEdgeIndices = loadedData.edgeIndices
            finalTileIndex = loadedData.tileIndex
            finalColors = loadedData.colors
        }
        
        vertexBuffer = device.makeBuffer(bytes: finalVertices, length: finalVertices.count * MemoryLayout<Vertex>.stride, options: [])!
        vertexCount = finalVertices.count
        
        self.tileIndex = finalTileIndex
        tileCount = finalTileIndex.count
        
        faceIndexBuffer = device.makeBuffer(bytes: finalFaceIndices, length: finalFaceIndices.count * MemoryLayout<UInt32>.stride, options: [])!
        faceIndexCount = finalFaceIndices.count
        
        edgeIndexBuffer = device.makeBuffer(bytes: finalEdgeIndices, length: finalEdgeIndices.count * MemoryLayout<UInt32>.stride, options: [])!
        edgeIndexCount = finalEdgeIndices.count
        
        colorBuffer = device.makeBuffer(bytes: finalColors, length: finalColors.count * MemoryLayout<SIMD4<Float>>.stride, options:[])!
    }
    
    private static func loadMeshData(from url: URL) -> (vertices: [Vertex], faceIndices: [UInt32], edgeIndices: [UInt32], tileIndex: [Int], colors: [SIMD4<Float>]) {
        do {
            // Read the entire file data
            let data = try Data(contentsOf: url)
            var offset = 0
            
            // Read vertex count
            let vertexCount = data.subdata(in: offset..<offset + MemoryLayout<UInt32>.size).withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += MemoryLayout<UInt32>.size
            
            // Read vertices
            let vertexDataSize = Int(vertexCount) * MemoryLayout<Vertex>.stride
            var vertices = [Vertex](repeating: Vertex(position: SIMD3<Float>(0,0,0)), count: Int(vertexCount))
            vertices.withUnsafeMutableBytes { destBuffer in
                data.withUnsafeBytes { sourceBuffer in
                    memcpy(destBuffer.baseAddress!,
                           sourceBuffer.baseAddress!.advanced(by: offset),
                           vertexDataSize)
                }
            }
            offset += vertexDataSize
            
            // Read face index count
            let faceIndexCount = data.subdata(in: offset..<offset + MemoryLayout<UInt32>.size).withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += MemoryLayout<UInt32>.size
            
            // Read face indices
            let faceIndexDataSize = Int(faceIndexCount) * MemoryLayout<UInt32>.stride
            var faceIndices = [UInt32](repeating: 0, count: Int(faceIndexCount))
            faceIndices.withUnsafeMutableBytes { destBuffer in
                data.withUnsafeBytes { sourceBuffer in
                    memcpy(destBuffer.baseAddress!,
                           sourceBuffer.baseAddress!.advanced(by: offset),
                           faceIndexDataSize)
                }
            }
            offset += faceIndexDataSize
            
            // Read edge index count
            let edgeIndexCount = data.subdata(in: offset..<offset + MemoryLayout<UInt32>.size).withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += MemoryLayout<UInt32>.size
            
            // Read edge indices
            let edgeIndexDataSize = Int(edgeIndexCount) * MemoryLayout<UInt32>.stride
            var edgeIndices = [UInt32](repeating: 0, count: Int(edgeIndexCount))
            edgeIndices.withUnsafeMutableBytes { destBuffer in
                data.withUnsafeBytes { sourceBuffer in
                    memcpy(destBuffer.baseAddress!,
                           sourceBuffer.baseAddress!.advanced(by: offset),
                           edgeIndexDataSize)
                }
            }
            offset += edgeIndexDataSize
            
            // Read tile index count
            let tileIndexCount = data.subdata(in: offset..<offset + MemoryLayout<UInt32>.size).withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += MemoryLayout<UInt32>.size
            
            // Read tile indices
            let tileIndexDataSize = Int(tileIndexCount) * MemoryLayout<Int>.stride
            var tileIndices = [Int](repeating: 0, count: Int(tileIndexCount))
            tileIndices.withUnsafeMutableBytes { destBuffer in
                data.withUnsafeBytes { sourceBuffer in
                    memcpy(destBuffer.baseAddress!,
                           sourceBuffer.baseAddress!.advanced(by: offset),
                           tileIndexDataSize)
                }
            }
            offset += tileIndexDataSize
            
            // Read colors
            let colorCount = (data.count - offset) / MemoryLayout<SIMD4<Float>>.stride
            var colors = [SIMD4<Float>](repeating: SIMD4<Float>(0,0,0,0), count: colorCount)
            let colorDataSize = colorCount * MemoryLayout<SIMD4<Float>>.stride
            colors.withUnsafeMutableBytes { destBuffer in
                data.withUnsafeBytes { sourceBuffer in
                    memcpy(destBuffer.baseAddress!,
                           sourceBuffer.baseAddress!.advanced(by: offset),
                           colorDataSize)
                }
            }
            
            print("✅ Mesh data loaded successfully from \(url.path)")
            return (vertices, faceIndices, edgeIndices, tileIndices, colors)
            
        } catch {
            print("❌ Failed to load mesh data: \(error)")
            fatalError("Could not load mesh data from \(url.path)")
        }
    }
    
    // DEBUG ONLY: was used to generate files. Don't call it please, I don't know what will happen if you do so.
    private func getMeshURL(named filename: String) -> URL? {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        let fileURL = libraryURL?.appendingPathComponent("Mesh/Library/\(filename).bin")
        print("Resolved file URL: \(fileURL?.path ?? "nil")")
        return fileURL
    }
    
    // DEBUG ONLY: files up to 5 subdivisions were generated. This function will probably not be used in the future. Call example at the end.
    private func saveMeshData(to url: URL, vertices: [Vertex], faceIndices: [UInt32], edgeIndices: [UInt32], tileIndex: [Int], colors: [SIMD4<Float>]) {
        var data = Data()
        
        var vertexCount = UInt32(vertices.count)
        data.append(Data(bytes: &vertexCount, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: vertices, count: vertices.count * MemoryLayout<Vertex>.stride))
        
        var faceIndexCount = UInt32(faceIndices.count)
        data.append(Data(bytes: &faceIndexCount, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: faceIndices, count: faceIndices.count * MemoryLayout<UInt32>.stride))
        
        var edgeIndexCount = UInt32(edgeIndices.count)
        data.append(Data(bytes: &edgeIndexCount, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: edgeIndices, count: edgeIndices.count * MemoryLayout<UInt32>.stride))
        
        var tileCount = UInt32(tileIndex.count)
        data.append(Data(bytes: &tileCount, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: tileIndex, count: tileIndex.count * MemoryLayout<Int>.stride))
        
        data.append(Data(bytes: colors, count: colors.count * MemoryLayout<SIMD4<Float>>.stride))
        
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            
            try data.write(to: url)
            print("✅ Mesh data saved successfully at \(url.path)")
        } catch {
            print("❌ Failed to save mesh data: \(error)")
        }
        
//        if let url = getMeshURL(named: filename) {
//            print("Checking for existing mesh file: \(url.path)")
//            if !FileManager.default.fileExists(atPath: url.path) {
//                print("File not found. Saving mesh data...")
//                saveMeshData(to: url, vertices: vertices, faceIndices: faceIndices, edgeIndices: edgeIndices, tileIndex: tileIndex, colors: colors)
//            } else {
//                print("Mesh file already exists. Skipping save.")
//            }
//        } else {
//            print("❌ Failed to get file URL for \(filename)")
//        }
    }
    
    func setColor(forVertexIndex index: Int, color: SIMD4<Float>) {
        let colorPointer = colorBuffer.contents().assumingMemoryBound(to: SIMD4<Float>.self)
        colorPointer[index] = color
    }
    
    func getVertex(forVertexIndex index: Int) -> Vertex {
        let pointer = vertexBuffer.contents().assumingMemoryBound(to: Vertex.self)
        return pointer[index]
    }
}

extension SIMD3 where Scalar == Float {
    init(normalized v: SIMD3<Float>) {
        let length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        self.init(v.x / length, v.y / length, v.z / length)
    }
}
