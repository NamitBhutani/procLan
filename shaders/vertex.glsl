#version 460 core
layout(location = 0) in vec4 position;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 FragPos;
out vec3 Normal;

void main() {
    FragPos = vec3(model * position);
    Normal = normalize(FragPos);  // Simple normal calculation
    gl_Position = projection * view * vec4(FragPos, 1.0);
}