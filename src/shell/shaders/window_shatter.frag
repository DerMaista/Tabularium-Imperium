#version 440

// qsb --glsl 100es,120,150 --hlsl 50 --msl 12 -o window_shatter.frag.qsb window_shatter.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
    vec2 cropOrigin;
    vec2 cropSize;
    vec2 seed;
};

layout(binding = 1) uniform sampler2D src;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec4 sampleCrop(vec2 local) {
    vec2 inside = step(vec2(0.0), local) * step(local, vec2(1.0));
    vec2 atlas = cropOrigin + clamp(local, 0.0, 1.0) * cropSize;
    return texture(src, atlas) * inside.x * inside.y;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = clamp(progress, 0.0, 1.0);

    vec2 cc = uv * vec2(aspect, 1.0) * 7.0;
    vec2 gi = floor(cc);

    float best = 1e9;
    vec2 bestId = gi;

    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            vec2 id = gi + vec2(float(i), float(j));
            vec2 fp = id + vec2(hash21(id + seed), hash21(id + seed + 7.3));
            float d = length(cc - fp);
            if (d < best) {
                best = d;
                bestId = id;
            }
        }
    }

    vec2 dir = normalize(vec2(hash21(bestId + 1.7) - 0.5, hash21(bestId + 3.1) - 0.5) + vec2(1e-5));
    float speed = 0.10 + 0.40 * hash21(bestId + 5.5);

    vec2 off = dir * speed * p * p;
    off.y += 0.20 * p * p * p;

    vec4 shard = sampleCrop(uv - off / vec2(aspect, 1.0));

    float life = 0.45 + 0.45 * hash21(bestId + 9.2);
    float alpha = 1.0 - smoothstep(life, 1.0, p);

    fragColor = shard * alpha * qt_Opacity;
}
