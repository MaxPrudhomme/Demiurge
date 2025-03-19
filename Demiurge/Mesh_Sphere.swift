//
//  Mesh_Sphere.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 19/03/2025.
//

import MetalKit

class Mesh_Sphere: Mesh {
    init(device:MTLDevice, radius: Float = 1.0, segments: Int = 32) {
        let vertices: [Vertex] = []
        let indices: [UInt16] = []
        let edgeIndices: [UInt16] = []
        
        let radius = radius
        let segments = segments
        
        super.init(device: device, vertices: vertices, indices: indices, edgeIndices: edgeIndices)
    }
}
