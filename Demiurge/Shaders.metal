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
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant float *vertices [[buffer(0)]],
                              constant float4x4 &mvpMatrix [[buffer(1)]]) {
    VertexOut out;
    
    float3 position = float3(vertices[vertexID * 7], vertices[vertexID * 7 + 1], vertices[vertexID * 7 + 2]);
    float4 color = float4(vertices[vertexID * 7 + 3], vertices[vertexID * 7 + 4], vertices[vertexID * 7 + 5], vertices[vertexID * 7 + 6]);
    
    out.position = mvpMatrix * float4(position, 1.0);
    out.color = color;
    
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}

// Fragment shader for edges - always returns black
fragment float4 edgeFragmentShader(VertexOut in [[stage_in]]) {
    return float4(0.0, 0.0, 0.0, 1.0);
}
