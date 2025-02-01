#include "include/FastNoiseLite.h"
#include "include/tritable.h"
#include "include/edgetable.h"
#include <vector>
#include <glad/glad.h>
using namespace std;
#define GRID_SIZE 32

GLuint densitySSBO, edgeTableSSBO, triTableSSBO;

vector<float> generateDensityField()
{
    FastNoiseLite noise;
    noise.SetNoiseType(FastNoiseLite::NoiseType_OpenSimplex2);

    vector<float> densityField(GRID_SIZE * GRID_SIZE * GRID_SIZE);

    for (int z = 0; z < GRID_SIZE; ++z)
    {
        for (int y = 0; y < GRID_SIZE; ++y)
        {
            for (int x = 0; x < GRID_SIZE; ++x)
            {
                int index = x + y * GRID_SIZE + z * GRID_SIZE * GRID_SIZE;
                float nx = (float)x / GRID_SIZE;
                float ny = (float)y / GRID_SIZE;
                float nz = (float)z / GRID_SIZE;

                densityField[index] = noise.GetNoise(nx * 10.0f, ny * 10.0f, nz * 10.0f); // Scale noise
            }
        }
    }
    return densityField;
}

void createDensitySSBO()
{
    vector<float> densityField = generateDensityField();
    glGenBuffers(1, &densitySSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, densitySSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, densityField.size() * sizeof(float), densityField.data(), GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, densitySSBO); // Bind to SSBO binding point 0
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}
void UploadMarchingCubesTables()
{
    // Upload Edge Table

    glGenBuffers(1, &edgeTableSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, edgeTableSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, edgetable.size() * sizeof(int), edgetable.data(), GL_STATIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, edgeTableSSBO); // Binding = 2
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    // Upload Tri Table
    // flatten triTable into a 1D vector
    std::vector<int> flattenedTriTable;
    for (const auto &row : tritable)
    {
        flattenedTriTable.insert(flattenedTriTable.end(), row.begin(), row.end());
    }
    glGenBuffers(1, &triTableSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, triTableSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, flattenedTriTable.size() * sizeof(int), flattenedTriTable.data(), GL_STATIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, triTableSSBO); // Binding = 3
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}
