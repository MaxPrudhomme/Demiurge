//
//  LayerMenuView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 21/03/2025.
//

import SwiftUI

struct LayerMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .symbolEffect(.bounce.up.byLayer, value: configuration.isPressed)
            .foregroundStyle(.blue)
    }
}

struct LayerMenuView: View {
    var renderControl: RenderControl
    @State private var bounce_layer = false
    @State private var layer: String = "All layers"
    
    var body: some View {
        Menu { // Picker is in a menu to avoid the value being shown when in .menu mode
            Picker(selection: $layer, label: Text("Layer options")) {
                Label("Temperature", systemImage: "thermometer.high")
                .tag("Temperature")
                
                Label("Humidity", systemImage: "humidity")
                .tag("Humidity")
                
                Label("Elevation", systemImage: "mountain.2")
                .tag("Elevation")
                
                Label("All layers", systemImage: "globe.americas")
                .tag("All layers")
            }
            .onChange(of: layer) { oldValue, newValue in
                handleLayerChange(newValue)
            }
        } label: {
            Image(systemName: "square.3.layers.3d.top.filled")
                .font(.system(size: 24))
                .frame(width: 32, height: 32)
                
        }
        .buttonStyle(LayerMenuButtonStyle())
        .padding(8)
    }
    
    private func handleLayerChange(_ newValue: String) {
        renderControl.layer = newValue
    }
}
