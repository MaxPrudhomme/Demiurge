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

        // Create a greyscale color map based on the updated height map values
        let grayScaleMap: [SIMD4<Float>] = elevation.heightMap.map { height in
            let greyValue = height // height value between 0 and 1
            return SIMD4<Float>(greyValue, greyValue, greyValue, 1.0) // RGBA format
        }

        // Send the color map to the changeColorMap method
//        changeColorMap(map: grayScaleMap)
    }
    
    func changeColorMap(map: [SIMD4<Float>]) {
        for (mapIndex, index) in mesh.tileIndex.enumerated() {
            mesh.setColor(forVertexIndex: index, color: map[mapIndex])
        }
    }
}
