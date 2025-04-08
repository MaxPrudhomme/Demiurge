//
//  ElevationShaders.metal
//  Demiurge
//
//  Created by Max PRUDHOMME on 08/04/2025.
//

#include <metal_stdlib>
using namespace metal;

// Simplex noise helper functions
constant float3 grad3[12] = {
    float3(1,1,0), float3(-1,1,0), float3(1,-1,0), float3(-1,-1,0),
    float3(1,0,1), float3(-1,0,1), float3(1,0,-1), float3(-1,0,-1),
    float3(0,1,1), float3(0,-1,1), float3(0,1,-1), float3(0,-1,-1)
};

float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float lerp(float t, float a, float b) {
    return a + t * (b - a);
}

// Complete implementation of noise function for Metal
float noise(float3 position, device const int* perm) {
    // Find unit grid cell containing the point
    int i = int(floor(position.x)) & 255;
    int j = int(floor(position.y)) & 255;
    int k = int(floor(position.z)) & 255;
    
    // Calculate offsets from the corner
    float xf = position.x - floor(position.x);
    float yf = position.y - floor(position.y);
    float zf = position.z - floor(position.z);
    
    // Hash function and gradient indices
    int hash000 = perm[(perm[(perm[i] + j) & 255] + k) & 255] % 12;
    int hash001 = perm[(perm[(perm[i] + j) & 255] + k + 1) & 255] % 12;
    int hash010 = perm[(perm[(perm[i] + j + 1) & 255] + k) & 255] % 12;
    int hash011 = perm[(perm[(perm[i] + j + 1) & 255] + k + 1) & 255] % 12;
    int hash100 = perm[(perm[(perm[i + 1] + j) & 255] + k) & 255] % 12;
    int hash101 = perm[(perm[(perm[i + 1] + j) & 255] + k + 1) & 255] % 12;
    int hash110 = perm[(perm[(perm[i + 1] + j + 1) & 255] + k) & 255] % 12;
    int hash111 = perm[(perm[(perm[i + 1] + j + 1) & 255] + k + 1) & 255] % 12;
    
    // Dot products with gradient vectors
    float n000 = dot(grad3[hash000], float3(xf, yf, zf));
    float n001 = dot(grad3[hash001], float3(xf, yf, zf-1));
    float n010 = dot(grad3[hash010], float3(xf, yf-1, zf));
    float n011 = dot(grad3[hash011], float3(xf, yf-1, zf-1));
    float n100 = dot(grad3[hash100], float3(xf-1, yf, zf));
    float n101 = dot(grad3[hash101], float3(xf-1, yf, zf-1));
    float n110 = dot(grad3[hash110], float3(xf-1, yf-1, zf));
    float n111 = dot(grad3[hash111], float3(xf-1, yf-1, zf-1));
    
    // Fade curves
    float u = fade(xf);
    float v = fade(yf);
    float w = fade(zf);
    
    // Interpolation along x axis
    float nx00 = mix(n000, n100, u);
    float nx01 = mix(n001, n101, u);
    float nx10 = mix(n010, n110, u);
    float nx11 = mix(n011, n111, u);
    
    // Interpolation along y axis
    float nxy0 = mix(nx00, nx10, v);
    float nxy1 = mix(nx01, nx11, v);
    
    // Final interpolation along z axis
    float nxyz = mix(nxy0, nxy1, w);
    
    // Output value is in range [-1,1]
    return nxyz;
}

// Helper function to generate detailed land terrain
float generateLandTerrain(float3 pos, device const int* perm) {
    float elevation = 0.0;
    float amplitude = 1.0;
    float frequency = 2.0;
    float persistence = 0.5;
    int octaves = 6;
    float totalAmplitude = 0.0;
    
    for (int i = 0; i < octaves; i++) {
        float noiseValue = noise(pos * frequency, perm);
        elevation += noiseValue * amplitude;
        totalAmplitude += amplitude;
        
        amplitude *= persistence;
        frequency *= 2.0;
    }
    
    // Normalize
    elevation = (elevation / totalAmplitude + 1.0) * 0.5;
    
    // Add more variation to land (steeper mountains)
    elevation = pow(elevation, 1.2);
    
    return elevation;
}

// Helper function to generate ocean terrain
float generateOceanTerrain(float3 pos, device const int* perm) {
    float elevation = 0.0;
    float amplitude = 0.7; // Lower amplitude for smoother ocean floor
    float frequency = 1.5;
    float persistence = 0.45;
    int octaves = 4; // Fewer octaves for smoother results
    float totalAmplitude = 0.0;
    
    for (int i = 0; i < octaves; i++) {
        float noiseValue = noise(pos * frequency, perm);
        elevation += noiseValue * amplitude;
        totalAmplitude += amplitude;
        
        amplitude *= persistence;
        frequency *= 2.0;
    }
    
    // Normalize
    elevation = (elevation / totalAmplitude + 1.0) * 0.5;
    
    // Make ocean floor smoother
    return elevation * 0.8;
}

// Kernel for generating continent mask


