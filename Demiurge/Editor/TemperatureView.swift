//
//  TemperatureView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 08/04/2025.
//

import SwiftUI

struct TemperatureView: View {
    @ObservedObject var renderControl: RenderControl

    @State private var equatorTemperature: Float
    @State private var polarTemperatureDrop: Float
    @State private var temperatureLapseRate: Float

    @State private var equatorTemperatureInfo: Bool = false
    @State private var polarTemperatureDropInfo: Bool = false
    @State private var temperatureLapseRateInfo: Bool = false

    init(renderControl: RenderControl) {
        self.renderControl = renderControl
        _equatorTemperature = State(initialValue: renderControl.temperatureController[0])
        _polarTemperatureDrop = State(initialValue: renderControl.temperatureController[1])
        _temperatureLapseRate = State(initialValue: renderControl.temperatureController[2])
    }

    var body: some View {
        VStack {
            // Equator Temperature
            HStack {
                Text("Equator Temperature")
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Button(action: {
                    equatorTemperatureInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                })
                .popover(isPresented: $equatorTemperatureInfo,
                         content: {
                    Text("Base temperature at the equator, at sea level.")
                        .presentationCompactAdaptation(.popover)
                })
            }

            HStack {
                Slider(value: $equatorTemperature, in: 0.0...1.0, step: 0.01)
                    .padding()
                    .onChange(of: equatorTemperature) { oldValue, newValue in
                        renderControl.temperatureController[0] = newValue
                    }

                Text("\(String(format: "%.2f", equatorTemperature))")
                    .frame(width: 40)
            }
            .padding(.top, -16)

            Divider()

            // Polar Temperature Drop
            HStack {
                Text("Pole Drop")
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Button(action: {
                    polarTemperatureDropInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                })
                .popover(isPresented: $polarTemperatureDropInfo,
                         content: {
                    Text("How much colder the poles are compared to the equator.")
                        .presentationCompactAdaptation(.popover)
                })
            }

            HStack {
                Slider(value: $polarTemperatureDrop, in: 0.0...1.0, step: 0.01)
                    .padding()
                    .onChange(of: polarTemperatureDrop) { oldValue, newValue in
                        renderControl.temperatureController[1] = newValue
                    }
                    .accessibilityIdentifier("poleDropSlider")

                Text("\(String(format: "%.2f", polarTemperatureDrop))")
                    .frame(width: 40)
            }
            .padding(.top, -16)

            Divider()

            // Temperature Lapse Rate
            HStack {
                Text("Lapse Rate")
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Button(action: {
                    temperatureLapseRateInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                })
                .popover(isPresented: $temperatureLapseRateInfo,
                         content: {
                    Text("How much temperature decreases with increasing elevation.")
                        .presentationCompactAdaptation(.popover)
                })
            }

            HStack {
                Slider(value: $temperatureLapseRate, in: 0.0...1.0, step: 0.01)
                    .padding()
                    .onChange(of: temperatureLapseRate) { oldValue, newValue in
                        renderControl.temperatureController[2] = newValue
                    }

                Text("\(String(format: "%.2f", temperatureLapseRate))")
                    .frame(width: 40)
            }
            .padding(.top, -16)
        }
        .padding(.horizontal, 32)
    }
}
