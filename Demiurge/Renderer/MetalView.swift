//
//  MetalView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 17/03/2025.
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    var renderControl: RenderControl
    
    func makeCoordinator() -> Renderer {
        Renderer(renderControl: renderControl)
    }

    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true
        metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
        metalView.delegate = context.coordinator
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = false

        // Enable depth testing
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearDepth = 1.0
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePinch(_:)))
        metalView.addGestureRecognizer(panGesture)
        metalView.addGestureRecognizer(pinchGesture)
        
        return metalView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.setNeedsDisplay()
    }
}
