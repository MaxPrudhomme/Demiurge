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
    float4 color [[flat]];
    float pointSize [[point_size]];
};

struct PointSizeBuffer {
    float pointSize;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]],
                             constant float4x4 &mvpMatrix [[buffer(1)]],
                             constant PointSizeBuffer &pointSizeBuffer [[buffer(2)]],
                             constant float4 *colorBuffer [[buffer(3)]],
                             uint vid [[vertex_id]]) {
    VertexOut out;
    
    out.position = mvpMatrix * float4(in.position, 1.0);
    out.color = colorBuffer[vid];
    out.pointSize = pointSizeBuffer.pointSize;

    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}

fragment float4 edgeFragmentShader(VertexOut in [[stage_in]]) {
    return float4(1.0, 1.0, 1.0, 1.0);
}

fragment float4 vertexPointFragmentShader(VertexOut in [[stage_in]]) {
    float2 fragCoord = in.position.xy / in.position.w;
    float dist = length(fragCoord);
    float radius = in.pointSize / 2.0;

    if (dist > radius) {
        discard_fragment();
    }

    return float4(1.0, 0.0, 0.0, 1.0);
}
