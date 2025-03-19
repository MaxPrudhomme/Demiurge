//
//  Mesh_Sphere.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 19/03/2025.
//

import MetalKit

class Mesh_Sphere: Mesh {
    init(device: MTLDevice, radius: Float = 1.0, subdivisions: Int = 3) {
        // We'll start with an icosahedron and subdivide
        let vertices: [Vertex]
        let indices: [UInt16]
        let edgeIndices: [UInt16]
        
        // Generate the hexasphere
        (vertices, indices, edgeIndices) = Mesh_Sphere.createHexasphere(radius: radius, subdivisions: subdivisions)
        
        super.init(device: device, vertices: vertices, indices: indices, edgeIndices: edgeIndices)
    }
    
    private static func createHexasphere(radius: Float, subdivisions: Int) -> ([Vertex], [UInt16], [UInt16]) {
        // Step 1: Create an icosahedron as our base
        let (baseVertices, baseFaces) = createIcosahedron(radius: radius)
        
        // Step 2: Subdivide the faces
        var vertices = [SIMD3<Float>]()
        var faces = [[Int]]()
        
        subdivideIcosahedron(baseVertices: baseVertices, baseFaces: baseFaces,
                             subdivisions: subdivisions, radius: radius,
                             vertices: &vertices, faces: &faces)
        
        // Step 3: Create the dual mesh (hexagons and pentagons)
        let (dualVertices, dualEdgeIndices) = createDualMesh(vertices: vertices, faces: faces, radius: radius)
        
        // Step 4: Create the vertex and index buffers
        var vertexArray = [Vertex]()
        for position in dualVertices {
            vertexArray.append(Vertex(position: position))
        }
        
        // Create dummy indices for triangles - we'll still use them for filling
        var indexArray = [UInt16]()
        for i in stride(from: 0, to: dualVertices.count - 2, by: 1) {
            indexArray.append(UInt16(0))
            indexArray.append(UInt16(i + 1))
            indexArray.append(UInt16(i + 2))
        }
        
        return (vertexArray, indexArray, dualEdgeIndices)
    }
    
    private static func createDualMesh(vertices: [SIMD3<Float>], faces: [[Int]], radius: Float) -> ([SIMD3<Float>], [UInt16]) {
        // Step 1: Calculate face centers
        var faceCenters = [SIMD3<Float>]()
        for face in faces {
            let v1 = vertices[face[0]]
            let v2 = vertices[face[1]]
            let v3 = vertices[face[2]]
            let center = (v1 + v2 + v3) / 3.0
            
            // Project to sphere surface
            let normalizedCenter = SIMD3<Float>(normalized: center) * radius
            faceCenters.append(normalizedCenter)
        }
        
        // Step 2: Build a map of adjacent faces for each face
        var faceAdjacency = Array(repeating: Set<Int>(), count: faces.count)
        
        for i in 0..<faces.count {
            let face1 = faces[i]
            for j in (i+1)..<faces.count {
                let face2 = faces[j]
                
                // Check if faces share an edge (2 common vertices)
                let commonVertices = Set(face1).intersection(Set(face2))
                if commonVertices.count == 2 {
                    faceAdjacency[i].insert(j)
                    faceAdjacency[j].insert(i)
                }
            }
        }
        
        // Step 3: Generate edge indices for the dual mesh
        var edgeIndices = [UInt16]()
        var processedEdges = Set<String>()
        
        for i in 0..<faceAdjacency.count {
            for j in faceAdjacency[i] {
                let edgeKey = [min(i, j), max(i, j)].map(String.init).joined(separator: "-")
                if !processedEdges.contains(edgeKey) {
                    processedEdges.insert(edgeKey)
                    edgeIndices.append(UInt16(i))
                    edgeIndices.append(UInt16(j))
                }
            }
        }
        
        return (faceCenters, edgeIndices)
    }
    
    private static func createIcosahedron(radius: Float) -> ([SIMD3<Float>], [[Int]]) {
        // Golden ratio for icosahedron construction
        let phi = (1.0 + sqrt(5.0)) / 2.0
        
        // 12 vertices of the icosahedron
        var vertices = [SIMD3<Float>]()
        
        // Create the 12 vertices
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(-1, Float(phi), 0)) * radius)
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(1, Float(phi), 0)) * radius)
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(-1, -Float(phi), 0)) * radius)
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(1, -Float(phi), 0)) * radius)
        
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(0, -1, Float(phi))) * radius)
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(0, 1, Float(phi))) * radius)
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(0, -1, -Float(phi))) * radius)
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(0, 1, -Float(phi))) * radius)
        
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(Float(phi), 0, -1)) * radius)
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(Float(phi), 0, 1)) * radius)
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(-Float(phi), 0, -1)) * radius)
        vertices.append(SIMD3<Float>(normalized: SIMD3<Float>(-Float(phi), 0, 1)) * radius)
        
        // 20 faces of the icosahedron (as triangles)
        let faces = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
        ]
        
        return (vertices, faces)
    }
    
    private static func subdivideIcosahedron(baseVertices: [SIMD3<Float>], baseFaces: [[Int]],
                                         subdivisions: Int, radius: Float,
                                         vertices: inout [SIMD3<Float>], faces: inout [[Int]]) {
        // Start with the base icosahedron
        vertices = baseVertices
        faces = baseFaces
        
        // Dictionary to store midpoints to avoid duplicate vertices
        var midpointCache = [String: Int]()
        
        // Perform subdivision iterations
        for _ in 0..<subdivisions {
            let oldFaces = faces
            faces = []
            
            for face in oldFaces {
                let v1 = face[0]
                let v2 = face[1]
                let v3 = face[2]
                
                // Get or create midpoints
                let a = getMidpointIndex(v1: v1, v2: v2, vertices: &vertices, radius: radius, cache: &midpointCache)
                let b = getMidpointIndex(v1: v2, v2: v3, vertices: &vertices, radius: radius, cache: &midpointCache)
                let c = getMidpointIndex(v1: v3, v2: v1, vertices: &vertices, radius: radius, cache: &midpointCache)
                
                // Create 4 new faces (subdividing the triangle)
                faces.append([v1, a, c])
                faces.append([v2, b, a])
                faces.append([v3, c, b])
                faces.append([a, b, c]) // Middle triangle
            }
        }
    }
    
    private static func getMidpointIndex(v1: Int, v2: Int, vertices: inout [SIMD3<Float>],
                                      radius: Float, cache: inout [String: Int]) -> Int {
        // Create a unique string key for this edge (ordered by vertex index)
        let edgeKey = [min(v1, v2), max(v1, v2)].map(String.init).joined(separator: "-")
        
        // Check if we've already calculated this midpoint
        if let cachedIndex = cache[edgeKey] {
            return cachedIndex
        }
        
        // Calculate midpoint and project to sphere surface
        let point1 = vertices[v1]
        let point2 = vertices[v2]
        let midpoint = (point1 + point2) * 0.5
        
        // Project to sphere
        let normalizedMidpoint = SIMD3<Float>(normalized: midpoint) * radius
        
        // Add new vertex
        let newIndex = vertices.count
        vertices.append(normalizedMidpoint)
        
        // Cache the result
        cache[edgeKey] = newIndex
        
        return newIndex
    }
}

// Helper extension for SIMD3 normalization
extension SIMD3 where Scalar == Float {
    init(normalized v: SIMD3<Float>) {
        let length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        self.init(v.x / length, v.y / length, v.z / length)
    }
}
