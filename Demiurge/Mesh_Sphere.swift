//
//  Mesh_Sphere.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 19/03/2025.
//

import MetalKit

class Mesh_Sphere: Mesh {
    init(device: MTLDevice, radius: Float = 1.0, subdivisions: Int = 0) {
        var vertices: [Vertex]
        var newVertices: [Vertex]
        var indices: [[UInt32]] = []
        var edgeIndices: [[UInt32]] = []
        
        let originalVertices = Mesh_Sphere.createIcosahedronVertices(radius: radius)

        (vertices, indices, edgeIndices) = Mesh_Sphere.subdivideAndTruncate(
            originalVertices: originalVertices,
            subdivisions: subdivisions,
            radius: radius
        )
        
        (newVertices, _, edgeIndices) = Mesh_Sphere.createDoubleMesh(
            originalVertices: vertices,
            indices: indices,
            edgeIndices: edgeIndices
        )
        
        super.init(device: device, vertices: newVertices, indices: [0, 0, 0], edgeIndices: edgeIndices.flatMap { $0 })
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
    
    private static func subdivideAndTruncate(originalVertices: [Vertex], subdivisions: Int, radius: Float) -> ([Vertex], [[UInt32]], [[UInt32]]) {
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
        
        let truncatedVertices: [SIMD3<Float>] = positions
        
        let finalVertices = truncatedVertices.map { Vertex(position: $0) }
        
        var indices: [[UInt32]] = []
        for face in subdividedFaces {
            indices.append(face.map { UInt32($0) })
        }

        var edgeIndices: [[UInt32]] = []
        for edge in subdividedEdges {
            edgeIndices.append(edge.map { UInt32($0) })
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
    
    private static func addVertexIfNotProcessed(_ vertex: Vertex, in vertices: inout [Vertex]) -> Int {
        if let existingIndex = vertices.firstIndex(where: { $0.position == vertex.position }) {
            return existingIndex
        } else {
            vertices.append(vertex)
            return vertices.count - 1
        }
    }
    
    private static func addEdge(_ edge: [UInt32], in edges: inout [[UInt32]]) -> Int {
        if let existingIndex = edges.firstIndex(of: edge) {
            return existingIndex
        } else {
            edges.append(edge)
            return edges.count - 1
        }
    }
    
    private static func getMidpoint(_ p1: Vertex, _ p2: Vertex, _ p3: Vertex) -> Vertex {
        return Vertex(
            position: (p1.position + p2.position + p3.position) / 3.0
        )
    }
    
    private static func createDoubleMesh(originalVertices: [Vertex], indices: [[UInt32]], edgeIndices: [[UInt32]]) -> ([Vertex], [[UInt32]], [[UInt32]]) {
        var newVertices: [Vertex] = []
        var newFaceIndices: [[UInt32]] = []
        var newEdgeIndices: [[UInt32]] = []
        
        var midpoints: [String : Vertex] = [:]
        
        for faceIndex in 0..<indices.count {
            let v1: Vertex = originalVertices[Int(indices[faceIndex][0])]
            let v2: Vertex = originalVertices[Int(indices[faceIndex][1])]
            let v3: Vertex = originalVertices[Int(indices[faceIndex][2])]
            
            midpoints["face_\(indices[faceIndex])"] = getMidpoint(v1, v2, v3)
        }
        
        for (vertexIndex, _) in originalVertices.enumerated() {
            // Store the index of faces that contains the current vertex as one of their points
            var associatedFaces: [Int] = []
            for (faceIndex, face) in indices.enumerated() {
                if face.contains(UInt32(vertexIndex)) {
                    associatedFaces.append(faceIndex)
                }
            }
            
            // Process all pairs of adjacent faces around this vertex
            for i in 0..<associatedFaces.count {
                let faceIndex1 = associatedFaces[i]
                let face1 = indices[faceIndex1]
                
                for j in (i+1)..<associatedFaces.count {
                    let faceIndex2 = associatedFaces[j]
                    let face2 = indices[faceIndex2]
                    
                    // Check if these faces share an edge (they share the current vertex and one other vertex)
                    var sharedVertices = 0
                    for vertexInFace1 in face1 {
                        if face2.contains(vertexInFace1) {
                            sharedVertices += 1
                        }
                    }
                    
                    // If faces share exactly 2 vertices (our original vertex and one more), they're adjacent
                    if sharedVertices == 2 {
                        // Get midpoints of both faces
                        let midpoint1 = midpoints["face_\(face1)"]!
                        let midpoint2 = midpoints["face_\(face2)"]!
                        
                        // Add midpoints to vertices array if not already there
                        let midpoint1Index = addVertexIfNotProcessed(midpoint1, in: &newVertices)
                        let midpoint2Index = addVertexIfNotProcessed(midpoint2, in: &newVertices)
                        
                        // Add edge between these midpoints
                        newEdgeIndices.append([UInt32(midpoint1Index), UInt32(midpoint2Index)])
                    }
                }
            }
        }
        
        
        return (newVertices, newFaceIndices, newEdgeIndices)
    }
}
