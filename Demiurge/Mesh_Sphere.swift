//
//  Mesh_Sphere.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 19/03/2025.
//

import MetalKit

class Mesh_Sphere: Mesh {
    init(device: MTLDevice, radius: Float = 1.0, subdivisions: Int = 3) {
        var vertices: [Vertex]
        var indices: [UInt16] = []
        var edgeIndices: [UInt16] = []
        
        let originalVertices = Mesh_Sphere.createIcosahedronVertices(radius: radius)
        
        (vertices, indices, edgeIndices) = Mesh_Sphere.subdivideAndTruncate(
            originalVertices: originalVertices,
            subdivisions: subdivisions,
            radius: radius
        )
        
        super.init(device: device, vertices: vertices, indices: indices, edgeIndices: edgeIndices)
    }
    
    private static func createIcosahedronVertices(radius: Float) -> [Vertex] {
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
        return vertices.map { Vertex(position: $0) }
    }
    
    private static func subdivideAndTruncate(originalVertices: [Vertex], subdivisions: Int, radius: Float) -> ([Vertex], [UInt16], [UInt16]) {
        // Initial faces
        let initialFaces: [[Int]] = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
        ]
        
        // Initial edges
        let initialEdges: [[Int]] = [
            [0, 1], [0, 5], [0, 7], [0, 10], [0, 11],
            [1, 5], [1, 7], [1, 8], [1, 9],
            [2, 3], [2, 4], [2, 6], [2, 10], [2, 11],
            [3, 4], [3, 6], [3, 8], [3, 9],
            [4, 5], [4, 9], [4, 11],
            [5, 9], [5, 11],
            [6, 7], [6, 8], [6, 10],
            [7, 8], [7, 10],
            [8, 9],
            [10, 11]
        ]
        
        var positions = originalVertices.map { $0.position }
        
        var edgeMidpoints: [String: Int] = [:]
        
        func getMidpoint(_ a: Int, _ b: Int) -> Int {
            let edgeKey = a < b ? "\(a)-\(b)" : "\(b)-\(a)"
            if let midpointIndex = edgeMidpoints[edgeKey] {
                return midpointIndex
            } else {
                let midpoint = (positions[a] + positions[b]) * 0.5
                let normalizedMidpoint = SIMD3<Float>(normalized: midpoint) * radius
                positions.append(normalizedMidpoint)
                edgeMidpoints[edgeKey] = positions.count - 1
                return positions.count - 1
            }
        }
        
        // Apply subdivision
        var subdividedFaces: [[Int]] = initialFaces
        var subdividedEdges: [[Int]] = initialEdges
        
        for _ in 0..<subdivisions {
            var newFaces: [[Int]] = []
            var newEdges: [[Int]] = []
            
            var processedEdges: Set<String> = []
            
            // Process each face for subdivision
            for face in subdividedFaces {
                let v1 = face[0]
                let v2 = face[1]
                let v3 = face[2]
                
                let a = getMidpoint(v1, v2)
                let b = getMidpoint(v2, v3)
                let c = getMidpoint(v3, v1)
                
                newFaces.append([v1, a, c])
                newFaces.append([v2, b, a])
                newFaces.append([v3, c, b])
                newFaces.append([a, b, c])
                
                // Create new edges - handle duplicates with a set
                addEdgeIfNotProcessed([v1, a], &newEdges, &processedEdges)
                addEdgeIfNotProcessed([a, v2], &newEdges, &processedEdges)
                addEdgeIfNotProcessed([v2, b], &newEdges, &processedEdges)
                addEdgeIfNotProcessed([b, v3], &newEdges, &processedEdges)
                addEdgeIfNotProcessed([v3, c], &newEdges, &processedEdges)
                addEdgeIfNotProcessed([c, v1], &newEdges, &processedEdges)
                addEdgeIfNotProcessed([a, b], &newEdges, &processedEdges)
                addEdgeIfNotProcessed([b, c], &newEdges, &processedEdges)
                addEdgeIfNotProcessed([c, a], &newEdges, &processedEdges)
            }
            
            subdividedFaces = newFaces
            subdividedEdges = newEdges
        }
        
        var truncatedVertices: [SIMD3<Float>] = positions
        var truncatedFaces: [[Int]] = subdividedFaces
        var truncatedEdges: [[Int]] = subdividedEdges
        
        let finalVertices = truncatedVertices.map { Vertex(position: $0) }
        
        var indices: [UInt16] = []
        for face in truncatedFaces {
            indices.append(contentsOf: face.map { UInt16($0) })
        }
        
        var edgeIndices: [UInt16] = []
        for edge in truncatedEdges {
            edgeIndices.append(contentsOf: edge.map { UInt16($0) })
        }
        
        return (finalVertices, indices, edgeIndices)
    }
    
    private static func addEdgeIfNotProcessed(_ edge: [Int], _ edges: inout [[Int]], _ processed: inout Set<String>) {
        let edgeKey = edge[0] < edge[1] ? "\(edge[0])-\(edge[1])" : "\(edge[1])-\(edge[0])"
        if !processed.contains(edgeKey) {
            edges.append(edge)
            processed.insert(edgeKey)
        }
    }
}
