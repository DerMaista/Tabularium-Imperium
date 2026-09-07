#version 440

// /usr/lib/qt6/bin/qsb --glsl 100es,120,150 --hlsl 50 --msl 12 -o color_swap.frag.qsb color_swap.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 primaryColor;
    vec4 accentColor;
};

layout(binding = 1) uniform sampler2D src;

void main() {
    lowp vec4 texColor = texture(src, qt_TexCoord0);

    if (texColor.a == 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    lowp float brightness = dot(texColor.rgb, vec3(0.299, 0.587, 0.114));

    lowp vec4 finalColor = mix(primaryColor, accentColor, brightness);

    fragColor = finalColor * texColor.a * qt_Opacity;
}