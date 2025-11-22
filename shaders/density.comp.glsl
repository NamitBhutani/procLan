// sphere sdf
#version 460 core
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(std430, binding = 0) buffer DensityBuffer {
    float density[];
};

uniform int gridSize;

void main() {
    uvec3 id = gl_GlobalInvocationID;
    if (id.x >= gridSize || id.y >= gridSize || id.z >= gridSize) return;

    uint index = id.x + id.y * gridSize + id.z * gridSize * gridSize;
    vec3 pos = vec3(id);
    
    vec3 center = vec3(gridSize) * 0.5;
    float radius = float(gridSize) * 0.3;
    
    float val = length(pos - center) - radius; 

    density[index] = val;
}