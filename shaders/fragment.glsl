#version 460 core
out vec4 FragColor;

in vec3 fragPos;
in vec3 fragNormal;

uniform vec3 viewPos;

const vec3 COLOR_GRASS = vec3(0.13, 0.55, 0.13);
const vec3 COLOR_ROCK  = vec3(0.35, 0.33, 0.31); 
const vec3 COLOR_SNOW  = vec3(0.95, 0.95, 1.0);
const vec3 COLOR_DIRT  = vec3(0.40, 0.30, 0.20);
const vec3 SKY_COLOR = vec3(0.53, 0.81, 0.92); 

void main() {
    vec3 norm = normalize(fragNormal);
    vec3 viewDir = normalize(viewPos - fragPos);
    vec3 lightDir = normalize(vec3(0.5, 1.0, 0.3)); 

    float slope = dot(norm, vec3(0.0, 1.0, 0.0));
    float grassBlend = smoothstep(0.4, 0.7, slope);
    vec3 terrainColor = mix(COLOR_ROCK, COLOR_GRASS, grassBlend);

    if(fragPos.y > 40.0) {
        float snowBlend = smoothstep(40.0, 55.0, fragPos.y) * slope;
        terrainColor = mix(terrainColor, COLOR_SNOW, snowBlend);
    }
    if(fragPos.y < 10.0) {
       float dirtBlend = smoothstep(10.0, 0.0, fragPos.y);
       terrainColor = mix(terrainColor, COLOR_DIRT, dirtBlend);
    }

    float up = norm.y * 0.5 + 0.5;
    vec3 groundColor = vec3(0.4, 0.35, 0.3); 
    vec3 skyColor    = vec3(0.6, 0.7, 0.8);
    
    vec3 ambient = mix(groundColor, skyColor, up);
    float caveBoost = 1.0 - smoothstep(5.0, 30.0, fragPos.y);
    ambient += vec3(0.15, 0.12, 0.1) * caveBoost;

    ambient *= 0.8;
    float NdotL = dot(norm, lightDir);
    float diff = NdotL * 0.5 + 0.5; 
    diff = diff * diff;
    vec3 diffuse = diff * vec3(1.0, 0.98, 0.9);

    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    vec3 specular = vec3(0.05) * spec;

    vec3 lighting = (ambient + diffuse + specular) * terrainColor;

    float dist = length(viewPos - fragPos);
    float fogFactor = smoothstep(150.0, 250.0, dist);
    vec3 finalColor = mix(lighting, SKY_COLOR, fogFactor);

    FragColor = vec4(finalColor, 1.0);
}