//
//  HumidityView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 08/04/2025.
//

import SwiftUI

struct HumidityView: View {
    @ObservedObject var renderControl: RenderControl

    @State private var equatorHumidity: Float
    @State private var polarHumidityDrop: Float
    @State private var elevationHumidityDropRate: Float
    @State private var waterInfluence: Float

    @State private var equatorHumidityInfo: Bool = false
    @State private var polarHumidityDropInfo: Bool = false
    @State private var elevationHumidityDropRateInfo: Bool = false
    @State private var waterInfluenceInfo: Bool = false

    init(renderControl: RenderControl) {
        self.renderControl = renderControl
        _equatorHumidity = State(initialValue: renderControl.humidityController[0])
        _polarHumidityDrop = State(initialValue: renderControl.humidityController[1])
        _elevationHumidityDropRate = State(initialValue: renderControl.humidityController[2])
        _waterInfluence = State(initialValue: renderControl.humidityController[3])
    }

    var body: some View {
        VStack {
            // Equator Humidity
            HStack {
                Text("Equator Humidity")
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Button(action: {
                    equatorHumidityInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                })
                .popover(isPresented: $equatorHumidityInfo,
                         content: {
                    Text("Base humidity at the equator (latitude 0).")
                        .presentationCompactAdaptation(.popover)
                })
            }

            HStack {
                Slider(value: $equatorHumidity, in: 0.0...1.0, step: 0.01)
                    .padding()
                    .onChange(of: equatorHumidity) { oldValue, newValue in
                        renderControl.humidityController[0] = newValue
                    }

                Text("\(String(format: "%.2f", equatorHumidity))")
                    .frame(width: 40)
            }
            .padding(.top, -16)

            Divider()

            // Polar Humidity Drop
            HStack {
                Text("Pole Drop")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: {
                    polarHumidityDropInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                })
                .popover(isPresented: $polarHumidityDropInfo,
                         content: {
                    Text("How much humidity decreases towards the poles.")
                        .presentationCompactAdaptation(.popover)
                })
            }

            HStack {
                Slider(value: $polarHumidityDrop, in: 0.0...1.0, step: 0.01)
                    .padding()
                    .onChange(of: polarHumidityDrop) { oldValue, newValue in
                        renderControl.humidityController[1] = newValue
                    }

                Text("\(String(format: "%.2f", polarHumidityDrop))")
                    .frame(width: 40)
            }
            .padding(.top, -16)

            Divider()

            // Elevation Humidity Drop Rate
            HStack {
                Text("Elevation Drop Rate")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: {
                    elevationHumidityDropRateInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                })
                .popover(isPresented: $elevationHumidityDropRateInfo,
                         content: {
                    Text("How much humidity decreases with increasing elevation.")
                        .presentationCompactAdaptation(.popover)
                })
            }

            HStack {
                Slider(value: $elevationHumidityDropRate, in: 0.0...1.0, step: 0.01)
                    .padding()
                    .onChange(of: elevationHumidityDropRate) { oldValue, newValue in
                        renderControl.humidityController[2] = newValue
                    }

                Text("\(String(format: "%.2f", elevationHumidityDropRate))")
                    .frame(width: 40)
            }
            .padding(.top, -16)

            Divider()

            // Water Influence
            HStack {
                Text("Water Influence")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: {
                    waterInfluenceInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                })
                .popover(isPresented: $waterInfluenceInfo,
                         content: {
                    Text("How much proximity to water (low elevation) increases humidity.")
                        .presentationCompactAdaptation(.popover)
                })
            }

            HStack {
                Slider(value: $waterInfluence, in: 0.0...1.0, step: 0.01)
                    .padding()
                    .onChange(of: waterInfluence) { oldValue, newValue in
                        renderControl.humidityController[3] = newValue
                    }

                Text("\(String(format: "%.2f", waterInfluence))")
                    .frame(width: 40)
            }
            .padding(.top, -16)
        }
        .padding(.horizontal, 32)
    }
}
