//
//  RenderControl.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 21/03/2025.
//

import SwiftUI

class RenderControl: ObservableObject {
    // Renderer Controller
    @Published var rotate: Bool = true
    @Published var rescale: Bool = false
    
    // Mesh Controller
    @Published var subdivisions: Int = 3
    
    @Published var planetName: String = generateNewPlanetName(current: "Earth")
    
    // Orchestrator Controller
    @Published var layer: String = "All layers"
    
    // Continent Scale / Ocean Ratio / Variance
    @Published var elevationController: [Float] = [2.5, 0.65, 1.0]
    
    // Equator Temperature / Pole Drop / Temperature Lapse Rate
    @Published var temperatureController: [Float] = [0.8, 0.9, 0.5]
    
    // Equator Humidity / Polar Humidity Drop / Elevation Humidity Drop / Water Influence
    @Published var humidityController: [Float] = [0.7, 0.8, 0.6, 0.4]
    
    @Published var seed: Int = Int.random(in: 0..<10000)
    
    public static func generateNewPlanetName(current: String) -> String {
        var newName: String
        repeat {
            let letters = String((0..<2).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".randomElement()! })
            let numbers = Int.random(in: 10...99)
            let suffix = ["A", "B", "C", "D", "E", "F"].randomElement()!
            newName = "Planet \(letters)\(numbers)-\(suffix)"
        } while newName == current
        return newName
    }
}
