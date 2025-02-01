#version 430

layout(std430, binding = 0) buffer DensityBuffer { //std430 memory layout is better for ssbos
float densities[];
};

void main() {
uint index = gl_GlobalInvocationID.x +
    gl_GlobalInvocationID.y * 32 +
    gl_GlobalInvocationID.z * 32 * 32;

float density = densities[index];

}
