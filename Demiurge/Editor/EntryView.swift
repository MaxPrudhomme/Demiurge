//
//  EntryView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 08/04/2025.
//

import SwiftUI

struct EntryView: View {
    var planetName: String
    var planetConfig: PlanetConfig

    var renderControl: RenderControl

    @Environment(\.presentationMode) var presentationMode

    init(planetName: String, planetConfig: PlanetConfig, renderControl: RenderControl) {
        self.planetName = planetName
        self.planetConfig = planetConfig
        self.renderControl = renderControl
    }

    func loadPlanet() {
        renderControl.seed = planetConfig.seed
        renderControl.planetName = planetConfig.planetName
        renderControl.elevationController = planetConfig.elevationController
        renderControl.temperatureController = planetConfig.temperatureController
        renderControl.humidityController = planetConfig.humidityController
    }

    var body: some View {
        HStack {
            Text(planetName)
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: {
                loadPlanet()
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}
