//
//  ControlView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 21/03/2025.
//

import SwiftUI

struct ControlView: View {
    var renderControl: RenderControl
    
    @State private var rotate = false
    @State private var bounce_glass = false
    
    func autoRotate() {
        renderControl.rotate = true
    }
    
    func resetZoom() {
        renderControl.rescale = true
    }
    
    var body: some View {
        VStack {
            VStack { // First panel stack
                Button(action: {
                    autoRotate()
                    rotate.toggle()
                }, label: {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: 24))
                        .frame(width: 32, height: 32)
                        .symbolEffect(.rotate.wholeSymbol, options: .nonRepeating, value: rotate)
                })
                .padding(8)
                
                Button(action: {
                    resetZoom()
                    bounce_glass.toggle()
                }, label: {
                    Image(systemName: "scale.3d")
                        .font(.system(size: 24))
                        .frame(width: 32, height: 32)
                        .symbolEffect(.bounce, value: bounce_glass)
                })
                .padding(.bottom, 8)
                .padding(.leading, 8)
                .padding(.trailing, 8)
            }
            .background(Material.regularMaterial)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)

            VStack { // Second Panel stack
                LayerMenuView(renderControl: renderControl)
            }
            .background(Material.regularMaterial)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 4)
        
    }
}
