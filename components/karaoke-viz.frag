#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    float progress;
    float isPlaying;
    float pixelHeight;
    vec4 color1;
    vec4 color2;
    vec4 color3;
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

// Smooth interpolated sample lookup
float getSampleSmooth(float x) {
    float pos = x * 31.0;
    int i0 = clamp(int(floor(pos)), 0, 31);
    int i1 = min(i0 + 1, 31);
    float frac = pos - float(i0);
    return mix(getSample(i0), getSample(i1), frac);
}

// Simplex noise
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

void main() {
    vec2 uv = qt_TexCoord0;
    float speed = mix(0.08, 0.35, isPlaying);
    float t = iTime * speed;

    vec3 c1 = color1.rgb;
    vec3 c2 = color2.rgb;
    vec3 c3 = color3.rgb;

    // ── 1. Aurora background (cheap: 2 noise lookups) ──
    float n1 = snoise(uv * 1.5 + vec2(t * 0.3, t * 0.1)) * 0.5 + 0.5;
    float n2 = snoise(uv * 2.0 + vec2(-t * 0.2, t * 0.4)) * 0.5 + 0.5;
    vec3 aurora = mix(c1, c2, n1);
    aurora = mix(aurora, c3, n2 * 0.4);

    float breath = 0.5 + 0.1 * sin(t * 1.5) * isPlaying;
    float vig = smoothstep(0.0, 0.3, uv.x) * smoothstep(1.0, 0.7, uv.x)
              * smoothstep(0.0, 0.2, uv.y) * smoothstep(1.0, 0.8, uv.y);
    float auroraAlpha = breath * vig * 0.25;

    // ── 2. Bottom waveform (smooth interpolated samples, no curve tracing) ──
    float samp = getSampleSmooth(uv.x);
    float waveH = samp * 0.18 * isPlaying;
    float distBottom = 1.0 - uv.y;
    // Soft glow field instead of hard edge
    float bottomWave = exp(-pow(max(distBottom - waveH, 0.0) * 15.0, 2.0)) * samp;
    // Fill below wave
    float bottomFill = smoothstep(waveH + 0.01, waveH - 0.005, distBottom) * 0.3;
    float bottomA = (bottomWave * 0.5 + bottomFill) * isPlaying;

    // ── 3. Top waveform (mirrored, dimmer) ──
    float topWaveH = samp * 0.10 * isPlaying;
    float distTop = uv.y;
    float topWave = exp(-pow(max(distTop - topWaveH, 0.0) * 18.0, 2.0)) * samp;
    float topFill = smoothstep(topWaveH + 0.008, topWaveH - 0.004, distTop) * 0.2;
    float topA = (topWave * 0.35 + topFill) * isPlaying;

    // Color per position
    float barT = uv.x;
    vec3 bottomCol = mix(c1, c2, barT);
    vec3 topCol = mix(c2, c3, barT);

    // ── 4. Side ribbons ──
    float avgLow = (getSample(0) + getSample(1) + getSample(2) + getSample(3)) * 0.25;
    float avgHigh = (getSample(20) + getSample(21) + getSample(22) + getSample(23)) * 0.25;

    float leftEdge = 0.015 + sin(uv.y * 12.0 + t * 8.0) * avgLow * 0.03 + avgLow * 0.035;
    float leftRibbon = smoothstep(leftEdge, 0.0, uv.x);

    float rightEdge = 0.985 - sin(uv.y * 10.0 - t * 7.0) * avgHigh * 0.03 - avgHigh * 0.035;
    float rightRibbon = smoothstep(rightEdge, 1.0, uv.x);

    float ribbonAlpha = (leftRibbon + rightRibbon) * 0.35 * isPlaying;
    vec3 ribbonColor = mix(c1, c3, uv.y);

    // ── 5. Progress pulse ──
    float progGlow = smoothstep(0.12, 0.0, abs(uv.x - progress)) * 0.1 * isPlaying;

    // ── Composite ──
    vec3 col = aurora * auroraAlpha;
    col += bottomCol * bottomA;
    col += topCol * topA;
    col += ribbonColor * ribbonAlpha;
    col += progGlow * c1;

    float alpha = auroraAlpha + bottomA + topA + ribbonAlpha + progGlow;
    alpha = min(alpha, 0.85);

    // Darken center for readability
    float centerDim = 1.0 - 0.45 * smoothstep(0.4, 0.0, abs(uv.y - 0.55)) * smoothstep(0.45, 0.0, abs(uv.x - 0.5));
    col *= centerDim;

    fragColor = vec4(col, alpha) * qt_Opacity;
}
