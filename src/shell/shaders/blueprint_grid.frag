#version 440

// Build (keep in sync with the .qsb committed next to it):
//   qsb --glsl 100es,120,150 --hlsl 50 --msl 12 -o blueprint_grid.frag.qsb blueprint_grid.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 gridColor;
    vec2 resolution;
    float gridSize;
    float thinWidth;
    float thickWidth;
};

float lineCoverage(float coord, float center, float spacing, float thin, float thick) {
    float offset = abs(coord - center);
    float index = floor(offset / spacing + 0.5);
    float distance = abs(offset - index * spacing);

    float width = mod(index, 10.0) < 0.5 ? thick : thin;

    return 1.0 - smoothstep(width * 0.5 - 0.5, width * 0.5 + 0.5, distance);
}

void main() {
    vec2 pixel = qt_TexCoord0 * resolution;
    vec2 center = resolution * 0.5;

    float vertical = lineCoverage(pixel.x, center.x, gridSize, thinWidth, thickWidth);
    float horizontal = lineCoverage(pixel.y, center.y, gridSize, thinWidth, thickWidth);

    float coverage = max(vertical, horizontal);

    fragColor = vec4(gridColor.rgb * gridColor.a, gridColor.a) * coverage * qt_Opacity;
}
