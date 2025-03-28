//
//  Orchestrator.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 22/03/2025.
//

import Foundation
import MetalKit
import Combine

let sizes: [Int] = [12, 42, 162, 642, 2562]

class Orchestrator {
    var renderControl: RenderControl
    var mesh: Mesh!
    
    private var cancellables: Set<AnyCancellable> = []
    
    let elevation: Elevation
    
    init(renderControl: RenderControl, device: MTLDevice, mesh: Mesh) {
        self.renderControl = renderControl
        self.mesh = mesh
        self.elevation = Elevation(tiles: mesh.tileCount)

        // Generate elevation before creating the color map
        elevation.generateElevation(from: mesh)

        let grayScaleMap: [SIMD4<Float>] = elevation.heightMap.map { height in
            // Convert from elevation range [-0.7, 0.8] to grayscale [0, 1]
            let normalizedHeight = (height - (-0.7)) / (0.8 - (-0.7))
            let greyValue = normalizedHeight.clamped(to: 0...1)
            return SIMD4<Float>(greyValue, greyValue, greyValue, 1.0) // RGBA format
        }

        // Send the color map to the changeColorMap method
        changeColorMap(map: grayScaleMap)
    }
    
    func changeColorMap(map: [SIMD4<Float>]) {
        for (mapIndex, index) in mesh.tileIndex.enumerated() {
            mesh.setColor(forVertexIndex: index, color: map[mapIndex])
        }
    }
}
