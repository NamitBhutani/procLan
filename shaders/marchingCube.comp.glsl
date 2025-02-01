#version 430

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(std430, binding = 0) buffer DensityBuffer {
float densities[];
};

layout(std430, binding = 2) buffer EdgeTable {
int edgeTable[256];
};

layout(std430, binding = 3) buffer TriTable {
int triTable[256 * 16];
};

layout(std430, binding = 1) buffer VertexBuffer {
vec4 vertices[];
};

const float isoLevel = 0.0;  // Threshold for surface extraction

// Convert 3D voxel coordinates to 1D index
int index3D(int x, int y, int z, int gridSize) {
return x + y * gridSize + z * gridSize * gridSize;
}

// Interpolate vertex positions along edges
vec3 interpolateVertex(vec3 p1, vec3 p2, float val1, float val2) {
float t = (isoLevel - val1) / (val2 - val1);
return mix(p1, p2, t);
}

void main() {
    // Get voxel grid position
ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);
int gridSize = 32;  // Grid size

    // Skip boundary voxels
if(pos.x >= gridSize - 1 || pos.y >= gridSize - 1 || pos.z >= gridSize - 1) {
return;
}

    // Read 8 density values (corners of the cube)
float cube[8];
cube[0] = densities[index3D(pos.x, pos.y, pos.z, gridSize)];
cube[1] = densities[index3D(pos.x + 1, pos.y, pos.z, gridSize)];
cube[2] = densities[index3D(pos.x + 1, pos.y + 1, pos.z, gridSize)];
cube[3] = densities[index3D(pos.x, pos.y + 1, pos.z, gridSize)];
cube[4] = densities[index3D(pos.x, pos.y, pos.z + 1, gridSize)];
cube[5] = densities[index3D(pos.x + 1, pos.y, pos.z + 1, gridSize)];
cube[6] = densities[index3D(pos.x + 1, pos.y + 1, pos.z + 1, gridSize)];
cube[7] = densities[index3D(pos.x, pos.y + 1, pos.z + 1, gridSize)];

    // Compute cube index based on density values
int cubeIndex = 0;
for(int i = 0;
i < 8;
i ++) {
if(cube[i] > isoLevel) {
cubeIndex |= (1 << i);
}
}

    // Look up edge table entry
int edges = edgeTable[cubeIndex];
if(edges == 0) return;

    // Cube corner positions
vec3 cubeCorners[8] = vec3[](vec3(pos.x, pos.y, pos.z), vec3(pos.x + 1, pos.y, pos.z), vec3(pos.x + 1, pos.y + 1, pos.z), vec3(pos.x, pos.y + 1, pos.z), vec3(pos.x, pos.y, pos.z + 1), vec3(pos.x + 1, pos.y, pos.z + 1), vec3(pos.x + 1, pos.y + 1, pos.z + 1), vec3(pos.x, pos.y + 1, pos.z + 1));

    // interpolated vertices along the edges
vec3 edgeVerts[12];
if(edges & 1) edgeVerts[0] = interpolateVertex(cubeCorners[0], cubeCorners[1], cube[0], cube[1]);
if(edges & 2) edgeVerts[1] = interpolateVertex(cubeCorners[1], cubeCorners[2], cube[1], cube[2]);
if(edges & 4) edgeVerts[2] = interpolateVertex(cubeCorners[2], cubeCorners[3], cube[2], cube[3]);
if(edges & 8) edgeVerts[3] = interpolateVertex(cubeCorners[3], cubeCorners[0], cube[3], cube[0]);
if(edges & 16) edgeVerts[4] = interpolateVertex(cubeCorners[4], cubeCorners[5], cube[4], cube[5]);
if(edges & 32) edgeVerts[5] = interpolateVertex(cubeCorners[5], cubeCorners[6], cube[5], cube[6]);
if(edges & 64) edgeVerts[6] = interpolateVertex(cubeCorners[6], cubeCorners[7], cube[6], cube[7]);
if(edges & 128) edgeVerts[7] = interpolateVertex(cubeCorners[7], cubeCorners[4], cube[7], cube[4]);
if(edges & 256) edgeVerts[8] = interpolateVertex(cubeCorners[0], cubeCorners[4], cube[0], cube[4]);
if(edges & 512) edgeVerts[9] = interpolateVertex(cubeCorners[1], cubeCorners[5], cube[1], cube[5]);
if(edges & 1024) edgeVerts[10] = interpolateVertex(cubeCorners[2], cubeCorners[6], cube[2], cube[6]);
if(edges & 2048) edgeVerts[11] = interpolateVertex(cubeCorners[3], cubeCorners[7], cube[3], cube[7]);

    // Lookup triangle indices from flattened triTable
int baseIndex = cubeIndex * 16;  // Each row in the table has 16 values
for(int i = 0;
triTable[baseIndex + i] != - 1;
i += 3) {
int v0 = triTable[baseIndex + i];
int v1 = triTable[baseIndex + i + 1];
int v2 = triTable[baseIndex + i + 2];

int voxelIndex = index3D(pos.x, pos.y, pos.z, gridSize) * 3;
vertices[voxelIndex] = vec4(edgeVerts[v0], 1.0);
vertices[voxelIndex + 1] = vec4(edgeVerts[v1], 1.0);
vertices[voxelIndex + 2] = vec4(edgeVerts[v2], 1.0);
}
}