kernel void generateContinentMask(device const float3* positions [[buffer(0)]],
                                 device float* continentMask [[buffer(1)]],
                                 device const int* permTable [[buffer(2)]],
                                 constant float& continentScale [[buffer(3)]],
                                 constant uint& tileCount [[buffer(4)]],
                                 uint id [[thread_position_in_grid]]) {
    if (id >= tileCount) return;

    float3 pos = positions[id];
    float continentFrequencyBase = 0.5;
    float continentFrequency = continentFrequencyBase * continentScale;
    float noiseValue = 0.0;
    float amplitude = 1.0;
    float frequency = continentFrequency;
    float persistence = 0.5;
    int octaves = 4; // You can adjust the number of octaves

    for (int i = 0; i < octaves; ++i) {
        noiseValue += noise(pos * frequency, permTable) * amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
    }

    // Normalize and bias the noise value to create a continent mask
    continentMask[id] = (noiseValue + 1.0) * 0.5;
}
// Kernel for spatial smoothing
kernel void smoothValues(device const float* inputValues [[buffer(0)]],
                         device float* outputValues [[buffer(1)]],
                         device const float3* positions [[buffer(2)]],
                         constant float& radius [[buffer(3)]],
                         constant uint& tileCount [[buffer(4)]],
                         uint id [[thread_position_in_grid]],
                         threadgroup float* sharedPositions [[threadgroup(0)]],
                         threadgroup float* sharedValues [[threadgroup(1)]],
                         uint tid [[thread_index_in_threadgroup]],
                         uint threadsPerGroup [[threads_per_threadgroup]]) {
    if (id >= tileCount) return;
    
    float3 pos = positions[id];
    float totalWeight = 1.0;
    float weightedSum = inputValues[id];
    
    // Process in chunks using threadgroup memory for faster access
    for (uint groupStart = 0; groupStart < tileCount; groupStart += threadsPerGroup) {
        // Load chunk into shared memory
        uint loadIndex = groupStart + tid;
        if (loadIndex < tileCount) {
            sharedPositions[tid * 3] = positions[loadIndex].x;
            sharedPositions[tid * 3 + 1] = positions[loadIndex].y;
            sharedPositions[tid * 3 + 2] = positions[loadIndex].z;
            sharedValues[tid] = inputValues[loadIndex];
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        // Process this chunk
        for (uint j = 0; j < min(threadsPerGroup, tileCount - groupStart); j++) {
            uint neighborIdx = groupStart + j;
            if (neighborIdx != id) {
                float3 neighborPos = float3(
                    sharedPositions[j * 3],
                    sharedPositions[j * 3 + 1],
                    sharedPositions[j * 3 + 2]
                );
                float dist = length(pos - neighborPos);
                if (dist < radius) {
                    float weight = 1.0 - (dist / radius);
                    weightedSum += sharedValues[j] * weight;
                    totalWeight += weight;
                }
            }
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    outputValues[id] = weightedSum / totalWeight;
}
// Complete elevation generation kernel that mimics the CPU version
kernel void generateElevation(device const float3* positions [[buffer(0)]],
                             device const float* continentMask [[buffer(1)]],
                             device float* heightMap [[buffer(2)]],
                             device const int* permTable [[buffer(3)]],
                             constant float& oceanThreshold [[buffer(4)]],
                             constant float& seaLevel [[buffer(5)]],
                             constant float& highPeakLevel [[buffer(6)]],
                             constant float& deepOceanLevel [[buffer(7)]],
                             constant float& deepOceanStartRatio [[buffer(8)]],
                             constant bool& oceanWorld [[buffer(9)]],
                             constant uint& tileCount [[buffer(10)]],
                             uint id [[thread_position_in_grid]]) {
    if (id >= tileCount) return;
    
    float3 pos = positions[id];
    float continentValue = continentMask[id];
    float elevation = 0.0;
    
    // Print or debug values
    // Cannot do actual printing in Metal, but we can output debug values
    // Try forcing some extreme values to see if the shader is working
    
    if (continentValue > oceanThreshold && !oceanWorld) {
        // Land elevation
        float landRatio = (continentValue - oceanThreshold) / (1.0 - oceanThreshold);
        
        // Add some variation
        float detailNoise = generateLandTerrain(pos, permTable);
        elevation = landRatio * highPeakLevel * 0.7 + detailNoise * highPeakLevel * 0.3;
        
        // Coastal mountains
        float coastalDistance = abs(continentValue - oceanThreshold) * 15.0;
        if (coastalDistance < 1.0) {
            float mountainFactor = sin(coastalDistance * M_PI_F);
            mountainFactor = clamp(mountainFactor, 0.0f, 1.0f);
            
            // Add some mountain noise
            float3 offsetPos = pos * 3.0 + float3(1.5, 2.3, 3.1);
            float mountainNoise = (noise(offsetPos, permTable) + 1.0) * 0.5;
            
            // Apply mountain effect
            elevation += mountainFactor * mountainNoise * highPeakLevel * 0.6 * (1.0 - landRatio * 0.5);
        }
        
        elevation = max(seaLevel, elevation);
    } else {
        // Ocean elevation
        float oceanRatio = (oceanThreshold - continentValue) / oceanThreshold;
        if (oceanRatio > 1.0) oceanRatio = 1.0; // Safety clamp
        
        // Generate ocean floor terrain
        float oceanFloorNoise = generateOceanTerrain(pos, permTable);
        
        // Calculate basic ocean depth
        elevation = -oceanRatio * fabs(deepOceanLevel) * 0.7 - oceanFloorNoise * fabs(deepOceanLevel) * 0.3;
        
        // Add trenches in deeper ocean areas
        if (oceanRatio > deepOceanStartRatio) {
            float3 trenchPos = pos * 2.0 + float3(3.7, 1.9, 2.6);
            float trenchNoise = (noise(trenchPos, permTable) + 1.0) * 0.5;
            
            if (trenchNoise > 0.6) {
                float trenchFactor = (trenchNoise - 0.6) / 0.4;
                elevation -= trenchFactor * fabs(deepOceanLevel) * 0.6;
            }
        }
        
        elevation = min(seaLevel - 0.01, elevation);
    }
    
    // Store the final elevation value
    heightMap[id] = elevation;
}
