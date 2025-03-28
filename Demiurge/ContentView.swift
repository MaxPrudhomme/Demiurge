//
//  ContentView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 13/03/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var renderControl = RenderControl()
    
    var body: some View {
        ZStack {
            MetalView(renderControl: renderControl)
                .edgesIgnoringSafeArea(.all)

            VStack { // Main App stack
                ControlView(renderControl: renderControl)
                
                Spacer()

                EditorView(renderControl: renderControl)
            }
        }
    }
}

#Preview {
    ContentView()
}
