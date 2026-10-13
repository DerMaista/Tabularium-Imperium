#version 440

// /usr/lib/qt6/bin/qsb --glsl 100es,120,150 --hlsl 50 --msl 12 -o tint.frag.qsb tint.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tintColor;
    vec4 shadeColor;
};

layout(binding = 1) uniform sampler2D src;

// Duotone: bright parts of the icon become tintColor, dark parts shadeColor,
// so filled colored icons keep their inner detail instead of turning into a
// flat silhouette (or into black, as a luminance multiply does with dark tints).
void main() {
    lowp vec4 texColor = texture(src, qt_TexCoord0);

    if (texColor.a == 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    lowp float brightness = dot(texColor.rgb / texColor.a, vec3(0.299, 0.587, 0.114));

    fragColor = mix(shadeColor, tintColor, brightness) * texColor.a * qt_Opacity;
}
