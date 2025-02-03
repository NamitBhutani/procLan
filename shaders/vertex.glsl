#version 460 core
layout(location = 0) in vec4 position;
layout(location = 1) in vec3 normal;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 fragPos;
out vec3 fragNormal;

void main() {
    fragPos = vec3(model * position);
    fragNormal = mat3(transpose(inverse(model))) * normal;
    gl_Position = projection * view * model * position;
}
