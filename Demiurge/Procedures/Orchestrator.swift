//
//  Orchestrator.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 22/03/2025.
//

import Foundation

let sizes: [Int] = [12, 42, 162, 642, 2562]

class Orchestrator {
    var renderControl: RenderControl
    
    let Elevation: Elevation
    
    var mapElevation: [Float] = []
    
    
    init(renderControl: RenderControl) {
        self.renderControl = renderControl
        self.Elevation = Demiurge.Elevation(tectonicActivityFactor: renderControl.tectonicActivityFactor, volcanicActivityFactor: renderControl.volcanicActivityFactor, noiseFrequency: renderControl.noiseFrequency, noiseAmplitude: renderControl.noiseAmplitude)
    }
    
    func run() -> [Float]{
        let tiles: Int = sizes[renderControl.subdivisions]
        mapElevation = Elevation.generateElevationMap(size: tiles)
        
        return mapElevation
    }
}
