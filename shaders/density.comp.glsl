#version 460 core
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(std430, binding = 0) buffer DensityBuffer {
    float density[];
};

uniform int gridSize;
uniform int densitySize;
uniform int u_Seed;
uniform vec3 u_Offset;

const int MAX_CAVES = 8;
uniform int u_NumCaves;
uniform vec3 u_CaveOffsets[MAX_CAVES];
uniform float u_CaveGains[MAX_CAVES];
uniform float u_CaveFrequencies[MAX_CAVES];
uniform float u_CaveCeiling;

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

void main() {
    uvec3 id = gl_GlobalInvocationID.xyz;
    if (id.x >= densitySize || id.y >= densitySize || id.z >= densitySize) return;

    uint index = id.x + id.y * densitySize + id.z * densitySize * densitySize;
    
    vec3 worldPos = vec3(id) + u_Offset - vec3(1.0);

    fnl_state warpNoise = fnlCreateState(u_Seed);
    warpNoise.noise_type = FNL_NOISE_OPENSIMPLEX2;
    warpNoise.domain_warp_type = FNL_DOMAIN_WARP_OPENSIMPLEX2;
    warpNoise.frequency = 0.005;
    warpNoise.domain_warp_amp = 5.0;

    FNLfloat wx = worldPos.x;
    FNLfloat wy = worldPos.y;
    FNLfloat wz = worldPos.z;
    fnlDomainWarp3D(warpNoise, wx, wy, wz);
    vec3 warpedPos = vec3(wx, wy, wz);

    fnl_state terrainNoise = fnlCreateState(u_Seed);
    terrainNoise.noise_type = FNL_NOISE_OPENSIMPLEX2;
    terrainNoise.fractal_type = FNL_FRACTAL_FBM;
    terrainNoise.frequency = 0.01; 
    terrainNoise.octaves = 4;

    float terrainHeight = fnlGetNoise3D(terrainNoise, warpedPos.x, 0.0, warpedPos.z) * 40.0 + 20.0;
    float currentDensity = terrainHeight - worldPos.y;

    float caveThreshold = 0.67; 

    for (int i = 0; i < u_NumCaves; ++i)
    {
        fnl_state caveNoise = fnlCreateState(u_Seed + i * 431);
        caveNoise.noise_type = FNL_NOISE_OPENSIMPLEX2;
        caveNoise.fractal_type = FNL_FRACTAL_RIDGED;
        caveNoise.frequency = u_CaveFrequencies[i];
        caveNoise.octaves = 2; 

        vec3 p = warpedPos + u_CaveOffsets[i];
        float caveVal = fnlGetNoise3D(caveNoise, p.x, p.y, p.z);

        float caveSDF = (caveThreshold - caveVal) * u_CaveGains[i] * 2.0;
        float heightMask = clamp((u_CaveCeiling - worldPos.y) * 0.15, 0.0, 1.0);

        caveSDF = mix(100.0, caveSDF, heightMask);

        currentDensity = smin(currentDensity, caveSDF, 4.0);
    }

    if (id.y < 3) { 
        currentDensity = 100.0; // bedrock
    }

    // walls and floor around surface
    if (id.x == 0 || id.x == densitySize - 1 || 
        id.z == 0 || id.z == densitySize - 1 || 
        id.y == 0)
    {
        currentDensity = -10.0;
    }

    density[index] = currentDensity;
}