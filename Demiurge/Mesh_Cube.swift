//
//  Mesh_Cube.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 18/03/2025.
//

import MetalKit

class Mesh_Cube: Mesh {
    init(device: MTLDevice) {
        let vertices: [Vertex] = [
            // Front face
            Vertex(position: SIMD3(-0.5, -0.5,  0.5)),
            Vertex(position: SIMD3( 0.5, -0.5,  0.5)),
            Vertex(position: SIMD3( 0.5,  0.5,  0.5)),
            Vertex(position: SIMD3(-0.5,  0.5,  0.5)),

            // Back face
            Vertex(position: SIMD3(-0.5, -0.5, -0.5)),
            Vertex(position: SIMD3( 0.5, -0.5, -0.5)),
            Vertex(position: SIMD3( 0.5,  0.5, -0.5)),
            Vertex(position: SIMD3(-0.5,  0.5, -0.5)),
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

        super.init(device: device, vertices: vertices, indices: indices, edgeIndices: edgeIndices)
    }
}
