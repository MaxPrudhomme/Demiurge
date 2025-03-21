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

class Mesh {
    var vertexBuffer: MTLBuffer
    var vertexCount: Int
    
    var indexBuffer: MTLBuffer
    let indexCount: Int
    
    var edgeIndexBuffer: MTLBuffer
    let edgeIndexCount: Int

    init(device: MTLDevice, vertices: [Vertex], indices: [UInt32], edgeIndices: [UInt32]) {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        vertexCount = vertices.count
        
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: [])!
        indexCount = indices.count
        
        edgeIndexBuffer = device.makeBuffer(bytes: edgeIndices, length: edgeIndices.count * MemoryLayout<UInt32>.stride, options: [])!
        edgeIndexCount = edgeIndices.count
    }
}

extension SIMD3 where Scalar == Float {
    init(normalized v: SIMD3<Float>) {
        let length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        self.init(v.x / length, v.y / length, v.z / length)
    }
}
