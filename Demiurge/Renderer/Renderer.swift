//
//  Renderer.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 17/03/2025.
//

import SwiftUI
import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {
    var renderControl: RenderControl!
    
    var orchestrator : Orchestrator!
    
    var device: MTLDevice!
    var pipelineState: MTLRenderPipelineState!
    var edgePipelineState: MTLRenderPipelineState!
    var vertexPipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var uniformBuffer: MTLBuffer!
    
    var mesh: Mesh_Sphere!
    var subdivisions: Int
    
    var renderScale: Float = 0.5
    var baseScale: Float = 0.5
    var initialScale: Float? = nil
    var scalingSpeed: Float = 0.01
    var isRescaling: Bool = false
    
    // Debug flags
    var showVertices: Bool = false
    
    // Defined as degrees
    var initialAngle: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    // Defined as radians
    var rotationAngle: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    var rotationMatrix: matrix_float4x4 = matrix_identity_float4x4
    var rotationVelocity: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    var lastTouchLocation: CGPoint?
    var isDragging: Bool = false

    var triangleDepthStencilState: MTLDepthStencilState!
    var edgeDepthStencilState: MTLDepthStencilState!
    var pointDepthStencilState: MTLDepthStencilState!
    
    let vertexPointSize: Float = 10.0
    
    var minScale: Float = 0.01
    var maxScale: Float = 1.8
    
    var scalingVelocity: Float = 0.0
    var rotationSpeed: Float = 0.0025

    var currentSubdivisions: Int = 3
    
    init(renderControl: RenderControl) {
        self.renderControl = renderControl
        self.subdivisions = renderControl.subdivisions
        
        super.init()

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }            
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        mesh = Mesh_Sphere(device: device, subdivisions: subdivisions)

        orchestrator = Orchestrator(renderControl: renderControl, device: device, mesh: mesh)
        
        currentSubdivisions = renderControl.subdivisions
        
        setupDepthStencilStates()
        setupPipeline()
        setupUniforms()
        
        rotationMatrix = MatrixUtils.rotationAroundAxesInDegrees(xDegrees: initialAngle.x, yDegrees: initialAngle.y)
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let velocity = gesture.velocity(in: gesture.view)
 
        let sensitivity: Float = 0.005
        let angleX = Float(translation.y) * sensitivity
        let angleY = Float(translation.x) * sensitivity
 
        let rotation = MatrixUtils.rotationAroundAxes(xAngle: angleX, yAngle: angleY)
        
        rotationMatrix = matrix_multiply(rotation, rotationMatrix)
 
        rotationVelocity = SIMD2<Float>(Float(velocity.x) * sensitivity * 0.02, Float(velocity.y) * sensitivity * 0.02)
 
        isDragging = (gesture.state != .ended)
        
        renderControl.rotate = false

        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let scale = Float(gesture.scale)

        let sensitivity: Float = 0.1
        let zoomAmount = (scale - 1.0) * sensitivity

        renderScale = max(minScale, min(maxScale, renderScale + zoomAmount))

        scalingVelocity = Float(gesture.velocity) * sensitivity * 0.02

        gesture.scale = 1.0
    }

    func updateScalingInertia() {
        let friction: Float = 0.95

        if !renderControl.rescale {
            if abs(scalingVelocity) > 0.0001 {
                renderScale += scalingVelocity
                scalingVelocity *= friction
            } else {
                scalingVelocity = 0
            }

            renderScale = max(minScale, min(maxScale, renderScale))
        }
    }

    func updateRescale() {
        if renderControl.rescale && renderScale != baseScale {
            let speedMultiplier: Float = 10.0
            let isUpscaling = renderScale < baseScale
            
            if isUpscaling {
                renderScale += scalingSpeed * speedMultiplier
                renderScale = min(renderScale, maxScale)
                if renderScale >= baseScale {
                    renderScale = baseScale
                    renderControl.rescale = false
                }
            } else {
                renderScale -= scalingSpeed * speedMultiplier
                renderScale = max(renderScale, minScale)
                if renderScale <= baseScale {
                    renderScale = baseScale
                    renderControl.rescale = false
                }
            }
        }
    }

    func stopInertiaOnAutoRescale() {
        if renderControl.rescale {
            scalingVelocity = 0
        }
    }

    func updateRotationInertia() {
        let friction: Float = 0.98

        if !isDragging {
            if simd_length(rotationVelocity) > 0.0001 {
                let rotation = MatrixUtils.rotationAroundAxes(xAngle: rotationVelocity.y, yAngle: rotationVelocity.x)
                
                rotationMatrix = matrix_multiply(rotation, rotationMatrix)

                rotationVelocity *= friction
            } else {
                rotationVelocity = SIMD2<Float>(0, 0)
            }
        }
    }

    func updateAutorotation() {
        // Only start autorotation if the flag is true
        if renderControl.rotate {
            let rotationMatrixY = MatrixUtils.rotationAroundAxes(xAngle: 0, yAngle: rotationSpeed)
            rotationMatrix = matrix_multiply(rotationMatrix, rotationMatrixY)
        }
    }

    func updateMesh() {
        if renderControl.subdivisions == currentSubdivisions {
            return
        }
        
        let newMesh = Mesh_Sphere(device: device, subdivisions: renderControl.subdivisions)
        let newOrchestrator: Orchestrator = Orchestrator(renderControl: renderControl, device: device, mesh: newMesh)
        
        mesh = newMesh
        orchestrator = newOrchestrator
        
        currentSubdivisions = renderControl.subdivisions
    }
    
    func setupDepthStencilStates() {
        let triangleDescriptor = MTLDepthStencilDescriptor()
        triangleDescriptor.depthCompareFunction = .less
        triangleDescriptor.isDepthWriteEnabled = true
        triangleDepthStencilState = device.makeDepthStencilState(descriptor: triangleDescriptor)
        
        let edgeDescriptor = MTLDepthStencilDescriptor()
        edgeDescriptor.depthCompareFunction = .lessEqual
        edgeDescriptor.isDepthWriteEnabled = false
        edgeDepthStencilState = device.makeDepthStencilState(descriptor: edgeDescriptor)
        
        let pointDescriptor = MTLDepthStencilDescriptor()
        pointDescriptor.depthCompareFunction = .lessEqual
        pointDescriptor.isDepthWriteEnabled = false
        pointDepthStencilState = device.makeDepthStencilState(descriptor: pointDescriptor)
    }
    
    func setupPipeline() {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: "fragmentShader"),
              let edgeFragmentFunction = library.makeFunction(name: "edgeFragmentShader"),
              let vertexFragmentFunction = library.makeFunction(name: "vertexPointFragmentShader") else {
            fatalError("Failed to create shader functions")
        }
        
        // Define the vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()

        // Vertex Position
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        // Layout: stride matches the full Vertex struct
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        // Apply to pipeline descriptors
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        let edgePipelineDescriptor = MTLRenderPipelineDescriptor()
        edgePipelineDescriptor.vertexFunction = vertexFunction
        edgePipelineDescriptor.fragmentFunction = edgeFragmentFunction
        edgePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        edgePipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        edgePipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        // Vertex point pipeline
        let vertexPointPipelineDescriptor = MTLRenderPipelineDescriptor()
        vertexPointPipelineDescriptor.vertexFunction = vertexFunction
        vertexPointPipelineDescriptor.fragmentFunction = vertexFragmentFunction
        vertexPointPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        vertexPointPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        vertexPointPipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            edgePipelineState = try device.makeRenderPipelineState(descriptor: edgePipelineDescriptor)
            vertexPipelineState = try device.makeRenderPipelineState(descriptor: vertexPointPipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    func setupUniforms() {
        let uniformsSize = MemoryLayout<matrix_float4x4>.stride
        uniformBuffer = device.makeBuffer(length: uniformsSize, options: [])
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func toRadians(fromDegrees degrees: SIMD2<Float>) -> SIMD2<Float> {
        return SIMD2<Float>(x: degrees.x * (.pi / 180.0), y: degrees.y * (.pi / 180.0))
    }
    
    func draw(in view: MTKView) {
        updateAutorotation()
        updateRescale()
        updateScalingInertia()
        
        updateMesh()
        
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
        
        updateRotationInertia()
        
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = MatrixUtils.perspective(fovy: .pi/3, aspect: aspect, nearZ: 0.1, farZ: 100)
        var modelViewMatrix = MatrixUtils.translation(x: 0, y: 0, z: -2)
        modelViewMatrix = matrix_multiply(modelViewMatrix, rotationMatrix)
        modelViewMatrix = matrix_multiply(modelViewMatrix, MatrixUtils.scale(x: renderScale, y: renderScale, z: renderScale))
        var mvpMatrix = matrix_multiply(projectionMatrix, modelViewMatrix)
        memcpy(uniformBuffer.contents(), &mvpMatrix, MemoryLayout<matrix_float4x4>.stride)
        
        var pointSize = vertexPointSize
        let pointSizeBuffer = device.makeBuffer(bytes: &pointSize, length: MemoryLayout<Float>.size, options: [])

        // Draw filled triangles
        commandEncoder.setDepthStencilState(triangleDepthStencilState)
        commandEncoder.setRenderPipelineState(pipelineState)
        commandEncoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        commandEncoder.setVertexBuffer(pointSizeBuffer, offset: 0, index: 2)
        commandEncoder.setVertexBuffer(mesh.colorBuffer, offset: 0, index: 3)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.faceIndexCount, indexType: .uint32, indexBuffer: mesh.faceIndexBuffer, indexBufferOffset: 0)

        // Draw edges
        commandEncoder.setDepthStencilState(edgeDepthStencilState)
        commandEncoder.setRenderPipelineState(edgePipelineState)
        commandEncoder.setCullMode(.back)
        commandEncoder.setVertexBuffer(pointSizeBuffer, offset: 0, index: 2)
        commandEncoder.drawIndexedPrimitives(type: .line, indexCount: mesh.edgeIndexCount, indexType: .uint32, indexBuffer: mesh.edgeIndexBuffer, indexBufferOffset: 0)

        if showVertices {
            // Draw vertices as points
            commandEncoder.setDepthStencilState(pointDepthStencilState)
            commandEncoder.setRenderPipelineState(vertexPipelineState)
            commandEncoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            commandEncoder.setVertexBuffer(pointSizeBuffer, offset: 0, index: 2)
            commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: mesh.vertexCount)
        }
        
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
