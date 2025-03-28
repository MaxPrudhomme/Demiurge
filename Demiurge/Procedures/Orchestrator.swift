//
//  Orchestrator.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 22/03/2025.
//

import Foundation
import MetalKit
import Combine

class Orchestrator {
    var renderControl: RenderControl
    var mesh: Mesh!
    
    private var cancellables: Set<AnyCancellable> = []
    
    let elevation: Elevation
    
    init(renderControl: RenderControl, device: MTLDevice, mesh: Mesh) {
        self.renderControl = renderControl
        self.mesh = mesh
        self.elevation = Elevation(tiles: mesh.tileCount)
        
        elevation.generateElevation(from: mesh)
        
        renderControl.$layer
            .sink { [weak self] newLayer in
                self?.handleLayerChange(newLayer)
            }
            .store(in: &cancellables)
    }
    
    func handleLayerChange(_ layer: String) {
        switch layer {
        case "Elevation":
            showElevation()
        case "Temperature":
            break
        case "Humidity":
            break
        case "All layers":
            showAllLayers()
            break
        default:
            break
        }
    }
    
    func showAllLayers() {
        // TEMP: will be changed later on.
        showElevation()
    }
    
    func showElevation() {
        let grayScaleMap: [SIMD4<Float>] = elevation.heightMap.map { height in
            // Convert from elevation range [-0.7, 0.8] to grayscale [0, 1]
            let normalizedHeight = (height - (-0.7)) / (0.8 - (-0.7))
            let greyValue = normalizedHeight.clamped(to: 0...1)
            return SIMD4<Float>(greyValue, greyValue, greyValue, 1.0) // RGBA format
        }

        changeColorMap(map: grayScaleMap)
    }
    
    func changeColorMap(map: [SIMD4<Float>]) {
        for (mapIndex, index) in mesh.tileIndex.enumerated() {
            mesh.setColor(forVertexIndex: index, color: map[mapIndex])
        }
    }
}
