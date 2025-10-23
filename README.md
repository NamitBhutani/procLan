# procLan: Procedural Terrain Generator

`procLan` is a GPU-accelerated procedural terrain generation system using the Marching Cubes algorithm. It's implemented in C++ and modern OpenGL, using compute shaders to extract and render 3D isosurfaces from a noise field in real-time.

## Features

  * **GPU-Accelerated:** Renders 100K+ polygon meshes at over 60 FPS by offloading work to the GPU.
  * **Marching Cubes:** Implements the Marching Cubes algorithm in a compute shader for efficient isosurface extraction.
  * **3D Viewer:** Includes an interactive 3D viewer with:
      * Phong lighting model
      * Wireframe rendering mode
      * Free-fly camera controls

-----

## Technical Details

This project uses a compute-shader-based pipeline to minimize CPU overhead.

1.  A **compute shader** runs the Marching Cubes algorithm on a Perlin noise field, calculating vertex positions and normals.
2.  The resulting mesh data is written to an **optimized Shader Storage Buffer Object (SSBO)**.
3.  The vertex shader reads directly from the SSBO for rendering, eliminating the need for slow CPU read-back.
4.  The fragment shader applies per-fragment **Phong lighting** for a smooth, shaded appearance.

-----

## Technology Stack

  * **Language:** C++
  * **Graphics API:** OpenGL (with compute shaders)
  * **OpenGL Loader:** `glad` (as a submodule)
  * **Algorithms:** Marching Cubes, Perlin Noise
  * **Shading:** GLSL (Vertex, Fragment, and Compute Shaders)

-----

## Building the Project

```bash
git clone --recursive https://github.com/NamitBhutani/procLan.git
cd procLan

mkdir build
cd build
cmake ..
make
```
