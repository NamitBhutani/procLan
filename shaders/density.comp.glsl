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

void main() {
    uvec3 id = gl_GlobalInvocationID.xyz;
    if (id.x >= densitySize || id.y >= densitySize || id.z >= densitySize) return;

    uint index = id.x + id.y * densitySize + id.z * densitySize * densitySize;
    
    // calc World Position for this voxel
    vec3 worldPos = vec3(id) + u_Offset - vec3(1.0);

    // setup warp noise
    fnl_state warpNoise = fnlCreateState(u_Seed);
    warpNoise.noise_type = FNL_NOISE_OPENSIMPLEX2;
    warpNoise.domain_warp_type = FNL_DOMAIN_WARP_OPENSIMPLEX2;
    warpNoise.frequency = 0.03;
    warpNoise.domain_warp_amp = 20;

    FNLfloat wx = worldPos.x;
    FNLfloat wy = worldPos.y;
    FNLfloat wz = worldPos.z;
    fnlDomainWarp3D(warpNoise, wx, wy, wz);
    vec3 warpedPos = vec3(wx, wy, wz);

    // setup base noise for terrain
    fnl_state noise = fnlCreateState(u_Seed);
    noise.noise_type = FNL_NOISE_OPENSIMPLEX2;
    noise.fractal_type = FNL_FRACTAL_FBM;
    noise.frequency = 0.02; 
    noise.octaves = 4;

    // 2D terrain noise sampled from warped domain
    float terrainHeight = fnlGetNoise3D(noise, warpedPos.x, 0.0, warpedPos.z) * 20.0 + 10.0;

    float val = terrainHeight - worldPos.y;

    // carve caves using multiple Ridged multifractal noise systems
    for (int i = 0; i < u_NumCaves; ++i)
    {
        fnl_state caveNoise = fnlCreateState(u_Seed + i * 431);
        caveNoise.noise_type = FNL_NOISE_OPENSIMPLEX2;
        caveNoise.fractal_type = FNL_FRACTAL_RIDGED;
        caveNoise.frequency = u_CaveFrequencies[i];
        caveNoise.octaves = 3;

        vec3 p = worldPos + u_CaveOffsets[i];
        float caveVal = fnlGetNoise3D(caveNoise, p.x, p.y, p.z);

        if (caveVal > 0.8)
            val -= caveVal * u_CaveGains[i];
    }

    density[index] = val;
}