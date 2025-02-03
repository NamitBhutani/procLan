#version 460 core
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(std430, binding = 0) buffer DensityBuffer {
float densities[];
};

layout(std430, binding = 1) buffer VertexBuffer {
vec4 vertices[];
};

layout(std430, binding = 2) buffer EdgeTableBuffer {
int edgeTable[256];
};

layout(std430, binding = 3) buffer TriTableBuffer {
int triTable[256 * 16];
};

layout(std430, binding = 4) buffer CounterBuffer {
uint vertexCounter;
};

const float isoLevel = 0.0;
const int gridSize = 32;

int index3D(int x, int y, int z, int gridSize) {
return x + y * gridSize + z * gridSize * gridSize;
}

vec3 interpolateVertex(vec3 p1, vec3 p2, float val1, float val2) {
if(abs(isoLevel - val1) < 0.00001) return p1;
if(abs(isoLevel - val2) < 0.00001) return p2;
if(abs(val1 - val2) < 0.00001) return p1;
float t = (isoLevel - val1) / (val2 - val1);
return mix(p1, p2, clamp(t, 0.0, 1.0));
}

void main() {
ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);

if(pos.x >= gridSize - 1 || pos.y >= gridSize - 1 || pos.z >= gridSize - 1) return;

float d0 = densities[index3D(pos.x, pos.y, pos.z, gridSize)];
float d1 = densities[index3D(pos.x + 1, pos.y, pos.z, gridSize)];
float d2 = densities[index3D(pos.x + 1, pos.y + 1, pos.z, gridSize)];
float d3 = densities[index3D(pos.x, pos.y + 1, pos.z, gridSize)];
float d4 = densities[index3D(pos.x, pos.y, pos.z + 1, gridSize)];
float d5 = densities[index3D(pos.x + 1, pos.y, pos.z + 1, gridSize)];
float d6 = densities[index3D(pos.x + 1, pos.y + 1, pos.z + 1, gridSize)];
float d7 = densities[index3D(pos.x, pos.y + 1, pos.z + 1, gridSize)];

int cubeIndex = 0;
if(d0 < isoLevel) cubeIndex |= 1;
if(d1 < isoLevel) cubeIndex |= 2;
if(d2 < isoLevel) cubeIndex |= 4;
if(d3 < isoLevel) cubeIndex |= 8;
if(d4 < isoLevel) cubeIndex |= 16;
if(d5 < isoLevel) cubeIndex |= 32;
if(d6 < isoLevel) cubeIndex |= 64;
if(d7 < isoLevel) cubeIndex |= 128;

if(edgeTable[cubeIndex] == 0) return;

vec3 p0 = vec3(pos.x, pos.y, pos.z);
vec3 p1 = vec3(pos.x + 1, pos.y, pos.z);
vec3 p2 = vec3(pos.x + 1, pos.y + 1, pos.z);
vec3 p3 = vec3(pos.x, pos.y + 1, pos.z);
vec3 p4 = vec3(pos.x, pos.y, pos.z + 1);
vec3 p5 = vec3(pos.x + 1, pos.y, pos.z + 1);
vec3 p6 = vec3(pos.x + 1, pos.y + 1, pos.z + 1);
vec3 p7 = vec3(pos.x, pos.y + 1, pos.z + 1);

vec3 edgeVerts[12];

if((edgeTable[cubeIndex] & 1) != 0) edgeVerts[0] = interpolateVertex(p0, p1, d0, d1);
if((edgeTable[cubeIndex] & 2) != 0) edgeVerts[1] = interpolateVertex(p1, p2, d1, d2);
if((edgeTable[cubeIndex] & 4) != 0) edgeVerts[2] = interpolateVertex(p2, p3, d2, d3);
if((edgeTable[cubeIndex] & 8) != 0) edgeVerts[3] = interpolateVertex(p3, p0, d3, d0);
if((edgeTable[cubeIndex] & 16) != 0) edgeVerts[4] = interpolateVertex(p4, p5, d4, d5);
if((edgeTable[cubeIndex] & 32) != 0) edgeVerts[5] = interpolateVertex(p5, p6, d5, d6);
if((edgeTable[cubeIndex] & 64) != 0) edgeVerts[6] = interpolateVertex(p6, p7, d6, d7);
if((edgeTable[cubeIndex] & 128) != 0) edgeVerts[7] = interpolateVertex(p7, p4, d7, d4);
if((edgeTable[cubeIndex] & 256) != 0) edgeVerts[8] = interpolateVertex(p0, p4, d0, d4);
if((edgeTable[cubeIndex] & 512) != 0) edgeVerts[9] = interpolateVertex(p1, p5, d1, d5);
if((edgeTable[cubeIndex] & 1024) != 0) edgeVerts[10] = interpolateVertex(p2, p6, d2, d6);
if((edgeTable[cubeIndex] & 2048) != 0) edgeVerts[11] = interpolateVertex(p3, p7, d3, d7);

int baseIndex = cubeIndex * 16;
for(int i = 0;
i < 16;
i += 3) {
int triIndex0 = triTable[baseIndex + i];
if(triIndex0 == - 1) break;
int triIndex1 = triTable[baseIndex + i + 1];
int triIndex2 = triTable[baseIndex + i + 2];

uint startIndex = atomicAdd(vertexCounter, 3);
vertices[startIndex] = vec4(edgeVerts[triIndex0], 1.0);
vertices[startIndex + 1] = vec4(edgeVerts[triIndex1], 1.0);
vertices[startIndex + 2] = vec4(edgeVerts[triIndex2], 1.0);
}
}
