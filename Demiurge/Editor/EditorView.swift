//
//  EditorView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 28/03/2025.
//

import SwiftUI

struct EditorView: View {
    var renderControl: RenderControl
    
    @State private var startingOffset: CGFloat = UIScreen.main.bounds.height * 0.59
    @State private var currentOffset: CGFloat = 0
    @State private var endOffset: CGFloat = 0
    
    @State private var bounce_binoculars = false
    @State private var bounce_dice = false
    @State private var isObservatoryPresented = false
    
    private let fullScreenThreshold: CGFloat = -150
    private let dismissThreshold: CGFloat = 150
    private let midScreenPosition: CGFloat = -UIScreen.main.bounds.height * 0.3
    
    private let maxDragUpDistance: CGFloat = 50
    
    func randomize() {
        renderControl.seed = Int.random(in: 0..<10000)
        renderControl.planetName = RenderControl.generateNewPlanetName(current: renderControl.planetName)
        
        renderControl.elevationController = [Float.random(in: 0.5...5.0), Float.random(in: 0.0...1.0)]
        renderControl.temperatureController = [Float.random(in: 0.0...1.0), Float.random(in: 0.0...1.0), Float.random(in: 0.0...1.0)]
        renderControl.humidityController = [Float.random(in: 0.0...1.0), Float.random(in: 0.0...1.0), Float.random(in: 0.0...1.0), Float.random(in: 0.0...1.0)]
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Drag indicator
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 5)
                        .cornerRadius(2.5)
                        .padding(.top, 10)
                        .accessibilityIdentifier("editorDraggable")
                    
                    HStack {
                        Button(action: {
                            bounce_binoculars.toggle()
                            isObservatoryPresented = true
                        }, label: {
                            Image(systemName: "binoculars.fill")
                                .font(.system(size: 24))
                                .frame(width: 32, height: 32)
                                .symbolEffect(.bounce.up.byLayer, value: bounce_binoculars)
                                .accessibilityIdentifier("observatoryButton")
                                
                        })
                        Spacer()
                        Text(renderControl.planetName)
                            .font(.title)
                        Spacer()
                        Button(action: {
                            randomize()
                            bounce_dice.toggle()
                        }, label: {
                            Image(systemName: "dice")
                                .font(.system(size: 24))
                                .frame(width: 32, height: 32)
                                .symbolEffect(.bounce.up.byLayer, value: bounce_dice)
                                .accessibilityIdentifier("randomizeButton")
                                
                        })
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    .padding(.horizontal, 32)
                    
                    EditorMenuView(renderControl: renderControl)

                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom + 200)
                .background(Material.regularMaterial)
                .cornerRadius(32, corners: [.topLeft, .topRight])
                .offset(y: startingOffset)
                .offset(y: limitDragDistance(currentOffset))
                .offset(y: endOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.3)) {
                                currentOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                // Full screen (top position)
                                if currentOffset < fullScreenThreshold {
                                    endOffset = -startingOffset
                                }
                                // Mid screen position
                                else if (currentOffset < 0 && endOffset == 0) ||
                                        (endOffset == -startingOffset && currentOffset > dismissThreshold) {
                                    endOffset = midScreenPosition
                                }
                                // Default position (bottom with header visible)
                                else if endOffset == midScreenPosition && currentOffset > dismissThreshold {
                                    endOffset = 0
                                }
                                
                                currentOffset = 0
                            }
                        }
                )
                .edgesIgnoringSafeArea(.bottom)
                .sheet(isPresented: $isObservatoryPresented) {
                    ObservatoryView(renderControl: renderControl)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // This function limits how far the user can drag the sheet
    private func limitDragDistance(_ distance: CGFloat) -> CGFloat {
        if endOffset == -startingOffset && distance < 0 {
            // When sheet is fully expanded, limit how far up it can be dragged
            // This creates a resistance effect when dragging beyond the top
            return max(distance, -maxDragUpDistance) / 2
        } else if distance > 250 {
            // Add resistance when dragging down too far
            let excess = distance - 250
            return 250 + (excess * 0.2)
        }
        return distance
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
