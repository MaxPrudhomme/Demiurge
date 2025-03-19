//
//  Mesh_Sphere.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 19/03/2025.
//

import MetalKit

class Mesh_Sphere: Mesh {
    init(device: MTLDevice, radius: Float = 1.0, subdivisions: Int = 1) {
        let vertices: [Vertex]
        var indices: [UInt16] = []
        let edgeIndices: [UInt16]
        
        (vertices, edgeIndices) = Mesh_Sphere.createIcosahedron(radius: radius, subdivisions: subdivisions)
        
        indices = Mesh_Sphere.createIcosahedronFaces(vertices: vertices, subdivisions: subdivisions)
        
        super.init(device: device, vertices: vertices, indices: indices, edgeIndices: edgeIndices)
    }
    
    private static func createIcosahedron(radius: Float, subdivisions: Int) -> ([Vertex], [UInt16]) {
        let phi = (1.0 + sqrt(5.0)) / 2.0
        let vertexPositions: [SIMD3<Float>] = [
            SIMD3<Float>(-1, Float(phi), 0), SIMD3<Float>(1, Float(phi), 0),
            SIMD3<Float>(-1, -Float(phi), 0), SIMD3<Float>(1, -Float(phi), 0),
            SIMD3<Float>(0, -1, Float(phi)), SIMD3<Float>(0, 1, Float(phi)),
            SIMD3<Float>(0, -1, -Float(phi)), SIMD3<Float>(0, 1, -Float(phi)),
            SIMD3<Float>(Float(phi), 0, -1), SIMD3<Float>(Float(phi), 0, 1),
            SIMD3<Float>(-Float(phi), 0, -1), SIMD3<Float>(-Float(phi), 0, 1)
        ]
        
        let vertices = vertexPositions.map { SIMD3<Float>(normalized: $0) * radius }
        
        let edges: [UInt16] = [
            0, 1, 0, 5, 0, 7, 0, 10, 0, 11,
            1, 5, 1, 7, 1, 8, 1, 9,
            2, 3, 2, 4, 2, 6, 2, 10, 2, 11,
            3, 4, 3, 6, 3, 8, 3, 9,
            4, 5, 4, 9, 4, 11,
            5, 9, 5, 11,
            6, 7, 6, 8, 6, 10,
            7, 8, 7, 10,
            8, 9,
            10, 11
        ]
        
        let vertexArray = vertices.map { Vertex(position: $0) }
        
        return (vertexArray, edges)
    }
    
    private static func createIcosahedronFaces(vertices: [Vertex], subdivisions: Int) -> [UInt16] {
        var indices: [UInt16] = []
        
        let initialFaces: [[Int]] = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
        ]
        
        for faceIndices in initialFaces {
            indices.append(contentsOf: faceIndices.map { UInt16($0) })
        }
        
        return indices
    }
}
