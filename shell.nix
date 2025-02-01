{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "opengl-dev";

  buildInputs = with pkgs; [
    pkg-config      # Dependency management for libraries
    glm             # GLM library
    libGL        
    glfw       
    gcc
    cmake
    ninja   
    assimp
  ];

  shellHook = ''
    zsh
  '';
}
