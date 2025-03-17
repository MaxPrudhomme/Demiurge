//
//  Mesh.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 17/03/2025.
//

import MetalKit

class Mesh {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var edgeIndexBuffer: MTLBuffer
    let indexCount: Int
    let edgeIndexCount : Int

    init(device: MTLDevice) {
        let vertices: [Float] = [
            // Front face
            -0.5, -0.5,  0.5,    0.2, 0.4, 0.8, 1.0,
             0.5, -0.5,  0.5,    0.2, 0.4, 0.8, 1.0,
             0.5,  0.5,  0.5,    0.2, 0.4, 0.8, 1.0,
            -0.5,  0.5,  0.5,    0.2, 0.4, 0.8, 1.0,

            // Back face
            -0.5, -0.5, -0.5,    0.2, 0.4, 0.8, 1.0,
             0.5, -0.5, -0.5,    0.2, 0.4, 0.8, 1.0,
             0.5,  0.5, -0.5,    0.2, 0.4, 0.8, 1.0,
            -0.5,  0.5, -0.5,    0.2, 0.4, 0.8, 1.0
        ]

        let indices: [UInt16] = [
            0, 1, 2, 2, 3, 0,  // Front face
            4, 5, 6, 6, 7, 4,  // Back face
            0, 4, 7, 7, 3, 0,  // Left face
            1, 5, 6, 6, 2, 1,  // Right face
            3, 2, 6, 6, 7, 3,  // Top face
            0, 1, 5, 5, 4, 0   // Bottom face
        ]
        
        let edgeIndices: [UInt16] = [
            0, 1, 1, 2, 2, 3, 3, 0,  // Front face edges
            4, 5, 5, 6, 6, 7, 7, 4,  // Back face edges
            0, 4, 1, 5, 2, 6, 3, 7   // Connecting edges
        ]
        
        indexCount = indices.count
        edgeIndexCount = edgeIndices.count
        
        edgeIndexBuffer = device.makeBuffer(bytes: edgeIndices, length: edgeIndices.count * MemoryLayout<UInt16>.stride, options: [])!
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: [])!
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])!
    }
}
