#include "include/marchingcube.h"
#include "include/tritable.h"
#include "include/edgetable.h"
#include "include/shader.h"
#include "include/camera.h"
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
using namespace std;
const unsigned int SCR_WIDTH = 800;
const unsigned int SCR_HEIGHT = 600;
struct VertexNormal
{
    glm::vec4 position;
    glm::vec3 normal;
    float pad;
};
MarchingCubes::MarchingCubes()
    : densitySSBO(0), vertexSSBO(0), edgeTableSSBO(0), triTableSSBO(0), normalSSBO(0),
      counterBuffer(0),
      computeShader(0), renderShader(0), VAO(0)
{
}

MarchingCubes::~MarchingCubes()
{
    glDeleteBuffers(1, &densitySSBO);
    glDeleteBuffers(1, &vertexSSBO);
    glDeleteBuffers(1, &normalSSBO);
    glDeleteBuffers(1, &edgeTableSSBO);
    glDeleteBuffers(1, &triTableSSBO);
    glDeleteBuffers(1, &counterBuffer);
    glDeleteProgram(computeShader);
    glDeleteProgram(renderShader);
    glDeleteVertexArrays(1, &VAO);
}
std::vector<float> MarchingCubes::generateLandDensityField()
{
    FastNoiseLite baseNoise;
    baseNoise.SetNoiseType(FastNoiseLite::NoiseType_Perlin);
    baseNoise.SetFrequency(0.01f);

    FastNoiseLite detailNoise;
    detailNoise.SetNoiseType(FastNoiseLite::NoiseType_Perlin);
    detailNoise.SetFrequency(0.05f);

    std::vector<float> densityField(GRID_SIZE * GRID_SIZE * GRID_SIZE);

    for (int z = 0; z < GRID_SIZE; ++z)
    {
        for (int x = 0; x < GRID_SIZE; ++x)
        {
            float nx = static_cast<float>(x) / GRID_SIZE;
            float nz = static_cast<float>(z) / GRID_SIZE;
            float baseHeight = (baseNoise.GetNoise(nx * 150.0f, nz * 150.0f) * 0.5f + 1.0f) * (GRID_SIZE * 0.5f);

            for (int y = 0; y < GRID_SIZE; ++y)
            {
                int index = x + y * GRID_SIZE + z * GRID_SIZE * GRID_SIZE;

                float ny = static_cast<float>(y) / GRID_SIZE;

                float detail = detailNoise.GetNoise(nx * 100.0f, ny * 100.0f, nz * 100.0f);

                densityField[index] = (y - (baseHeight + detail));
            }
        }
    }

    return densityField;
}

std::vector<float> MarchingCubes::generateDensityField()
{
    cout << "enter generateDensityField" << endl;
    noise.SetNoiseType(FastNoiseLite::NoiseType_OpenSimplex2);
    cout << "setnoisetype" << endl;
    std::vector<float> densityField(GRID_SIZE * GRID_SIZE * GRID_SIZE);
    cout << "density field init" << endl;
    for (int z = 0; z < GRID_SIZE; ++z)
    {
        for (int y = 0; y < GRID_SIZE; ++y)
        {
            for (int x = 0; x < GRID_SIZE; ++x)
            {
                int index = x + y * GRID_SIZE + z * GRID_SIZE * GRID_SIZE;
                float nx = static_cast<float>(x) / GRID_SIZE;
                float ny = static_cast<float>(y) / GRID_SIZE;
                float nz = static_cast<float>(z) / GRID_SIZE;
                densityField[index] = noise.GetNoise(nx * 100.0f, ny * 100.0f, nz * 100.0f);
            }
        }
    }
    cout << "density field set";
    return densityField;
}
std::vector<float> MarchingCubes::generateSphereDensityField()
{
    std::vector<float> densityField(GRID_SIZE * GRID_SIZE * GRID_SIZE);

    // Define sphere parameters
    glm::vec3 center(GRID_SIZE / 2.0f, GRID_SIZE / 2.0f, GRID_SIZE / 2.0f);
    float radius = GRID_SIZE / 4.0f; // This will make the sphere take up half the grid

    for (int z = 0; z < GRID_SIZE; ++z)
    {
        for (int y = 0; y < GRID_SIZE; ++y)
        {
            for (int x = 0; x < GRID_SIZE; ++x)
            {
                int index = x + y * GRID_SIZE + z * GRID_SIZE * GRID_SIZE;

                // Calculate distance from current point to sphere center
                glm::vec3 pos(x, y, z);
                float distance = glm::length(pos - center) - radius;

                // The density is the signed distance field:
                // Negative inside the sphere, positive outside
                densityField[index] = distance;
            }
        }
    }

    return densityField;
}
void MarchingCubes::createDensitySSBO()
{
    cout << "Creating density SSBO..." << endl;
    std::vector<float> densityField = generateLandDensityField();
    cout << "densityField" << endl;
    glGenBuffers(1, &densitySSBO);
    cout << "buffers bound";
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, densitySSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, densityField.size() * sizeof(float), densityField.data(), GL_DYNAMIC_DRAW);
    GLenum error = glGetError();
    if (error != GL_NO_ERROR)
    {
        std::cerr << "OpenGL Error after glBufferData: " << error << std::endl;
    }
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, densitySSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}

