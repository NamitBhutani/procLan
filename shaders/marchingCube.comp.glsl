#version 460 core

struct VertexNormal {
    vec4 position;
    vec3 normal;
    float pad; // padding for alignment (vec3 is 12 bytes; adding 4 bytes gives a 16-byte block)
};

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(std430, binding = 0) buffer DensityBuffer {
float densities[];
};

// unified buffer for both vertices and normals.
layout(std430, binding = 1) buffer VertexNormalBuffer {
VertexNormal vertexNormals[];
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
uniform int gridSize;
uniform int densitySize;

int index3D(int x, int y, int z) {
return x + y * densitySize + z * densitySize * densitySize;
}

vec3 interpolateVertex(vec3 p1, vec3 p2, float val1, float val2) {
if(abs(isoLevel - val1) < 0.00001) return p1;
if(abs(isoLevel - val2) < 0.00001) return p2;
if(abs(val1 - val2) < 0.00001) return p1;
float t = (isoLevel - val1) / (val2 - val1);
return mix(p1, p2, clamp(t, 0.0, 1.0));
}

vec3 computeNormal(int x, int y, int z) {
    // clamp indices to stay inside the 0..31 range
    // int x0 = max(x - 1, 0);
    // int x1 = min(x + 1, gridSize - 1);
    
    // int y0 = max(y - 1, 0);
    // int y1 = min(y + 1, gridSize - 1);
    
    // int z0 = max(z - 1, 0);
    // int z1 = min(z + 1, gridSize - 1);

    // float dX = densities[index3D(x0, y, z, gridSize)] - densities[index3D(x1, y, z, gridSize)];
    // float dY = densities[index3D(x, y0, z, gridSize)] - densities[index3D(x, y1, z, gridSize)];
    // float dZ = densities[index3D(x, y, z0, gridSize)] - densities[index3D(x, y, z1, gridSize)];

    // return normalize(vec3(dX, dY, dZ));
    float dX = densities[index3D(x, y + 1, z + 1)] - densities[index3D(x + 2, y + 1, z + 1)];
    float dY = densities[index3D(x + 1, y, z + 1)] - densities[index3D(x + 1, y + 2, z + 1)];
    float dZ = densities[index3D(x + 1, y + 1, z)] - densities[index3D(x + 1, y + 1, z + 2)];

    return normalize(vec3(dX, dY, dZ));
}

vec3 interpolateNormal(vec3 normal0, vec3 normal1, float val0, float val1) {
if(abs(isoLevel - val0) < 0.00001) return normal0;
if(abs(isoLevel - val1) < 0.00001) return normal1;
if(abs(val0 - val1) < 0.00001) return normal0;
float t = (isoLevel - val0) / (val1 - val0);
return normalize(mix(normal0, normal1, t));
}

void main() {
ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);

if(pos.x >= gridSize - 1 || pos.y >= gridSize - 1 || pos.z >= gridSize - 1) {
return;
}

float d0 = densities[index3D(pos.x + 1, pos.y + 1, pos.z + 1)];
float d1 = densities[index3D(pos.x + 2, pos.y + 1, pos.z + 1)];
float d2 = densities[index3D(pos.x + 2, pos.y + 2, pos.z + 1)];
float d3 = densities[index3D(pos.x + 1, pos.y + 2, pos.z + 1)];
float d4 = densities[index3D(pos.x + 1, pos.y + 1, pos.z + 2)];
float d5 = densities[index3D(pos.x + 2, pos.y + 1, pos.z + 2)];
float d6 = densities[index3D(pos.x + 2, pos.y + 2, pos.z + 2)];
float d7 = densities[index3D(pos.x + 1, pos.y + 2, pos.z + 2)];

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

vec3 normal0 = computeNormal(pos.x, pos.y, pos.z);
vec3 normal1 = computeNormal(pos.x + 1, pos.y, pos.z);
vec3 normal2 = computeNormal(pos.x + 1, pos.y + 1, pos.z);
vec3 normal3 = computeNormal(pos.x, pos.y + 1, pos.z);
vec3 normal4 = computeNormal(pos.x, pos.y, pos.z + 1);
vec3 normal5 = computeNormal(pos.x + 1, pos.y, pos.z + 1);
vec3 normal6 = computeNormal(pos.x + 1, pos.y + 1, pos.z + 1);
vec3 normal7 = computeNormal(pos.x, pos.y + 1, pos.z + 1);
vec3 edgeVerts[12];
vec3 edgeNormals[12];

if((edgeTable[cubeIndex] & 1) != 0) {
edgeVerts[0] = interpolateVertex(p0, p1, d0, d1);
edgeNormals[0] = interpolateNormal(normal0, normal1, d0, d1);
}
if((edgeTable[cubeIndex] & 2) != 0) {
edgeVerts[1] = interpolateVertex(p1, p2, d1, d2);
edgeNormals[1] = interpolateNormal(normal1, normal2, d1, d2);
}
if((edgeTable[cubeIndex] & 4) != 0) {
edgeVerts[2] = interpolateVertex(p2, p3, d2, d3);
edgeNormals[2] = interpolateNormal(normal2, normal3, d2, d3);
}
if((edgeTable[cubeIndex] & 8) != 0) {
edgeVerts[3] = interpolateVertex(p3, p0, d3, d0);
edgeNormals[3] = interpolateNormal(normal3, normal0, d3, d0);
}
if((edgeTable[cubeIndex] & 16) != 0) {
edgeVerts[4] = interpolateVertex(p4, p5, d4, d5);
edgeNormals[4] = interpolateNormal(normal4, normal5, d4, d5);
}
if((edgeTable[cubeIndex] & 32) != 0) {
edgeVerts[5] = interpolateVertex(p5, p6, d5, d6);
edgeNormals[5] = interpolateNormal(normal5, normal6, d5, d6);
}
if((edgeTable[cubeIndex] & 64) != 0) {
edgeVerts[6] = interpolateVertex(p6, p7, d6, d7);
edgeNormals[6] = interpolateNormal(normal6, normal7, d6, d7);
}
if((edgeTable[cubeIndex] & 128) != 0) {
edgeVerts[7] = interpolateVertex(p7, p4, d7, d4);
edgeNormals[7] = interpolateNormal(normal7, normal4, d7, d4);
}
if((edgeTable[cubeIndex] & 256) != 0) {
edgeVerts[8] = interpolateVertex(p0, p4, d0, d4);
edgeNormals[8] = interpolateNormal(normal0, normal4, d0, d4);
}
if((edgeTable[cubeIndex] & 512) != 0) {
edgeVerts[9] = interpolateVertex(p1, p5, d1, d5);
edgeNormals[9] = interpolateNormal(normal1, normal5, d1, d5);
}
if((edgeTable[cubeIndex] & 1024) != 0) {
edgeVerts[10] = interpolateVertex(p2, p6, d2, d6);
edgeNormals[10] = interpolateNormal(normal2, normal6, d2, d6);
}
if((edgeTable[cubeIndex] & 2048) != 0) {
edgeVerts[11] = interpolateVertex(p3, p7, d3, d7);
edgeNormals[11] = interpolateNormal(normal3, normal7, d3, d7);
}

    // Use the triangle table to output vertices.
int baseIndex = cubeIndex * 16;
for(int i = 0;
i < 16;
i += 3) {
int triIndex0 = triTable[baseIndex + i];
if(triIndex0 == - 1) break;
int triIndex1 = triTable[baseIndex + i + 1];
int triIndex2 = triTable[baseIndex + i + 2];

uint startIndex = atomicAdd(vertexCounter, 3);
vertexNormals[startIndex].position = vec4(edgeVerts[triIndex0], 1.0);
vertexNormals[startIndex].normal = edgeNormals[triIndex0];
vertexNormals[startIndex].pad = 0.0;

vertexNormals[startIndex + 1].position = vec4(edgeVerts[triIndex1], 1.0);
vertexNormals[startIndex + 1].normal = edgeNormals[triIndex1];
vertexNormals[startIndex + 1].pad = 0.0;

vertexNormals[startIndex + 2].position = vec4(edgeVerts[triIndex2], 1.0);
vertexNormals[startIndex + 2].normal = edgeNormals[triIndex2];
vertexNormals[startIndex + 2].pad = 0.0;
}
}
