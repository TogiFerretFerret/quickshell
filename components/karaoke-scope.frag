#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float isActive;
    float sampleCount;
    float pixelHeight;
    vec4 waveColor;
    vec4 widthRatio;
    vec4 b0; vec4 b1; vec4 b2; vec4 b3;
    vec4 b4; vec4 b5; vec4 b6; vec4 b7;
};

float getSample(int i) {
    int bi = i / 4, ci = i - bi * 4;
    vec4 block;
    if      (bi == 0) block = b0; else if (bi == 1) block = b1;
    else if (bi == 2) block = b2; else if (bi == 3) block = b3;
    else if (bi == 4) block = b4; else if (bi == 5) block = b5;
    else if (bi == 6) block = b6; else              block = b7;
    if (ci == 0) return block.x; else if (ci == 1) return block.y;
    else if (ci == 2) return block.z; else return block.w;
}

float sampleY(int i, int count) {
    float v = getSample(i);
    if (i == 0 || i == count - 1) v = 0.0;
    float s = mod(float(i), 2.0) < 0.5 ? 1.0 : -1.0;
    return clamp(0.5 - v * s * 0.85 * 0.5, 0.15, 0.85);
}

vec2 curvePoint(float t, int count) {
    float seg = t * float(count - 1);
    int idx = clamp(int(floor(seg)), 0, count - 2);
    float u = seg - float(idx);

    int i0 = clamp(idx - 1, 0, count - 1);
    int i1 = idx;
    int i2 = min(idx + 1, count - 1);
    int i3 = min(idx + 2, count - 1);

    float y0 = sampleY(i0, count);
    float y1 = sampleY(i1, count);
    float y2 = sampleY(i2, count);
    float y3 = sampleY(i3, count);

    float tension = 0.420;
    float a = -tension * y0 + (2.0 - tension) * y1 + (tension - 2.0) * y2 + tension * y3;
    float b = 2.0 * tension * y0 + (tension - 3.0) * y1 + (3.0 - 2.0 * tension) * y2 - tension * y3;
    float c = -tension * y0 + tension * y2;
    float d = y1;
    float y = ((a * u + b) * u + c) * u + d;

    float x = (float(idx) + u) / float(count - 1);
    return vec2(x, clamp(y, 0.05, 0.95));
}

float segDist(vec2 p, vec2 a, vec2 b, float ar) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    vec2 d = p - (a + t * ab);
    d.x *= ar;
    return length(d);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float h = pixelHeight;
    float ar = widthRatio.x;

    if (isActive < 0.5 || sampleCount < 2.0) {
        float dpx = abs(uv.y - 0.5) * h;
        float a = smoothstep(1.5, 0.0, dpx) * 0.4 * qt_Opacity;
        fragColor = vec4(waveColor.rgb * a, a);
        return;
    }

    int count = max(int(sampleCount), 2);

    const int N = 96;
    float minDist = 1e10;
    vec2 prev = curvePoint(0.0, count);
    for (int i = 1; i <= N; i++) {
        vec2 curr = curvePoint(float(i) / float(N), count);
        float d = segDist(uv, prev, curr, ar);
        minDist = min(minDist, d);
        prev = curr;
    }

    float dpx = minDist * h;

    // Thicker core line (~3px)
    float lineA = smoothstep(3.5, 0.5, dpx);
    // Wide glow (~10px)
    float glowA = smoothstep(14.0, 0.0, dpx) * 0.35;
    // Fat bloom
    float bloomA = exp(-dpx * dpx * 0.02) * 0.2;

    float a = max(max(lineA, glowA), bloomA) * qt_Opacity;
    fragColor = vec4(waveColor.rgb * a, a);
}
