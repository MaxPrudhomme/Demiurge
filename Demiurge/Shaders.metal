//
//  Shaders.metal
//  Demiurge
//
//  Created by Max PRUDHOMME on 17/03/2025.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]], constant float4x4 &mvpMatrix [[buffer(1)]]) {
    VertexOut out;
    
    out.position = mvpMatrix * float4(in.position, 1.0);
    out.color = float4(0.0, 0.2, 1.0, 1.0);

    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}

// Fragment shader for edges - always returns black
fragment float4 edgeFragmentShader(VertexOut in [[stage_in]]) {
    return float4(1.0, 1.0, 1.0, 1.0);
}
