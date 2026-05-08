#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    float isPlaying;
    float energy;
    float bass;
    float kick;
};

layout(binding = 1) uniform sampler2D src;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 center = vec2(0.5, 0.5);

    // Bass zoom — image breathes with the low end
    float zoom = 1.15 + bass * 0.05 * isPlaying;
    vec2 warped = (uv - center) / zoom + center;

    // Slow rotation that speeds up on kicks
    float angle = iTime * 0.01 + kick * 0.03;
    vec2 rotUV = warped - center;
    float ca = cos(angle), sa = sin(angle);
    warped = vec2(rotUV.x * ca - rotUV.y * sa, rotUV.x * sa + rotUV.y * ca) + center;

    // Kick shake — displaces UV on transients
    float shakeAmt = kick * 0.008 * isPlaying;
    warped.x += sin(iTime * 73.0) * shakeAmt;
    warped.y += cos(iTime * 91.0) * shakeAmt;

    // Chromatic aberration — scales with energy
    float spread = 0.002 + energy * 0.006 * isPlaying;
    vec3 col;
    col.r = texture(src, warped + vec2(spread, spread * 0.5)).r;
    col.g = texture(src, warped).g;
    col.b = texture(src, warped - vec2(spread, spread * 0.5)).b;

    // Bloom — sample blurred version and add
    vec2 px = vec2(1.0 / 320.0, 1.0 / 200.0) * 3.0;
    vec3 bloom = vec3(0.0);
    for (float x = -1.0; x <= 1.0; x += 1.0) {
        for (float y = -1.0; y <= 1.0; y += 1.0) {
            bloom += texture(src, warped + vec2(x, y) * px).rgb;
        }
    }
    bloom /= 9.0;
    col = mix(col, col + bloom * 0.3, energy * isPlaying);

    col *= 0.5;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
