//
//  Orchestrator.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 22/03/2025.
//

import Foundation
import MetalKit

let sizes: [Int] = [12, 42, 162, 642, 2562]

class Orchestrator {
    var renderControl: RenderControl
    
    let elevation: Elevation    
    
    init(renderControl: RenderControl, device: MTLDevice) {
        self.renderControl = renderControl
        self.elevation = Elevation(device: device)
    }
}
