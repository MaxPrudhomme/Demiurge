//
//  Humidity.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 08/04/2025.
//

import Foundation
import simd
import Combine

class Humidity {
    var humidityMap: [Float]
    let tileCount: Int
    var renderControl: RenderControl
    private var noiseGenerator: SimplexNoise
    
    // 1. Equator Humidity: Base humidity at the equator (latitude 0). (Range: 0.0 - 1.0, where 1.0 is most humid)
    var equatorHumidity: Float = 0.7

    // 2. Polar Humidity Drop: How much humidity decreases towards the poles. (Range: 0.0 - 1.0, where 1.0 means poles are very dry)
    var polarHumidityDrop: Float = 0.8

    // 3. Elevation Humidity Drop Rate: How much humidity decreases with increasing elevation. (Value represents humidity drop per unit of elevation)
    var elevationHumidityDropRate: Float = 0.6 // Higher value means faster drop with elevation

    // 4. Water Influence: How much proximity to water (low elevation) increases humidity. (Range: 0.0 - 1.0)
    var waterInfluence: Float = 0.4

    var noiseInfluence: Float = 0.2
    var noiseScale: Float = 3.0 // Controls the frequency/scale of humidity noise

    // --- Initialization ---
    init(tiles: Int, seed: Int = Int.random(in: 0..<10000), renderControl: RenderControl) {
        self.tileCount = tiles
        self.humidityMap = [Float](repeating: 0, count: tiles)
        self.noiseGenerator = SimplexNoise(seed: seed)
        self.renderControl = renderControl

        self.equatorHumidity = renderControl.humidityController[0]
        self.polarHumidityDrop = renderControl.humidityController[1]
        self.elevationHumidityDropRate = renderControl.humidityController[2]
        self.waterInfluence = renderControl.humidityController[3]
        // self.noiseInfluence = renderControl.humidityController[4]
        // self.noiseScale = renderControl.humidityController[5]
    }

    func modifyHumidity(newValues: [Float], mesh: Mesh, elevation: Elevation, seed: Int? = nil) {
        if let seed = seed {
            self.noiseGenerator = SimplexNoise(seed: seed)
        }
        self.equatorHumidity = newValues[0]
        self.polarHumidityDrop = newValues[1]
        self.elevationHumidityDropRate = newValues[2]
        self.waterInfluence = newValues[3]
        // self.noiseInfluence = newValues[4]
        // self.noiseScale = newValues[5]

        generateHumidity(mesh: mesh, elevation: elevation)
    }

    func generateHumidity(mesh: Mesh, elevation: Elevation) {
        guard elevation.heightMap.count == tileCount else {
            print("Error: Elevation heightMap count does not match tileCount for humidity generation.")
            return
        }

        for i in 0..<tileCount {
            let centerVertex = mesh.getVertex(forVertexIndex: mesh.tileIndex[i])
            let pos = centerVertex.position.normalized() // Position on unit sphere

            // 1. Latitude Factor
            let latitude = abs(pos.y) // 0 at equator, 1 at poles
            let latitudeHumidity = equatorHumidity * (1.0 - latitude * polarHumidityDrop)

            // 2. Elevation Factor
            let currentElevation = elevation.heightMap[i]
            let elevationFactor = max(0.0, currentElevation) // Consider only elevation above sea level
            let elevationHumidityDrop = elevationFactor * elevationHumidityDropRate
            var finalHumidity = latitudeHumidity - elevationHumidityDrop

            // 3. Water Influence (Simple approach: lower elevation = more water influence)
            // You might need to adjust the threshold based on your elevation data
            let seaLevelThreshold: Float = 0.0 // Assuming 0.0 is roughly sea level
            if currentElevation <= seaLevelThreshold {
                finalHumidity += waterInfluence * (1.0 - elevationFactor) // Higher influence at or below sea level
            }

            // 4. Noise Factor
            let noiseValue = noiseGenerator.noise(x: pos.x * noiseScale, y: pos.y * noiseScale, z: pos.z * noiseScale)
            let normalizedNoise = (noiseValue + 1.0) * 0.5 // Normalize to 0-1
            let noiseEffect = (normalizedNoise - 0.5) * noiseInfluence
            finalHumidity += noiseEffect

            // 5. Clamp Final Humidity
            humidityMap[i] = finalHumidity.clamped(to: 0.0...1.0)
        }
    }
}
