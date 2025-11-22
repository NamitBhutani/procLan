#version 460 core
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(std430, binding = 0) buffer DensityBuffer {
    float density[];
};

uniform int gridSize;
uniform int u_Seed;
uniform vec3 u_Offset;   // Pass chunk offset (e.g., vec3(0,0,0))

void main() {
    uvec3 id = gl_GlobalInvocationID.xyz;
    if (id.x >= gridSize || id.y >= gridSize || id.z >= gridSize) return;

    uint index = id.x + id.y * gridSize + id.z * gridSize * gridSize;
    
    // calc World Position for this voxel
    vec3 worldPos = vec3(id) + u_Offset;

    // setup noise
    fnl_state noise = fnlCreateState(u_Seed);
    noise.noise_type = FNL_NOISE_OPENSIMPLEX2;
    noise.fractal_type = FNL_FRACTAL_FBM;
    noise.frequency = 0.02; 
    noise.octaves = 4;

    // 2d noise
    float terrainHeight = fnlGetNoise3D(noise, worldPos.x, 0.0, worldPos.z) * 20.0 + 10.0;

    float val = terrainHeight - worldPos.y;

    // todo: sdf cave system goes here

    density[index] = val;
}