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
    
    var indexBuffer: MTLBuffer
    let indexCount: Int
    
    var edgeIndexBuffer: MTLBuffer
    let edgeIndexCount: Int

    init(device: MTLDevice, vertices: [Vertex], indices: [UInt16], edgeIndices: [UInt16]) {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])!
        indexCount = indices.count
        
        edgeIndexBuffer = device.makeBuffer(bytes: edgeIndices, length: edgeIndices.count * MemoryLayout<UInt16>.stride, options: [])!
        edgeIndexCount = edgeIndices.count
    }
}
