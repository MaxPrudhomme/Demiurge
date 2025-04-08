//
//  EditorMenuView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 28/03/2025.
//

import SwiftUI

struct EditorMenuView: View {
    var renderControl: RenderControl
    @State private var selectedOption: String = "Elevation"
    
    var body: some View {
        VStack {
            Picker("Select Parameter", selection: $selectedOption) {
                Text("Temperature").tag("Temperature")
                Text("Elevation").tag("Elevation")
                Text("Moisture").tag("Moisture")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(16)
            
            if selectedOption == "Elevation" {
                ElevationView(renderControl: renderControl)
            } else if selectedOption == "Temperature" {
                TemperatureView(renderControl: renderControl)
            }
        }
    }
}
