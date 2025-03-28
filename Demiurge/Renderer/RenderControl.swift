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
    @Published var subdivisions: Int = 5
    
    // Orchestrator Controller
    @Published var layer: String = "All layers"
}
