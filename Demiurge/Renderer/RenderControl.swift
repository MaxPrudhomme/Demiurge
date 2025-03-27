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
    @Published var subdivisions: Int = 0
    
    // Orchestrator Controller
    
        // Elevation parameters
        @Published var tectonicActivityFactor: Float = 1.0
        @Published var volcanicActivityFactor: Float = 0.5
        @Published var noiseFrequency: Float = 0.1
        @Published var noiseAmplitude: Float = 1.0
}
