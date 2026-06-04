#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    float weatherCode;  // 0=clear, 1=cloud, 2=rain, 3=snow, 4=thunder
    vec4 accent;        // primary color
    vec4 dims;          // .x = width, .y = height
};

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash1(float p) {
    return fract(sin(p * 127.1) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// Rain — layered streaks with varied angle/speed/length
float rain(vec2 uv, float t) {
    float drops = 0.0;
    for (float i = 0.0; i < 6.0; i++) {
        float scale = 4.0 + i * 2.8;
        float speed = 2.2 + i * 1.0 + hash1(i) * 0.6;
        float angle = -0.12 - i * 0.04;
        vec2 st = uv * vec2(scale, scale * 0.3);
        st.x += st.y * angle;
        st.y -= t * speed;
        float col_id = floor(st.x);
        st.y += hash1(col_id + i * 17.0) * 10.0;
        vec2 g = fract(st) - 0.5;
        float stretch = 4.5 + i * 1.5;
        float d = length(g * vec2(1.8, stretch));
        float intensity = 0.16 - i * 0.018;
        drops += smoothstep(0.2, 0.0, d) * intensity;
    }
    return drops;
}

// Snow — soft, varied drift
float snow(vec2 uv, float t) {
    float flakes = 0.0;
    for (float i = 0.0; i < 5.0; i++) {
        float scale = 3.5 + i * 2.5;
        float speed = 0.2 + i * 0.1;
        vec2 st = uv * scale;
        st.y -= t * speed;
        // Each layer drifts differently
        float drift = sin(t * (0.2 + i * 0.08) + i * 1.9) * 0.4;
        st.x += drift + sin(st.y * 0.6 + i * 2.7) * 0.3;
        // Per-cell jitter so it doesn't look gridded
        vec2 cell = floor(st);
        vec2 local = fract(st) - 0.5;
        vec2 jitter = vec2(hash(cell + i), hash(cell + i + 100.0)) * 0.6 - 0.3;
        float d = length(local - jitter);
        // Vary flake size
        float size = 0.06 + hash(cell + i * 50.0) * 0.04;
        flakes += smoothstep(size, 0.0, d) * (0.15 - i * 0.02);
    }
    return flakes;
}

// Lightning bolt — jagged line from top to bottom
float bolt(vec2 uv, float seed) {
    float boltX = hash1(seed) * 0.6 + 0.2; // random x position
    float brightness = 0.0;

    // Walk down the bolt
    float x = boltX;
    float prevX = x;
    float segments = 12.0;
    for (float i = 0.0; i < segments; i++) {
        float y0 = i / segments;
        float y1 = (i + 1.0) / segments;
        // Jagged horizontal displacement
        float jag = (hash1(seed * 13.7 + i * 7.3) - 0.5) * 0.08;
        float nextX = x + jag;
        // Branch occasionally
        float branch = step(0.8, hash1(seed * 3.1 + i * 11.0));

        // Distance from UV to this line segment
        vec2 a = vec2(x, y0);
        vec2 b = vec2(nextX, y1);
        vec2 pa = uv - a;
        vec2 ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        float d = length(pa - ba * h);

        // Core bolt — bright thin line
        brightness += smoothstep(0.008, 0.0, d) * 0.6;
        // Glow around bolt
        brightness += smoothstep(0.06, 0.0, d) * 0.15;
        // Wide atmospheric glow
        brightness += smoothstep(0.2, 0.0, d) * 0.04;

        // Small branch
        if (branch > 0.5) {
            float branchAng = (hash1(seed + i * 23.0) - 0.5) * 0.2;
            vec2 c = vec2(nextX + branchAng, y1 + 0.08);
            vec2 pb = uv - b;
            vec2 cb = c - b;
            float hb = clamp(dot(pb, cb) / dot(cb, cb), 0.0, 1.0);
            float db = length(pb - cb * hb);
            brightness += smoothstep(0.005, 0.0, db) * 0.3;
            brightness += smoothstep(0.04, 0.0, db) * 0.08;
        }

        x = nextX;
    }
    return brightness;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = iTime * 0.25;
    vec3 col = vec3(0.0);
    float alpha = 0.0;

    vec3 ac = accent.rgb;

    // Edge vignette
    float vig = smoothstep(0.0, 0.15, uv.x) * smoothstep(1.0, 0.85, uv.x)
              * smoothstep(0.0, 0.1, uv.y) * smoothstep(1.0, 0.9, uv.y);

    if (weatherCode < 0.5) {
        // ── CLEAR: nothing — let the UI breathe ──
        alpha = 0.0;

    } else if (weatherCode < 1.5) {
        // ── CLOUDY: drifting cloud layers ──
        float c1 = fbm(uv * 4.0 + vec2(t * 0.4, t * 0.1));
        float c2 = fbm(uv * 2.5 + vec2(t * 0.2, -t * 0.15));
        float clouds = smoothstep(0.35, 0.65, c1) * 0.6 + smoothstep(0.3, 0.7, c2) * 0.3;
        col = mix(ac * 0.15, vec3(0.25, 0.25, 0.3), clouds);
        alpha = 0.3;

    } else if (weatherCode < 2.5) {
        // ── RAIN: varied diagonal streaks + dark clouds ──
        float r = rain(uv, t);
        float clouds = fbm(uv * 2.0 + vec2(t * 0.2, t * 0.05));
        col = vec3(0.01, 0.02, 0.04) + ac * 0.04;
        col += vec3(0.02, 0.03, 0.06) * clouds;
        col += vec3(0.35, 0.45, 0.65) * r;
        alpha = 0.3;

    } else if (weatherCode < 3.5) {
        // ── SNOW: gentle drifting flakes ──
        float s = snow(uv, t);
        float haze = fbm(uv * 1.5 + vec2(t * 0.06, t * 0.1));
        col = vec3(0.03, 0.03, 0.06) + vec3(0.06, 0.06, 0.09) * haze;
        col += vec3(0.6, 0.65, 0.8) * s;
        alpha = 0.25;

    } else {
        // ── THUNDER: dark clouds + rain + lightning bolts ──
        // Ominous cloud base
        float clouds = fbm(uv * 3.0 + vec2(t * 0.3, t * 0.08));
        float clouds2 = fbm(uv * 5.0 + vec2(-t * 0.2, t * 0.15));
        col = vec3(0.02, 0.02, 0.05) + vec3(0.04, 0.04, 0.08) * clouds;

        // Dimmer rain
        float r = rain(uv, t * 0.8);
        col += vec3(0.2, 0.25, 0.4) * r * 0.6;

        // Lightning bolt — aperiodic, wraps every 80s so it never stops
        float tBolt = mod(iTime, 80.0);
        float boltId = 0.0;
        float accum = 0.0;
        for (float i = 0.0; i < 40.0; i++) {
            float interval = 1.5 + hash1(i * 7.7) * 0.7;
            if (accum + interval > tBolt) break;
            accum += interval;
            boltId = i;
        }
        float boltPhase = (tBolt - accum) / (1.5 + hash1(boltId * 7.7) * 0.7);
        float shouldBolt = 1.0;

        if (shouldBolt > 0.5) {
            // Bolt visible for brief moment
            float boltFade = smoothstep(0.0, 0.01, boltPhase) * smoothstep(0.12, 0.03, boltPhase);
            float b = bolt(uv, boltId);
            col += vec3(0.6, 0.65, 1.0) * b * boltFade;

            // Atmospheric flash — illuminates clouds
            float flash = smoothstep(0.0, 0.02, boltPhase) * smoothstep(0.15, 0.02, boltPhase);
            col += vec3(0.12, 0.12, 0.2) * flash * clouds2;

            // Second smaller bolt sometimes
            float shouldSecond = step(0.5, hash1(boltId * 3.1));
            if (shouldSecond > 0.5) {
                float secondFade = smoothstep(0.18, 0.19, boltPhase) * smoothstep(0.28, 0.2, boltPhase) * 0.5;
                float b2 = bolt(uv, boltId + 100.0);
                col += vec3(0.4, 0.45, 0.8) * b2 * secondFade;
            }
        }

        alpha = 0.35;
    }

    fragColor = vec4(col * vig, alpha * vig) * qt_Opacity;
}
