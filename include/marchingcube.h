#pragma once
#include <glad/glad.h>
#include <vector>
#include "FastNoiseLite.h"
#include <glm/glm.hpp>
#include "include/camera.h"

class MarchingCubes
{
private:
    static const int GRID_SIZE = 32;
    GLuint densitySSBO;
    GLuint vertexSSBO;
    GLuint edgeTableSSBO;
    GLuint triTableSSBO;
    GLuint counterBuffer;
    GLuint computeShader;
    GLuint renderShader;
    GLuint VAO;

    FastNoiseLite noise;

    std::vector<float> generateDensityField();
    std::vector<float> generateSphereDensityField();
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
};
