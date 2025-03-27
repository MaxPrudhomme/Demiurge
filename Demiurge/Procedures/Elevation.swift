//
//  Elevation.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 22/03/2025.
//

import Foundation
import MetalKit

class Elevation {
    var heightMap: [Float]
    let tileCount: Int

    init(tiles: Int) {
        self.tileCount = tiles
        self.heightMap = (0..<tiles).map { _ in Float.random(in: 0..<1) }
    }

    func generateElevation(from mesh: Mesh) {
        var newHeightMap = [Float](repeating: 0, count: tileCount)

        // Generate noise-based elevation using tile centers
        for i in 0..<tileCount {
            let centerVertex = mesh.getVertex(forVertexIndex: mesh.tileIndex[i])
            let pos = centerVertex.position
            newHeightMap[i] = perlinNoise3D(x: pos.x, y: pos.y, z: pos.z)
        }

        // Apply noise-space smoothing
        var smoothedHeightMap = newHeightMap
        for i in 0..<tileCount {
            let centerVertex = mesh.getVertex(forVertexIndex: mesh.tileIndex[i])
            let pos = centerVertex.position
            
            // Sample Perlin noise at nearby points for smoothing
            let offsets: [SIMD3<Float>] = [
                SIMD3<Float>(0.02, 0, 0),
                SIMD3<Float>(-0.02, 0, 0),
                SIMD3<Float>(0, 0.02, 0),
                SIMD3<Float>(0, -0.02, 0),
                SIMD3<Float>(0, 0, 0.02),
                SIMD3<Float>(0, 0, -0.02)
            ]
            
            let samples = offsets.map { offset in
                perlinNoise3D(x: pos.x + offset.x, y: pos.y + offset.y, z: pos.z + offset.z)
            }
            
            smoothedHeightMap[i] = (samples.reduce(0, +) + newHeightMap[i]) / Float(samples.count + 1)
        }

        heightMap = smoothedHeightMap
    }

    // Simple Perlin noise function (placeholder)
    func perlinNoise3D(x: Float, y: Float, z: Float) -> Float {
        return (sin(x * 10) * cos(y * 10) * sin(z * 10) + 1) / 2 // Example pattern
    }
}
