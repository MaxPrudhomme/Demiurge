//
//  Temperature.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 08/04/2025.
//

import Foundation
import simd
import Combine

class Temperature {
    var temperatureMap: [Float]
    let tileCount: Int
    var renderControl: RenderControl // Assuming RenderControl holds temperature parameters too
    private var noiseGenerator: SimplexNoise

    // 1. Equator Temperature: Base temperature at the equator (latitude 0), at sea level. (Range: 0.0 - 1.0, where 1.0 is hottest)
    var equatorTemperature: Float = 0.8

    // 2. Polar Temperature Drop: How much colder the poles are compared to the equator. (Range: 0.0 - 1.0, where 1.0 means poles are absolute coldest)
    var polarTemperatureDrop: Float = 0.9

    // 3. Temperature Lapse Rate: How much temperature decreases with increasing elevation. (Value represents temp drop per unit of elevation, e.g., per 'highPeakLevel' unit)
    var temperatureLapseRate: Float = 0.5 // A value of 0.5 means at the highest peaks, temp drops by 50% of the base range.

    var noiseInfluence: Float = 0.1
    var noiseScale: Float = 4.0

    init(tiles: Int, seed: Int = Int.random(in: 0..<10000), renderControl: RenderControl) {
        self.tileCount = tiles
        self.temperatureMap = [Float](repeating: 0, count: tiles)
        self.noiseGenerator = SimplexNoise(seed: seed)
        self.renderControl = renderControl

         self.equatorTemperature = renderControl.temperatureController[0]
         self.polarTemperatureDrop = renderControl.temperatureController[1]
         self.temperatureLapseRate = renderControl.temperatureController[2]
        // self.noiseInfluence = renderControl.temperatureController[3]
        // self.noiseScale = renderControl.temperatureController[4]
    }

    func modifyTemperature(newValues: [Float], mesh: Mesh, elevation: Elevation, seed: Int? = nil) {
        if let seed = seed {
            self.noiseGenerator = SimplexNoise(seed: seed)
        }
        self.equatorTemperature = newValues[0]
        self.polarTemperatureDrop = newValues[1]
        self.temperatureLapseRate = newValues[2]
//        self.noiseInfluence = newValues[3]
//        self.noiseScale = newValues[4]

        generateTemperature(mesh: mesh, elevation: elevation)
    }

    func generateTemperature(mesh: Mesh, elevation: Elevation) {
        guard elevation.heightMap.count == tileCount else {
            print("Error: Elevation heightMap count does not match tileCount.")
            return
        }

        for i in 0..<tileCount {
            let centerVertex = mesh.getVertex(forVertexIndex: mesh.tileIndex[i])
            let pos = centerVertex.position.normalized() // Position on unit sphere

            // 1. Calculate Latitude Factor
            // Assuming Y is the polar axis. Latitude is 0 at equator (y=0), 1 at poles (|y|=1).
            let latitude = abs(pos.y) // Value from 0 (equator) to 1 (poles)
            let latitudeTemperature = equatorTemperature * (1.0 - latitude * polarTemperatureDrop)

            // 2. Calculate Elevation Factor
            // Temperature decreases as elevation increases above sea level.
            // Normalize elevation relative to sea level (0.0) for calculation.
            // We only consider elevation *above* sea level for cooling.
            let currentElevation = elevation.heightMap[i]
            let elevationAboveSea = max(0.0, currentElevation)
            let referenceMaxElevation: Float = 1.0
            let elevationFactor = (elevationAboveSea / referenceMaxElevation) * temperatureLapseRate
            let elevationTemperatureDrop = min(elevationFactor, 1.0) // Cap drop at 100%

            let noiseValue = noiseGenerator.noise(x: pos.x * noiseScale, y: pos.y * noiseScale, z: pos.z * noiseScale)
            let normalizedNoise = (noiseValue + 1.0) * 0.5 // Normalize noise to 0-1
            let noiseEffect = (normalizedNoise - 0.5) * noiseInfluence

            var finalTemperature = latitudeTemperature - elevationTemperatureDrop
            finalTemperature += noiseEffect

            // 5. Clamp Final Temperature (ensure it stays within 0.0 - 1.0 range)
            temperatureMap[i] = finalTemperature.clamped(to: 0.0...1.0)
        }
    }

    private func printTemperatureStats() {
        let sorted = temperatureMap.sorted()
        let minTemp = sorted.first ?? 0
        let maxTemp = sorted.last ?? 0
        let medianTemp = sorted[sorted.count / 2]
        let avgTemp = temperatureMap.reduce(0, +) / Float(tileCount)

        print("Temperature stats (0=Cold, 1=Hot):")
        print("  Range: \(minTemp) to \(maxTemp)")
        print("  Median: \(medianTemp)")
        print("  Average: \(avgTemp)")

        var frozen = 0, cold = 0, temperate = 0, warm = 0, hot = 0
        for temp in temperatureMap {
            if temp < 0.1 { frozen += 1 }
            else if temp < 0.3 { cold += 1 }
            else if temp < 0.6 { temperate += 1 }
            else if temp < 0.8 { warm += 1 }
            else { hot += 1 }
        }
        print("  Distribution:")
        print("    Frozen (<0.1): \(frozen) (\(Float(frozen)/Float(tileCount)*100)%)")
        print("    Cold   (0.1-0.3): \(cold) (\(Float(cold)/Float(tileCount)*100)%)")
        print("    Temperate(0.3-0.6): \(temperate) (\(Float(temperate)/Float(tileCount)*100)%)")
        print("    Warm   (0.6-0.8): \(warm) (\(Float(warm)/Float(tileCount)*100)%)")
        print("    Hot    (>0.8): \(hot) (\(Float(hot)/Float(tileCount)*100)%)")
    }
}
