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
