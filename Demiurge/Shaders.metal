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
    float pointSize [[point_size]];  // Added for vertex point rendering
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]],
                             constant float4x4 &mvpMatrix [[buffer(1)]],
                             constant float &pointSize [[buffer(2)]], // Optional point size
                             uint vid [[vertex_id]]) {
    VertexOut out;
    
    out.position = mvpMatrix * float4(in.position, 1.0);
    out.color = float4(0.0, 0.2, 1.0, 1.0);
    out.pointSize = pointSize;  // Use the provided point size

    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}

// Fragment shader for edges - always returns white
fragment float4 edgeFragmentShader(VertexOut in [[stage_in]]) {
    return float4(1.0, 1.0, 1.0, 1.0);
}

// New fragment shader for vertex points - always returns red
fragment float4 vertexPointFragmentShader(VertexOut in [[stage_in]]) {
    // Calculate distance from fragment to center of point
    float2 centerCoord = in.position.xy;
    float2 fragCoord = centerCoord;
    
    // Create a circle effect
    float dist = distance(fragCoord, centerCoord);
    float radius = in.pointSize / 2.0;
    
    // Discard fragments outside the circle
    if (dist > radius) {
        discard_fragment();
    }
    
    // Red color for vertex points
    return float4(1.0, 0.0, 0.0, 1.0);
}