void MarchingCubes::uploadMarchingCubesTables()
{
    glGenBuffers(1, &edgeTableSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, edgeTableSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, edgetable.size() * sizeof(int), edgetable.data(), GL_STATIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, edgeTableSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    std::vector<int> flattenedTriTable;
    for (const auto &row : tritable)
    {
        flattenedTriTable.insert(flattenedTriTable.end(), row.begin(), row.end());
    }

    glGenBuffers(1, &triTableSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, triTableSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, flattenedTriTable.size() * sizeof(int), flattenedTriTable.data(), GL_STATIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, triTableSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}

void MarchingCubes::initialize()
{
    setupShaders();
    setupBuffers();
    createDensitySSBO();
    uploadMarchingCubesTables();
}

void MarchingCubes::setupBuffers()
{
    int maxVertices = GRID_SIZE * GRID_SIZE * GRID_SIZE * 15;

    glGenBuffers(1, &vertexSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, vertexSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, maxVertices * sizeof(VertexNormal), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, vertexSSBO);

    glGenBuffers(1, &counterBuffer);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, counterBuffer);
    unsigned int zero = 0;
    glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int), &zero, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 4, counterBuffer);

    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, vertexSSBO);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, sizeof(VertexNormal), (void *)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(VertexNormal), (void *)16);
    glEnableVertexAttribArray(1);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
}
void MarchingCubes::setupShaders()
{

    {
        Shader computeShaderObj("shaders/marchingCube.comp.glsl");
        computeShader = computeShaderObj.ID;
    }

    {
        Shader renderShaderObj("shaders/vertex.glsl", "shaders/fragment.glsl");
        renderShader = renderShaderObj.ID;
    }
}

void MarchingCubes::render(Camera camera)
{
    glUseProgram(computeShader);
    glDispatchCompute((GRID_SIZE) / 8, (GRID_SIZE) / 8, (GRID_SIZE) / 8);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    glBindBuffer(GL_SHADER_STORAGE_BUFFER, counterBuffer);
    unsigned int vertexCount = 0;
    glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(unsigned int), &vertexCount);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    if (vertexCount == 0)
    {
        std::cout << "No vertices generated. Skipping rendering." << std::endl;
        return;
    }

    glm::mat4 model = glm::mat4(1.0f);
    glm::mat4 view = camera.GetViewMatrix();
    glm::mat4 projection = glm::perspective(glm::radians(camera.Zoom), (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.1f, 100.0f);

    glUseProgram(renderShader);
    glUniformMatrix4fv(glGetUniformLocation(renderShader, "model"), 1, GL_FALSE, glm::value_ptr(model));
    glUniformMatrix4fv(glGetUniformLocation(renderShader, "view"), 1, GL_FALSE, glm::value_ptr(view));
    glUniformMatrix4fv(glGetUniformLocation(renderShader, "projection"), 1, GL_FALSE, glm::value_ptr(projection));

    glm::vec3 lightPos(0.0f, 40.0f, 60.0f);
    glm::vec3 viewPos = camera.Position;
    glm::vec3 lightColor(1.0f, 1.0f, 1.0f);
    glm::vec3 objectColor(0.6f, 0.9f, 0.6f);

    glUniform3fv(glGetUniformLocation(renderShader, "lightPos"), 1, glm::value_ptr(lightPos));
    glUniform3fv(glGetUniformLocation(renderShader, "viewPos"), 1, glm::value_ptr(viewPos));
    glUniform3fv(glGetUniformLocation(renderShader, "lightColor"), 1, glm::value_ptr(lightColor));
    glUniform3fv(glGetUniformLocation(renderShader, "objectColor"), 1, glm::value_ptr(objectColor));

    glBindVertexArray(VAO);
    glDrawArrays(GL_TRIANGLES, 0, vertexCount);
    glBindVertexArray(0);
    // glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
}

void MarchingCubes::debugComputeShaderOutput()
{
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // Read back the vertex count
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, counterBuffer);
    unsigned int vertexCount = 0;
    glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(unsigned int), &vertexCount);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    std::cout << "Vertex Count: " << vertexCount << std::endl;

    // Read back the generated vertices
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, vertexSSBO);
    glm::vec4 *mappedVertices = (glm::vec4 *)glMapBuffer(GL_SHADER_STORAGE_BUFFER, GL_READ_ONLY);

    if (mappedVertices)
    {
        std::cout << "Generated Vertices: " << std::endl;
        for (unsigned int i = 0; i < std::min(vertexCount, 10u); i++) // Print first 10 vertices
        {
            std::cout << "Vertex " << i << ": ("
                      << mappedVertices[i].x << ", "
                      << mappedVertices[i].y << ", "
                      << mappedVertices[i].z << ", "
                      << mappedVertices[i].w << ")" << std::endl;
        }

        glUnmapBuffer(GL_SHADER_STORAGE_BUFFER);
    }
    else
    {
        std::cerr << "Error: Failed to map vertex buffer!" << std::endl;
    }
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}
void MarchingCubes::resetVertexCounter()
{
    unsigned int zero = 0;
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, counterBuffer);
    glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(unsigned int), &zero);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}