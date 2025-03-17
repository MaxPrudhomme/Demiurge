//
//  Renderer.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 17/03/2025.
//

import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var pipelineState: MTLRenderPipelineState!
    var edgePipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var mesh: Mesh!
    var uniformBuffer: MTLBuffer!
    var rotationAngle: Float = 0.0
    
    var lastTouchLocation: CGPoint?
    var rotationMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    var rotationVelocity: SIMD2<Float> = SIMD2<Float>(0, 0)
    var isDragging: Bool = false

    // Two depth stencil states:
    var triangleDepthStencilState: MTLDepthStencilState!
    var edgeDepthStencilState: MTLDepthStencilState!
    
    override init() {
        super.init()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        setupDepthStencilStates()
        mesh = Mesh(device: device)
        setupPipeline()
        setupUniforms()
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let velocity = gesture.velocity(in: gesture.view)

        let sensitivity: Float = 0.005
        let angleX = Float(translation.x) * sensitivity
        let angleY = Float(translation.y) * sensitivity

        let rotationX = MatrixUtils.rotation(angle: angleY, axis: SIMD3<Float>(1, 0, 0))
        let rotationY = MatrixUtils.rotation(angle: angleX, axis: SIMD3<Float>(0, 1, 0))

        rotationMatrix = matrix_multiply(rotationX, rotationMatrix)
        rotationMatrix = matrix_multiply(rotationMatrix, rotationY)

        rotationVelocity = SIMD2<Float>(Float(velocity.x) * sensitivity * 0.02, Float(velocity.y) * sensitivity * 0.02)

        isDragging = (gesture.state != .ended)
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    func updateInertia() {
        let friction: Float = 0.98 // Lower friction = slower stop

        if !isDragging {
            if simd_length(rotationVelocity) > 0.0001 {
                let rotationX = MatrixUtils.rotation(angle: rotationVelocity.y, axis: SIMD3<Float>(1, 0, 0))
                let rotationY = MatrixUtils.rotation(angle: rotationVelocity.x, axis: SIMD3<Float>(0, 1, 0))

                rotationMatrix = matrix_multiply(rotationX, rotationMatrix)
                rotationMatrix = matrix_multiply(rotationMatrix, rotationY)

                rotationVelocity *= friction
            } else {
                rotationVelocity = SIMD2<Float>(0, 0)
            }
        }
    }
    
    func setupDepthStencilStates() {
        let triangleDescriptor = MTLDepthStencilDescriptor()
        triangleDescriptor.depthCompareFunction = .less
        triangleDescriptor.isDepthWriteEnabled = true
        triangleDepthStencilState = device.makeDepthStencilState(descriptor: triangleDescriptor)
        
        // For drawing edges. Changing to .lessEqual tolerates small precision differences.
        let edgeDescriptor = MTLDepthStencilDescriptor()
        edgeDescriptor.depthCompareFunction = .lessEqual
        edgeDescriptor.isDepthWriteEnabled = false
        edgeDepthStencilState = device.makeDepthStencilState(descriptor: edgeDescriptor)
    }
    
    func setupPipeline() {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: "fragmentShader"),
              let edgeFragmentFunction = library.makeFunction(name: "edgeFragmentShader") else {
            fatalError("Failed to create shader functions")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        let edgePipelineDescriptor = MTLRenderPipelineDescriptor()
        edgePipelineDescriptor.vertexFunction = vertexFunction
        edgePipelineDescriptor.fragmentFunction = edgeFragmentFunction
        edgePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        edgePipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            edgePipelineState = try device.makeRenderPipelineState(descriptor: edgePipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    func setupUniforms() {
        let uniformsSize = MemoryLayout<matrix_float4x4>.stride
        uniformBuffer = device.makeBuffer(length: uniformsSize, options: [])
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = view.clearColor
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        if let depthTexture = view.depthStencilTexture {
            renderPassDescriptor.depthAttachment.texture = depthTexture
            renderPassDescriptor.depthAttachment.loadAction = .clear
            renderPassDescriptor.depthAttachment.storeAction = .store
            renderPassDescriptor.depthAttachment.clearDepth = 1.0
        }
        
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        updateInertia()
        
        // Update uniforms
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = MatrixUtils.perspective(fovy: .pi/3, aspect: aspect, nearZ: 0.1, farZ: 100)
        var modelViewMatrix = MatrixUtils.translation(x: 0, y: 0, z: -2) // Keep the translation for positioning
        modelViewMatrix = matrix_multiply(modelViewMatrix, rotationMatrix) // Apply rotation first
        modelViewMatrix = matrix_multiply(modelViewMatrix, MatrixUtils.scale(x: 0.75, y: 0.75, z: 0.75)) // Then scale the cube
        var mvpMatrix = matrix_multiply(projectionMatrix, modelViewMatrix)
        memcpy(uniformBuffer.contents(), &mvpMatrix, MemoryLayout<matrix_float4x4>.stride)
        
        // Draw filled triangles
        commandEncoder.setDepthStencilState(triangleDepthStencilState)
        commandEncoder.setRenderPipelineState(pipelineState)
        commandEncoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indexCount, indexType: .uint16, indexBuffer: mesh.indexBuffer, indexBufferOffset: 0)
        
        // Draw edges only where triangle depth is nearly equal (visible portions)
        commandEncoder.setDepthStencilState(edgeDepthStencilState)
        commandEncoder.setRenderPipelineState(edgePipelineState)
        commandEncoder.setCullMode(.back) // Cull back–facing lines to hide hidden edges.
        commandEncoder.drawIndexedPrimitives(type: .line, indexCount: mesh.edgeIndexCount, indexType: .uint16, indexBuffer: mesh.edgeIndexBuffer, indexBufferOffset: 0)
        
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
