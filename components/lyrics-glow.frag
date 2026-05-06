#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    // Approximate pixel size for blur (assumes ~300px wide text area)
    vec2 px = vec2(1.0 / 300.0, 1.0 / 60.0) * 2.5;

    // 9-tap box blur for soft glow
    vec4 sum = vec4(0.0);
    for (float x = -1.0; x <= 1.0; x += 1.0) {
        for (float y = -1.0; y <= 1.0; y += 1.0) {
            sum += texture(source, uv + vec2(x, y) * px);
        }
    }
    sum /= 9.0;

    // Boost brightness for glow effect
    vec4 col = sum * 1.8;
    col.a = min(col.a, 1.0);

    fragColor = col * qt_Opacity;
}
