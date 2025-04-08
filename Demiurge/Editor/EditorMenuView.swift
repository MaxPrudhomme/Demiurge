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
                Text("Humidity").tag("Humidity")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(16)
            
            if selectedOption == "Elevation" {
                ElevationView(renderControl: renderControl)
            } else if selectedOption == "Temperature" {
                TemperatureView(renderControl: renderControl)
            } else  if selectedOption == "Humidity" {
                HumidityView(renderControl: renderControl)
            }
        }
    }
}
