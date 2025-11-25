#pragma once
#include <glad/glad.h>
#include <vector>
#include "FastNoiseLite.h"
#include <glm/glm.hpp>
#include "include/camera.h"

class MarchingCubes
{
private:
    static const int GRID_SIZE = 64;
    static const int DENSITY_SIZE = GRID_SIZE + 3;

    GLuint densitySSBO;
    GLuint vertexSSBO;
    GLuint edgeTableSSBO;
    GLuint triTableSSBO;
    GLuint counterBuffer;
    GLuint computeShader;
    GLuint renderShader;
    GLuint densityComputeShader;
    GLuint normalSSBO;
    GLuint VAO;

    FastNoiseLite noise;

    struct Cave
    {
        glm::vec3 offset;
        float gain;
        float frequency;
        Cave(const glm::vec3 &o = glm::vec3(0.0f), float g = 1.0f, float f = 0.02f) : offset(o), gain(g), frequency(f) {}
    };

    void createDensitySSBO();
    void uploadMarchingCubesTables();
    void setupShaders();
    void setupBuffers();

public:
    MarchingCubes();
    ~MarchingCubes();
    void initialize();
    void render(Camera camera);
    void debugComputeShaderOutput();
    void resetVertexCounter();

    static const int MAX_CAVES = 8;

    int seed;
    std::vector<Cave> caves;
    float caveCeiling = 25.0f;
};
