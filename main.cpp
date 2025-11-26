#include "imgui.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include "include/marchingcube.h"
#include "include/camera.h"
#include <iostream>
#include <random>
#include <chrono>

const unsigned int SCR_WIDTH = 800;
const unsigned int SCR_HEIGHT = 600;

// camera
Camera camera(glm::vec3(-80.0f, 80.0f, 80.0f));
float lastX = SCR_WIDTH / 2.0f;
float lastY = SCR_HEIGHT / 2.0f;
bool firstMouse = true;
double curX = SCR_WIDTH / 2.0;
double curY = SCR_HEIGHT / 2.0;
bool mouseMoved = false;

// timing
float deltaTime = 0.0f;
float lastFrame = 0.0f;

bool show_control_window = false;
bool prev_show_control_window = show_control_window;
bool wireframe = false;
bool prevEnter = false;

void mouse_callback(GLFWwindow *window, double xposIn, double yposIn)
{
    // Record latest cursor position; actual camera processing happens in main loop
    curX = xposIn;
    curY = yposIn;
    mouseMoved = true;
}

void processInput(GLFWwindow *window)
{
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);

    ImGuiIO &io = ImGui::GetIO();
    if (show_control_window && io.WantCaptureKeyboard)
    {
        if (glfwGetKey(window, GLFW_KEY_M) == GLFW_PRESS)
        {
            show_control_window = !show_control_window;
            return;
        }
        // do not allow any other keyboard input
        return;
    }

    if (glfwGetKey(window, GLFW_KEY_M) == GLFW_PRESS)
    {
        show_control_window = !show_control_window;
        return;
    }

    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
        camera.ProcessKeyboard(FORWARD, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
        camera.ProcessKeyboard(BACKWARD, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
        camera.ProcessKeyboard(LEFT, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
        camera.ProcessKeyboard(RIGHT, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS)
        camera.ProcessKeyboard(UP, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS)
        camera.ProcessKeyboard(DOWN, deltaTime);
    bool currentEnter = glfwGetKey(window, GLFW_KEY_ENTER) == GLFW_PRESS;
    if (currentEnter && !prevEnter)
    {
        wireframe = !wireframe;
        glPolygonMode(GL_FRONT_AND_BACK, wireframe ? GL_LINE : GL_FILL);
    }
    prevEnter = currentEnter;
}

void framebuffer_size_callback(GLFWwindow *window, int width, int height)
{
    glViewport(0, 0, width, height);
}

int main()
{
    std::mt19937 rng(std::chrono::steady_clock::now().time_since_epoch().count());

    if (!glfwInit())
    {
        std::cout << "Failed to initialize GLFW\n";
        return -1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow *window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Marching Cubes", NULL, NULL);
    if (!window)
    {
        std::cout << "Failed to create GLFW window\n";
        glfwTerminate();
        return -1;
    }

    glfwMakeContextCurrent(window);
    glfwSetCursorPosCallback(window, mouse_callback);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        std::cout << "Failed to initialize GLAD\n";
        return -1;
    }

    glEnable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    MarchingCubes marchingCubes;
    marchingCubes.initialize();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    (void)io;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;

    ImGui::StyleColorsDark();
    ImGuiStyle &style = ImGui::GetStyle();

    float main_scale = ImGui_ImplGlfw_GetContentScaleForMonitor(glfwGetPrimaryMonitor()) * 1.25f;
    style.ScaleAllSizes(main_scale);
    style.FontScaleDpi = main_scale;

    ImGui_ImplGlfw_InitForOpenGL(window, true);
    const char *glsl_version = "#version 460 core";
    ImGui_ImplOpenGL3_Init(glsl_version);

    while (!glfwWindowShouldClose(window))
    {
        float currentFrame = glfwGetTime();
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;
        processInput(window);

        // switch cursor mode depending on control window
        if (show_control_window)
        {
            glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
        }
        else
        {
            // if switching from ui to scene, reset firstMouse to stop camera jump
            if (prev_show_control_window)
                firstMouse = true;
            glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
        }
        prev_show_control_window = show_control_window;

        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();

        // process mouse movement only when no ImGui mouse capture
        ImGuiIO &io = ImGui::GetIO();
        if (!io.WantCaptureMouse && !show_control_window)
        {
            if (mouseMoved)
            {
                float xpos = static_cast<float>(curX);
                float ypos = static_cast<float>(curY);

                if (firstMouse)
                {
                    lastX = xpos;
                    lastY = ypos;
                    firstMouse = false;
                }

                float xoffset = xpos - lastX;
                float yoffset = lastY - ypos; // reversed since y-coordinates go from bottom to top

                lastX = xpos;
                lastY = ypos;

                camera.ProcessMouseMovement(xoffset, yoffset);
                mouseMoved = false;
            }
        }
        else
        {
            firstMouse = true;
            mouseMoved = false;
        }

        if (show_control_window)
        {
            ImGui::Begin("Controls & Editor", &show_control_window, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_AlwaysAutoResize);
            ImGui::Text("Terrain Seed");
            ImGui::SameLine();
            ImGui::InputInt("##seed", &marchingCubes.seed);
            ImGui::SameLine();
            if (ImGui::Button("Random"))
            {
                marchingCubes.seed = std::uniform_int_distribution<int>(0, 100000)(rng);
            }
            ImGui::Text("Cave Ceiling");
            ImGui::SameLine();
            ImGui::SliderFloat("##ceiling", &marchingCubes.caveCeiling, 0.0f, 60.0f);
            ImGui::Separator();
            ImGui::Text("Caves (%d)", (int)marchingCubes.caves.size());
            for (int i = 0; i < (int)marchingCubes.caves.size(); ++i)
            {
                char label[32];
                snprintf(label, sizeof(label), "Cave %d", i);
                if (ImGui::TreeNode(label))
                {
                    ImGui::Text("Offset");
                    ImGui::SameLine();
                    ImGui::InputFloat3("##offset", &marchingCubes.caves[i].offset.x);
                    ImGui::Text("Gain");
                    ImGui::SameLine();
                    ImGui::InputFloat("##gain", &marchingCubes.caves[i].gain);
                    ImGui::Text("Frequency");
                    ImGui::SameLine();
                    ImGui::InputFloat("##frequency", &marchingCubes.caves[i].frequency);
                    if (ImGui::Button("Remove"))
                    {
                        marchingCubes.caves.erase(marchingCubes.caves.begin() + i);
                        ImGui::TreePop();
                        break;
                    }
                    ImGui::TreePop();
                }
            }
            if (ImGui::Button("Add Cave") && (int)marchingCubes.caves.size() < MarchingCubes::MAX_CAVES)
            {
                marchingCubes.caves.emplace_back();
            }
            ImGui::Separator();
            ImGui::TextDisabled("Press M to toggle this window");
            ImGui::TextDisabled("Press ENTER to toggle wireframe mode");
            ImGui::End();
        }

        glClearColor(0.53f, 0.81f, 0.92f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        //  marchingCubes.resetVertexCounter();
        marchingCubes.render(camera);
        // cout << "render done" << endl;
        // marchingCubes.debugComputeShaderOutput();

        ImGui::Render();
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    glfwTerminate();
    return 0;
}