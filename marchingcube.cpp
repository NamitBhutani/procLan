#include "include/marchingcube.h"
#include "include/tritable.h"
#include "include/edgetable.h"
#include "include/shader.h"
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
using namespace std;
const unsigned int SCR_WIDTH = 800;
const unsigned int SCR_HEIGHT = 600;
MarchingCubes::MarchingCubes()
    : densitySSBO(0), vertexSSBO(0), edgeTableSSBO(0), triTableSSBO(0),
      counterBuffer(0), computeShader(0), renderShader(0), VAO(0)
{
}

MarchingCubes::~MarchingCubes()
{
    glDeleteBuffers(1, &densitySSBO);
    glDeleteBuffers(1, &vertexSSBO);
    glDeleteBuffers(1, &edgeTableSSBO);
    glDeleteBuffers(1, &triTableSSBO);
    glDeleteProgram(computeShader);
    glDeleteProgram(renderShader);
    glDeleteVertexArrays(1, &VAO);
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
                densityField[index] = noise.GetNoise(nx * 20.0f, ny * 20.0f, nz * 20.0f);
            }
        }
    }
    cout << "density field set";
    return densityField;
}

void MarchingCubes::createDensitySSBO()
{
    cout << "Creating density SSBO..." << endl;
    std::vector<float> densityField = generateDensityField();
    cout << "densityField" << endl;
    glGenBuffers(1, &densitySSBO);
    cout << "buffers bound";
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, densitySSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, densityField.size() * sizeof(float), densityField.data(), GL_DYNAMIC_DRAW);
    GLenum error = glGetError();
    if (error != GL_NO_ERROR)
    {
        std::cerr << "OpenGL Error after glBufferData: " << error << std::endl;
        // You might want to handle the error (e.g., cleanup or abort)
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
    // Create vertex SSBO for compute shader output
    int maxVertices = GRID_SIZE * GRID_SIZE * GRID_SIZE * 15; // worst-case vertex count
    glGenBuffers(1, &vertexSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, vertexSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, maxVertices * sizeof(glm::vec4), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, vertexSSBO);

    // Verify vertex buffer creation
    GLint vertexBufferSize = 0;
    glGetBufferParameteriv(GL_SHADER_STORAGE_BUFFER, GL_BUFFER_SIZE, &vertexBufferSize);
    if (vertexBufferSize != maxVertices * sizeof(glm::vec4))
    {
        std::cout << "Error: Vertex buffer size mismatch. Expected: "
                  << maxVertices * sizeof(glm::vec4) << ", Got: " << vertexBufferSize << std::endl;
        return;
    }

    glGenBuffers(1, &counterBuffer);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, counterBuffer);
    unsigned int initCounter = 0;
    glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int), &initCounter, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 4, counterBuffer);

    // Create VAO for rendering
    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, vertexSSBO);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, sizeof(glm::vec4), (void *)0);
    glEnableVertexAttribArray(0);

    GLenum error = glGetError();
    if (error != GL_NO_ERROR)
    {
        std::cout << "OpenGL Error during buffer setup: " << error << std::endl;
        return;
    }

    // Clean up bindings
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
}
void MarchingCubes::setupShaders()
{

    {
        Shader computeShaderObj("shaders/marchingCube.comp.glsl");
        computeShader = computeShaderObj.ID;
    }

    // {
    //     Shader renderShaderObj("shaders/vertex.glsl", "shaders/fragment.glsl");
    //     renderShader = renderShaderObj.ID;
    // }
}

void MarchingCubes::render()
{
    // Dispatch compute shader
    glUseProgram(computeShader);
    glDispatchCompute((GRID_SIZE) / 8, (GRID_SIZE) / 8, (GRID_SIZE) / 8);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    // glMemoryBarrier(GL_ALL_BARRIER_BITS);

    // Render generated mesh
    // glUseProgram(renderShader);

    // // Set up transformation matrices
    // glm::mat4 model = glm::mat4(1.0f);
    // model = glm::translate(model, glm::vec3(-16.0f, -16.0f, -16.0f)); // Center the grid
    // model = glm::scale(model, glm::vec3(0.1f));                       // Scale down

    // glm::mat4 view = glm::lookAt(
    //     glm::vec3(5.0f, 5.0f, 5.0f), // Camera position
    //     glm::vec3(0.0f, 0.0f, 0.0f), // Look at origin
    //     glm::vec3(0.0f, 1.0f, 0.0f)  // Up vector
    // );

    // glm::mat4 projection = glm::perspective(
    //     glm::radians(45.0f),
    //     (float)SCR_WIDTH / (float)SCR_HEIGHT,
    //     0.1f,
    //     100.0f);

    // glUniformMatrix4fv(glGetUniformLocation(renderShader, "model"), 1, GL_FALSE, glm::value_ptr(model));
    // glUniformMatrix4fv(glGetUniformLocation(renderShader, "view"), 1, GL_FALSE, glm::value_ptr(view));
    // glUniformMatrix4fv(glGetUniformLocation(renderShader, "projection"), 1, GL_FALSE, glm::value_ptr(projection));

    // glBindVertexArray(VAO);

    // // Reset counter before each frame
    // unsigned int zero = 0;
    // glBindBuffer(GL_SHADER_STORAGE_BUFFER, counterBuffer);
    // glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(unsigned int), &zero);
    // glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // // Get vertex count after compute shader runs
    // unsigned int numGeneratedVertices = 0;
    // glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(unsigned int), &numGeneratedVertices);

    // glDrawArrays(GL_TRIANGLES, 0, numGeneratedVertices);
}
void MarchingCubes::debugComputeShaderOutput()
{
    // Ensure compute shader has finished execution before reading back data
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