//
//  MatrixUtils.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 17/03/2025.
//

import simd

struct MatrixUtils {
    static func perspective(fovy: Float, aspect: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
        let ys = 1 / tan(fovy * 0.5)
        let xs = ys / aspect
        let zs = farZ / (nearZ - farZ)

        return matrix_float4x4([
            SIMD4<Float>(xs, 0, 0, 0),
            SIMD4<Float>(0, ys, 0, 0),
            SIMD4<Float>(0, 0, zs, -1),
            SIMD4<Float> (0, 0, zs * nearZ, 0)
        ])
    }

    static func rotation(angle: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
        return matrix_float4x4(simd_quaternion(angle, normalize(axis)))
    }

    static func rotationAroundAxes(xAngle: Float, yAngle: Float) -> matrix_float4x4 {
        let rotationX = rotation(angle: xAngle, axis: SIMD3<Float>(1, 0, 0))
        let rotationY = rotation(angle: yAngle, axis: SIMD3<Float>(0, 1, 0))
        
        // Combine rotations (order matters!)
        return matrix_multiply(rotationX, rotationY)
    }
    
    static func rotationAroundAxesInDegrees(xDegrees: Float, yDegrees: Float) -> matrix_float4x4 {
        let xRadians = xDegrees * (.pi / 180.0)
        let yRadians = yDegrees * (.pi / 180.0)
        return rotationAroundAxes(xAngle: xRadians, yAngle: yRadians)
    }
    
    static func translation(x: Float, y: Float, z: Float) -> matrix_float4x4 {
        return matrix_float4x4(columns: (SIMD4<Float>(1, 0, 0, 0), SIMD4<Float>(0, 1, 0, 0), SIMD4<Float>(0, 0, 1, 0), SIMD4<Float>(x, y, z, 1)))
    }
    
    static func scale(x: Float, y: Float, z: Float) -> matrix_float4x4 {
        return matrix_float4x4(
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}
