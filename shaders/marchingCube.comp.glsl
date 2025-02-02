#version 460 core
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(std430, binding = 0) buffer DensityBuffer {
float densities[];
};

layout(std430, binding = 1) buffer VertexBuffer {
vec4 vertices[];
};

layout(std430, binding = 2) buffer EdgeTable {
int edgeTable[256];
};

layout(std430, binding = 3) buffer TriTable {
int triTable[256 * 16];
};

layout(std430, binding = 4) buffer CounterBuffer {
uint vertexCounter;
};

const float isoLevel = 0.1;

int index3D(int x, int y, int z, int gridSize) {
return x + y * gridSize + z * gridSize * gridSize;
}

vec3 interpolateVertex(vec3 p1, vec3 p2, float val1, float val2) {
if(abs(val2 - val1) < 0.0001) return p1;
float t = (isoLevel - val1) / (val2 - val1);
return mix(p1, p2, clamp(t, 0.0, 1.0));
}

void main() {
ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);
const int gridSize = 32;

if(pos.x >= gridSize - 1 || pos.y >= gridSize - 1 || pos.z >= gridSize - 1) {
return;
}

float cubeVertices[8];
for(int i = 0;
i < 8;
i ++) {
ivec3 offset = ivec3(i & 1, (i & 2) >> 1, (i & 4) >> 2);
ivec3 samplePos = pos + offset;
cubeVertices[i] = densities[index3D(samplePos.x, samplePos.y, samplePos.z, gridSize)];
}

int cubeIndex = 0;
for(int i = 0;
i < 8;
i ++) {
if(cubeVertices[i] > isoLevel) {
cubeIndex |= (1 << i);
}
}

int edges = edgeTable[cubeIndex];
if(edges == 0) {
return;
}

vec3 cubeCorners[8];
for(int i = 0;
i < 8;
i ++) {
ivec3 offset = ivec3(i & 1, (i & 2) >> 1, (i & 4) >> 2);
cubeCorners[i] = vec3(pos + offset);
}

vec3 edgeVerts[12];
for(int i = 0;
i < 12;
i ++) {
int v1 = 0, v2 = 0;
switch(i) {
case 0 : v1 = 0;
v2 = 1;
break;
case 1 : v1 = 1;
v2 = 2;
break;
case 2 : v1 = 2;
v2 = 3;
break;
case 3 : v1 = 3;
v2 = 0;
break;
case 4 : v1 = 4;
v2 = 5;
break;
case 5 : v1 = 5;
v2 = 6;
break;
case 6 : v1 = 6;
v2 = 7;
break;
case 7 : v1 = 7;
v2 = 4;
break;
case 8 : v1 = 0;
v2 = 4;
break;
case 9 : v1 = 1;
v2 = 5;
break;
case 10 : v1 = 2;
v2 = 6;
break;
case 11 : v1 = 3;
v2 = 7;
break;
}
        // Calculate vertex position regardless of edge mask
edgeVerts[i] = interpolateVertex(cubeCorners[v1], cubeCorners[v2], cubeVertices[v1], cubeVertices[v2]);
}

int baseIndex = cubeIndex * 16;
for(int i = 0;
triTable[baseIndex + i] != - 1 && i < 15;
i += 3) {
int v0 = triTable[baseIndex + i];
int v1 = triTable[baseIndex + i + 1];
int v2 = triTable[baseIndex + i + 2];

if(v0 < 0 || v0 >= 12 || v1 < 0 || v1 >= 12 || v2 < 0 || v2 >= 12) {
continue;
}

uint startIndex = atomicAdd(vertexCounter, 3);
vertices[startIndex] = vec4(edgeVerts[v0], 1.0);
vertices[startIndex + 1] = vec4(edgeVerts[v1], 1.0);
vertices[startIndex + 2] = vec4(edgeVerts[v2], 1.0);
}
}