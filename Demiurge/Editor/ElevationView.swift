//
//  ElevationView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 28/03/2025.
//

import SwiftUI

struct ElevationView: View {
    var renderControl: RenderControl
    
    @State private var continentScale: Float
    @State private var oceanRatio: Float
    @State private var continentScaleInfo: Bool = false
    @State private var oceanRatioInfo: Bool = false
    
    init(renderControl: RenderControl) {
        self.renderControl = renderControl
        _continentScale = State(initialValue: renderControl.elevationController[0])
        _oceanRatio = State(initialValue: renderControl.elevationController[1])
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Continent Scale")
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Button(action: {
                    continentScaleInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        
                })
                .popover(isPresented: $continentScaleInfo,
                     content: {
                Text("Continent scale will affect the number of continents generated.")
                    .presentationCompactAdaptation(.popover)
                })
            }
            
            HStack {
                Slider(value: $continentScale, in: 0.5...5.0, step: 0.1)
                    .padding()
                    .onChange(of: continentScale) { oldValue, newValue in
                        renderControl.elevationController[0] = newValue
                    }
                
                Text("\(String(format: "%.1f", continentScale))")
                    .frame(width: 32)
            }
            .padding(.top, -16)
            
            HStack {
                Text("Ocean Ratio")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: {
                    oceanRatioInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        
                })
                .popover(isPresented: $oceanRatioInfo,
                     content: {
                Text("Ocean ratio affects the amound of water on the planet.")
                    .presentationCompactAdaptation(.popover)
                })
            }
            
            HStack {
                Slider(value: $oceanRatio, in: 0.0...1.0, step: 0.1)
                    .padding()
                    .onChange(of: oceanRatio) { oldValue, newValue in
                        renderControl.elevationController[1] = newValue
                    }
                
                Text("\(String(format: "%.2f", oceanRatio))")
                    .frame(width: 36)
            }
            .padding(.top, -16)
        
        }
        .padding(.horizontal, 32)
    }
}
