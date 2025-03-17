//
//  ContentView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 13/03/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            MetalView()
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Text("Demiurge")
                        .font(.title)
                        .padding()
                    Spacer()
                }
                .background(Color.gray.opacity(0.5))

                Spacer()

                HStack {
                    Spacer()
                    Text("Navigation")
                        .padding()
                    Spacer()
                }
                .background(Color.gray.opacity(0.5))
            }
        }
    }
}

#Preview {
    ContentView()
}
