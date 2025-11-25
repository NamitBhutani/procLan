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

float getDensity(int x, int y, int z) {
    int xClamped = clamp(x, 0, densitySize - 1);
    int yClamped = clamp(y, 0, densitySize - 1);
    int zClamped = clamp(z, 0, densitySize - 1);
    return densities[index3D(xClamped, yClamped, zClamped)];
}

vec3 computeNormal(int x, int y, int z) {
    float dX = getDensity(x - 1, y, z) - getDensity(x + 1, y, z);
    float dY = getDensity(x, y - 1, z) - getDensity(x, y + 1, z);
    float dZ = getDensity(x, y, z - 1) - getDensity(x, y, z + 1);
    vec3 n = vec3(dX, dY, dZ);
    
    if (length(n) < 0.0001) {
        return vec3(0.0, 1.0, 0.0);
    }
    return normalize(n);
}

vec3 interpolateNormal(vec3 normal0, vec3 normal1, float val0, float val1) {
    if(abs(isoLevel - val0) < 0.00001) return normal0;
    if(abs(isoLevel - val1) < 0.00001) return normal1;
    if(abs(val0 - val1) < 0.00001) return normal0;
    
    float t = (isoLevel - val0) / (val1 - val0);
    vec3 n = mix(normal0, normal1, t);
    
    if (length(n) < 0.0001) {
        return normal0;
    }
    return normalize(n);
}

void main() {
    ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);

    if (pos.x >= densitySize - 1 || pos.y >= densitySize - 1 || pos.z >= densitySize - 1) {
        return;
    }

    float d0 = densities[index3D(pos.x,     pos.y,     pos.z)];
    float d1 = densities[index3D(pos.x + 1, pos.y,     pos.z)];
    float d2 = densities[index3D(pos.x + 1, pos.y + 1, pos.z)];
    float d3 = densities[index3D(pos.x,     pos.y + 1, pos.z)];
    float d4 = densities[index3D(pos.x,     pos.y,     pos.z + 1)];
    float d5 = densities[index3D(pos.x + 1, pos.y,     pos.z + 1)];
    float d6 = densities[index3D(pos.x + 1, pos.y + 1, pos.z + 1)];
    float d7 = densities[index3D(pos.x,     pos.y + 1, pos.z + 1)];

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

    vec3 basePos = vec3(pos) - vec3(1.0); 

    vec3 p0 = basePos + vec3(0, 0, 0);
    vec3 p1 = basePos + vec3(1, 0, 0);
    // p2-p7 logic handled in loop below

    vec3 n0 = computeNormal(pos.x,     pos.y,     pos.z);
    vec3 n1 = computeNormal(pos.x + 1, pos.y,     pos.z);
    vec3 n2 = computeNormal(pos.x + 1, pos.y + 1, pos.z);
    vec3 n3 = computeNormal(pos.x,     pos.y + 1, pos.z);
    vec3 n4 = computeNormal(pos.x,     pos.y,     pos.z + 1);
    vec3 n5 = computeNormal(pos.x + 1, pos.y,     pos.z + 1);
    vec3 n6 = computeNormal(pos.x + 1, pos.y + 1, pos.z + 1);
    vec3 n7 = computeNormal(pos.x,     pos.y + 1, pos.z + 1);

    vec3 edgeVerts[12];
    vec3 edgeNormals[12];

    if((edgeTable[cubeIndex] & 1) != 0) {
        edgeVerts[0] = interpolateVertex(p0, p1, d0, d1);
        edgeNormals[0] = interpolateNormal(n0, n1, d0, d1);
    }
    if((edgeTable[cubeIndex] & 2) != 0) {
        edgeVerts[1] = interpolateVertex(p1, (basePos + vec3(1,1,0)), d1, d2);
        edgeNormals[1] = interpolateNormal(n1, n2, d1, d2);
    }
    if((edgeTable[cubeIndex] & 4) != 0) {
        edgeVerts[2] = interpolateVertex((basePos + vec3(1,1,0)), (basePos + vec3(0,1,0)), d2, d3);
        edgeNormals[2] = interpolateNormal(n2, n3, d2, d3);
    }
    if((edgeTable[cubeIndex] & 8) != 0) {
        edgeVerts[3] = interpolateVertex((basePos + vec3(0,1,0)), p0, d3, d0);
        edgeNormals[3] = interpolateNormal(n3, n0, d3, d0);
    }
    if((edgeTable[cubeIndex] & 16) != 0) {
        edgeVerts[4] = interpolateVertex((basePos + vec3(0,0,1)), (basePos + vec3(1,0,1)), d4, d5);
        edgeNormals[4] = interpolateNormal(n4, n5, d4, d5);
    }
    if((edgeTable[cubeIndex] & 32) != 0) {
        edgeVerts[5] = interpolateVertex((basePos + vec3(1,0,1)), (basePos + vec3(1,1,1)), d5, d6);
        edgeNormals[5] = interpolateNormal(n5, n6, d5, d6);
    }
    if((edgeTable[cubeIndex] & 64) != 0) {
        edgeVerts[6] = interpolateVertex((basePos + vec3(1,1,1)), (basePos + vec3(0,1,1)), d6, d7);
        edgeNormals[6] = interpolateNormal(n6, n7, d6, d7);
    }
    if((edgeTable[cubeIndex] & 128) != 0) {
        edgeVerts[7] = interpolateVertex((basePos + vec3(0,1,1)), (basePos + vec3(0,0,1)), d7, d4);
        edgeNormals[7] = interpolateNormal(n7, n4, d7, d4);
    }
    if((edgeTable[cubeIndex] & 256) != 0) {
        edgeVerts[8] = interpolateVertex(p0, (basePos + vec3(0,0,1)), d0, d4);
        edgeNormals[8] = interpolateNormal(n0, n4, d0, d4);
    }
    if((edgeTable[cubeIndex] & 512) != 0) {
        edgeVerts[9] = interpolateVertex(p1, (basePos + vec3(1,0,1)), d1, d5);
        edgeNormals[9] = interpolateNormal(n1, n5, d1, d5);
    }
    if((edgeTable[cubeIndex] & 1024) != 0) {
        edgeVerts[10] = interpolateVertex((basePos + vec3(1,1,0)), (basePos + vec3(1,1,1)), d2, d6);
        edgeNormals[10] = interpolateNormal(n2, n6, d2, d6);
    }
    if((edgeTable[cubeIndex] & 2048) != 0) {
        edgeVerts[11] = interpolateVertex((basePos + vec3(0,1,0)), (basePos + vec3(0,1,1)), d3, d7);
        edgeNormals[11] = interpolateNormal(n3, n7, d3, d7);
    }

    // output tris
    int baseIndex = cubeIndex * 16;
    for(int i = 0; i < 16; i += 3) {
        int triIndex0 = triTable[baseIndex + i];
        if(triIndex0 == -1) break;
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
