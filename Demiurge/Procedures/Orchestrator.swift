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
        self.elevation = Elevation(device: device)
        self.mesh = mesh
        
    }
}
