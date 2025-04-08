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
    let temperature: Temperature
    
    init(renderControl: RenderControl, device: MTLDevice, mesh: Mesh) {
        self.renderControl = renderControl
        self.mesh = mesh
        self.elevation = Elevation(tiles: mesh.tileCount, renderControl: renderControl)
        self.temperature = Temperature(tiles: mesh.tileCount, renderControl: renderControl)
        
        elevation.generateElevation(from: mesh)
        temperature.generateTemperature(mesh: mesh, elevation: elevation)
        
        renderControl.$layer
            .sink { [weak self] newLayer in
                self?.handleLayerChange(newLayer)
            }
            .store(in: &cancellables)
        
        renderControl.$elevationController
            .sink { [weak self] newValues in
                self?.elevation.modifyTerrain(newValues: newValues, mesh: mesh)
                self?.temperature.modifyTemperature(newValues: renderControl.temperatureController, mesh: mesh, elevation: self!.elevation)
                self?.handleLayerChange(renderControl.layer)
            }
            .store(in: &cancellables)
        
        renderControl.$temperatureController
            .sink { [weak self] newValues in
                self?.temperature.modifyTemperature(newValues: newValues, mesh: mesh, elevation: self!.elevation)
                self?.handleLayerChange(renderControl.layer)
            }
            .store(in: &cancellables)
    }
    
    func handleLayerChange(_ layer: String) {
        switch layer {
        case "Elevation":
            showElevation()
        case "Temperature":
            showTemperature()
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
        showTemperature()
    }
    
    func showElevation() {
        let grayScaleMap: [SIMD4<Float>] = elevation.heightMap.map { height in
            // Convert from elevation range [-0.7, 0.8] to grayscale [0, 1]
            let normalizedHeight = (height - (-0.8)) / (0.8 - (-0.8))
            let greyValue = normalizedHeight.clamped(to: 0...1)
            return SIMD4<Float>(greyValue, greyValue, greyValue, 1.0) // RGBA format
        }

        changeColorMap(map: grayScaleMap)
    }
    
    func showTemperature() {
        let temperatureMap: [Float] = temperature.temperatureMap

        // Define the color stops with their corresponding temperatures (0.0 to 1.0)
        let colorStops: [(temperature: Float, color: SIMD4<Float>)] = [
            (temperature: 0.0, color: SIMD4<Float>(0.0, 0.0, 1.0, 1.0)),    // Blue (Coldest)
            (temperature: 0.2, color: SIMD4<Float>(0.0, 0.5, 1.0, 1.0)),    // Light Blue
            (temperature: 0.4, color: SIMD4<Float>(0.0, 1.0, 0.0, 1.0)),    // Green (Cool)
            (temperature: 0.6, color: SIMD4<Float>(1.0, 1.0, 0.0, 1.0)),    // Yellow (Warm)
            (temperature: 0.8, color: SIMD4<Float>(1.0, 0.5, 0.0, 1.0)),    // Orange (Hot)
            (temperature: 1.0, color: SIMD4<Float>(1.0, 0.0, 0.0, 1.0))     // Red (Hottest)
        ]

        let colorMap: [SIMD4<Float>] = temperatureMap.map { temp in
            // Find the two color stops that the current temperature falls between
            guard let lowerStopIndex = colorStops.firstIndex(where: { $0.temperature >= temp }) else {
                // If the temperature is above the highest stop, use the last color
                return colorStops.last!.color
            }

            if lowerStopIndex == 0 {
                // If the temperature is below the first stop, use the first color
                return colorStops.first!.color
            }

            let upperStop = colorStops[lowerStopIndex]
            let lowerStop = colorStops[lowerStopIndex - 1]

            // Calculate the interpolation factor
            let range = upperStop.temperature - lowerStop.temperature
            let factor = range == 0 ? 0 : (temp - lowerStop.temperature) / range

            // Interpolate between the two colors
            return lerpColor(lowerStop.color, upperStop.color, Float(factor))
        }

        changeColorMap(map: colorMap)
    }
    
    
    func changeColorMap(map: [SIMD4<Float>]) {
        for (mapIndex, index) in mesh.tileIndex.enumerated() {
            mesh.setColor(forVertexIndex: index, color: map[mapIndex])
        }
    }
    
    func lerpColor(_ color1: SIMD4<Float>, _ color2: SIMD4<Float>, _ t: Float) -> SIMD4<Float> {
        // Clamp t to the valid range [0, 1]
        let clampedT = min(max(t, 0.0), 1.0)
        // Perform linear interpolation for each component (R, G, B, A)
        return color1 * (1.0 - clampedT) + color2 * clampedT
    }

}
