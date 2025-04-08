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
    let humidity: Humidity
    
    init(renderControl: RenderControl, device: MTLDevice, mesh: Mesh) {
        self.renderControl = renderControl
        self.mesh = mesh
        self.elevation = Elevation(tiles: mesh.tileCount, renderControl: renderControl)
        self.temperature = Temperature(tiles: mesh.tileCount, renderControl: renderControl)
        self.humidity = Humidity(tiles: mesh.tileCount, renderControl: renderControl)
        
        elevation.generateElevation(from: mesh)
        temperature.generateTemperature(mesh: mesh, elevation: elevation)
        humidity.generateHumidity(mesh: mesh, elevation: elevation)
        
        renderControl.$layer
            .sink { [weak self] newLayer in
                self?.handleLayerChange(newLayer)
            }
            .store(in: &cancellables)
        
        renderControl.$elevationController
            .sink { [weak self] newValues in
                self?.elevation.modifyTerrain(newValues: newValues, mesh: mesh)
                self?.humidity.modifyHumidity(newValues: renderControl.humidityController, mesh: mesh, elevation: self!.elevation)
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
        
        renderControl.$humidityController
            .sink { [weak self] newValues in
                self?.humidity.modifyHumidity(newValues: newValues, mesh: mesh, elevation: self!.elevation)
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
            showHumidity()
        case "All layers":
            showAllLayers()
            break
        default:
            break
        }
    }
    
    func showAllLayers() {
        let elevationMap = elevation.heightMap
        let temperatureMap = temperature.temperatureMap
        let humidityMap = humidity.humidityMap

        var biomeMap: [SIMD4<Float>] = []
        var biomeCounts: [String: Int] = [
            "Deep Ocean": 0, "Ocean": 0, "Shallows": 0, "Land": 0, "Hills": 0,
            "Mountains": 0, "Peaks": 0, "Frozen Wasteland": 0, "Tundra": 0,
            "Boreal Forest": 0, "Temperate Forest": 0, "Grassland": 0, "Desert": 0,
            "Tropical Rainforest": 0
        ]

        let deepOceanLevel: Float = -0.6 // Assuming this value, adjust if needed

        for i in 0..<mesh.tileCount {
            let h = elevationMap[i]
            let temp = temperatureMap[i]
            let humidity = humidityMap[i]

            var biome: String = "Ocean"
            var baseColor: SIMD4<Float> = SIMD4<Float>(0.0, 0.3, 0.8, 1.0) // Default to ocean
            var brightness: Float = 1.0

            if h < deepOceanLevel + 0.1 {
                biome = "Deep Ocean"
                baseColor = SIMD4<Float>(0.0, 0.2, 0.6, 1.0)
                // Darker with depth
                let depthFactor = 1.0 - ((h - (deepOceanLevel + 0.1)) / (deepOceanLevel - (deepOceanLevel + 0.1)))
                brightness = 0.5 + 0.5 * depthFactor.clamped(to: 0...1) // Range from 0.5 to 1.0
            } else if h < -0.1 {
                biome = "Ocean"
                baseColor = SIMD4<Float>(0.0, 0.3, 0.8, 1.0)
                // Slightly darker with depth
                let depthFactor = 1.0 - ((h - (-0.1)) / (deepOceanLevel + 0.1 - (-0.1)))
                brightness = 0.7 + 0.3 * depthFactor.clamped(to: 0...1) // Range from 0.7 to 1.0
            } else if h < 0.0 {
                biome = "Shallows"
                baseColor = SIMD4<Float>(0.2, 0.4, 0.7, 1.0)
                // Lighter as it gets shallower
                brightness = 0.8 + 0.2 * (h / 0.1).clamped(to: 0...1) // Range from 0.8 to 1.0
            } else if h < 0.2 {
                biome = "Land"
                if temp < 0.1 {
                    biome = "Frozen Wasteland"
                    baseColor = SIMD4<Float>(0.9, 0.9, 0.9, 1.0)
                } else if temp < 0.3 {
                    biome = "Tundra"
                    baseColor = SIMD4<Float>(0.8, 0.8, 0.8, 1.0)
                } else if temp < 0.6 {
                    if humidity < 0.5 {
                        biome = "Grassland"
                        baseColor = SIMD4<Float>(0.7, 0.8, 0.3, 1.0)
                    } else {
                        biome = "Temperate Forest"
                        baseColor = SIMD4<Float>(0.2, 0.6, 0.2, 1.0)
                    }
                } else if temp < 0.8 {
                    if humidity < 0.5 {
                        biome = "Desert"
                        baseColor = SIMD4<Float>(0.9, 0.8, 0.4, 1.0)
                    } else {
                        biome = "Tropical Rainforest"
                        baseColor = SIMD4<Float>(0.1, 0.7, 0.3, 1.0)
                    }
                } else { // Hot
                    if humidity < 0.6 {
                        biome = "Desert"
                        baseColor = SIMD4<Float>(0.9, 0.7, 0.2, 1.0)
                    } else {
                        biome = "Tropical Rainforest"
                        baseColor = SIMD4<Float>(0.1, 0.5, 0.2, 1.0)
                    }
                }
                // Lighter with height in "Land"
                brightness = 0.8 + 0.2 * (h / 0.2).clamped(to: 0...1)
            } else if h < 0.4 {
                biome = "Hills"
                if temp < 0.3 {
                    biome = "Boreal Forest"
                    baseColor = SIMD4<Float>(0.3, 0.5, 0.3, 1.0)
                } else if temp < 0.6 {
                    if humidity < 0.6 {
                        biome = "Grassland"
                        baseColor = SIMD4<Float>(0.6, 0.7, 0.3, 1.0)
                    } else {
                        biome = "Temperate Forest"
                        baseColor = SIMD4<Float>(0.2, 0.5, 0.2, 1.0)
                    }
                } else {
                    if humidity < 0.5 {
                        biome = "Grassland"
                        baseColor = SIMD4<Float>(0.8, 0.7, 0.4, 1.0)
                    } else {
                        baseColor = SIMD4<Float>(0.3, 0.4, 0.2, 1.0)
                    }
                }
                // Lighter with height in "Hills"
                brightness = 0.7 + 0.3 * ((h - 0.2) / 0.2).clamped(to: 0...1)
            } else if h < 0.7 {
                biome = "Mountains"
                baseColor = SIMD4<Float>(0.6, 0.6, 0.6, 1.0)
                if temp < 0.3 {
                    biome = "Tundra"
                    baseColor = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
                }
                // Lighter with height in "Mountains"
                brightness = 0.6 + 0.4 * ((h - 0.4) / 0.3).clamped(to: 0...1)
            } else {
                biome = "Peaks"
                baseColor = SIMD4<Float>(0.8, 0.8, 0.8, 1.0)
                if temp < 0.1 {
                    baseColor = SIMD4<Float>(1.0, 1.0, 1.0, 1.0) // Snow
                }
                // Always bright for peaks
                brightness = 1.0
            }

            let finalColor = baseColor * brightness
            biomeMap.append(SIMD4<Float>(finalColor.x, finalColor.y, finalColor.z, 1.0))
            biomeCounts[biome] = (biomeCounts[biome] ?? 0) + 1
        }

        print("Biome Counts: \(biomeCounts)")
        changeColorMap(map: biomeMap)
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
    
    func showHumidity() {
        let humidityMap: [Float] = humidity.humidityMap

        // Define a color map for humidity (e.g., white for dry, blue for moist)
        let dryColor = SIMD4<Float>(1.0, 1.0, 1.0, 1.0) // White
        let moistColor = SIMD4<Float>(0.0, 0.0, 1.0, 1.0) // Blue

        let colorMap: [SIMD4<Float>] = humidityMap.map { humidityValue in
            return lerpColor(dryColor, moistColor, humidityValue)
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
