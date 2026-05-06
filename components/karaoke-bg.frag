#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    float progress;
    float isPlaying;
    vec4  color1;
    vec4  color2;
    vec4  color3;
};

vec3 mod289(vec3 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x * 34.0) + 1.0) * x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                       -0.577350269189626, 0.024390243902439);
    vec2 i = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m * m; m = m * m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 a0 = x - floor(x + 0.5);
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
    vec3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float fbm(vec2 p, float t) {
    float f = 0.0;
    f += 0.5000 * snoise(p * 1.0 + t * 0.15);
    f += 0.2500 * snoise(p * 2.0 - t * 0.22);
    f += 0.1250 * snoise(p * 4.0 + t * 0.30);
    f += 0.0625 * snoise(p * 8.0 - t * 0.10);
    return f;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float speed = mix(0.12, 0.4, isPlaying);
    float t = iTime * speed;

    // Large flowing noise fields
    float n1 = fbm(uv * 1.5 + vec2(t * 0.3, t * 0.1), t);
    float n2 = fbm(uv * 2.0 + vec2(-t * 0.2, t * 0.4), t * 1.3);
    float n3 = fbm(uv * 1.2 + vec2(t * 0.15, -t * 0.25), t * 0.7);

    // Blend three accent colors
    vec3 c1 = color1.rgb;
    vec3 c2 = color2.rgb;
    vec3 c3 = color3.rgb;

    float blend1 = smoothstep(-0.2, 0.6, n1);
    float blend2 = smoothstep(-0.1, 0.5, n2);
    vec3 col = mix(c1, c2, blend1);
    col = mix(col, c3, blend2 * 0.5);

    // Subtle progress pulse
    float progGlow = smoothstep(0.2, 0.0, abs(uv.x - progress)) * 0.15 * isPlaying;
    col += progGlow;

    // Breathing
    float breath = 0.55 + 0.1 * sin(t * 1.5) * isPlaying;

    // Strong center vignette — keep lyrics readable
    float vig = smoothstep(0.0, 0.35, uv.x) * smoothstep(1.0, 0.65, uv.x)
              * smoothstep(0.0, 0.25, uv.y) * smoothstep(1.0, 0.75, uv.y);

    // Extra darkening in the center column where lyrics sit
    float centerDim = 1.0 - 0.3 * smoothstep(0.35, 0.15, abs(uv.x - 0.5));

    float alpha = breath * vig * centerDim * 0.45;
    fragColor = vec4(col * alpha, alpha) * qt_Opacity;
}
