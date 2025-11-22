cmake_minimum_required(VERSION 3.10)
project(marchingcubes)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set OpenGL preference to GLVND
set(OpenGL_GL_PREFERENCE GLVND)
cmake_policy(SET CMP0072 NEW)

# Find required packages
find_package(OpenGL REQUIRED)
find_package(glfw3 REQUIRED)

# Add glad library
add_library(glad STATIC
    glad/glad.c)
target_include_directories(glad PRIVATE
    glad/include)

# Collect all source files
set(SOURCE_FILES
    edgetable.cpp
    tritable.cpp
    marchingcube.cpp
    main.cpp)

# Collect all shader files using GLOB
file(GLOB SHADER_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*")

# Add executable
add_executable(${PROJECT_NAME} ${SOURCE_FILES})

# Include directories
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    glad/include
    ${GLFW_INCLUDE_DIRS}
    ${GLM_INCLUDE_DIRS}
    $ENV{GLM_INCLUDE_DIR})

# Link libraries
target_link_libraries(${PROJECT_NAME} PRIVATE
    glad
    glfw
    OpenGL::GL
    assimp
    ${CMAKE_DL_LIBS})

set(SHADER_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/shaders")
set(SHADER_DEST_DIR "${CMAKE_BINARY_DIR}/shaders")

file(MAKE_DIRECTORY ${SHADER_DEST_DIR})

add_custom_target(copyShaders ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${SHADER_SOURCE_DIR} ${SHADER_DEST_DIR}
    COMMENT "copying shaders to build directory"
)

add_dependencies(${PROJECT_NAME} copyShaders)