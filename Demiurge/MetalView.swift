//
//  MetalView.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 17/03/2025.
//


import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    
    class Coordinator: NSObject, MTKViewDelegate {
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize if needed
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable else { return }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = view.clearColor
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            
            guard let commandBuffer = view.device?.makeCommandQueue()?.makeCommandBuffer(),
                  let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true
        metalView.clearColor = MTLClearColorMake(0.0, 1.0, 0.0, 1.0) // Green
        metalView.delegate = context.coordinator
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = false // Set to false to enable rendering
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.setNeedsDisplay()
    }
}