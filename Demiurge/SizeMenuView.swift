//
//  SizeMenuView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 27/03/2025.
//


import SwiftUI

struct SizeMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .symbolEffect(.bounce, value: configuration.isPressed)
            .foregroundStyle(.blue)
    }
}

struct SizeMenuView: View {
    var renderControl: RenderControl
    @State private var bounce_hexagon = false
    @State private var layer: Int = 3
    
    var body: some View {
        Menu { // Picker is in a menu to avoid the value being shown when in .menu mode
            Picker(selection: $layer, label: Text("Planet size")) {
                Text("0")
                .tag(0)
                
                Text("1")
                .tag(1)
                
                Text("2")
                .tag(2)
                
                Text("3")
                .tag(3)
                
                Text("4")
                .tag(4)
                
                Text("5")
                .tag(5)
            }
            .onChange(of: layer) { oldValue, newValue in
                handleLayerChange(newValue)
            }
        } label: {
            Image(systemName: "hexagon")
                .font(.system(size: 24))
                .frame(width: 32, height: 32)
                
        }
        .buttonStyle(LayerMenuButtonStyle())
        .pickerStyle(.segmented)
    }
    
    private func handleLayerChange(_ newValue: Int) {
        renderControl.subdivisions = newValue
    }
}
