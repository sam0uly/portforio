---
title: Dither Footer
category: Effects
order: 7
preview: dither-footer
summary: Interactive WebGL ordered Bayer dither wave with live cursor disturbance, click ripples, and theme morphing.
tags:
  - WebGL
  - GLSL
  - Bayer
---

The signature interactive WebGL Bayer-dither footer from this portfolio. Uses domain-warped FBM noise quantized through an 8×8 Bayer threshold matrix, with magnetic pointer disturbance, up to **4 concurrent click-to-ripple waves**, an intro rise animation, and full Dark/Light palette adaptation.

::framework{name="vue"}
### Usage
```vue [PageFooter.vue]
<script setup lang="ts">
import { ref } from 'vue';
import DitherFooter from './DitherFooter.vue';

const footerRef = ref<InstanceType<typeof DitherFooter> | null>(null);
const playing = ref(true);
const speed = ref(1);
const theme = ref<'dark' | 'light'>('dark');
</script>

<template>
  <div class="space-y-3">
    <div class="flex flex-wrap items-center gap-2 font-mono text-xs">
      <button type="button" @click="playing = !playing">{{ playing ? 'Pause' : 'Play' }}</button>
      <button type="button" @click="speed = speed === 2 ? 0.5 : speed * 2">{{ speed }}x</button>
      <button type="button" @click="theme = theme === 'dark' ? 'light' : 'dark'">{{ theme }}</button>
      <button type="button" @click="footerRef?.spawnRipple()">Ripple</button>
      <button type="button" @click="footerRef?.replayIntro()">Replay intro</button>
    </div>
    <DitherFooter
      ref="footerRef"
      :playing="playing"
      :speed="speed"
      :theme="theme"
      class="h-36 rounded-[14px]"
    />
  </div>
</template>
```

### Source
```vue [DitherFooter.vue]
<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue';

interface Props {
  playing?: boolean;
  speed?: number;
  theme?: 'dark' | 'light';
}

const props = withDefaults(defineProps<Props>(), {
  playing: true,
  speed: 1,
  theme: 'dark',
});

interface Ripple {
  x: number;
  y: number;
  age: number;
}

const RIPPLE_DURATION = 2.1;
const VERTEX_SHADER = `
attribute vec2 position;
varying vec2 vUv;
void main() {
  vUv = position * 0.5 + 0.5;
  gl_Position = vec4(position, 0.0, 1.0);
}`;

const FRAGMENT_SHADER = `
precision highp float;

varying vec2 vUv;

uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uMouse;
uniform float uPresence;
uniform vec3 uRipple0;
uniform vec3 uRipple1;
uniform vec3 uRipple2;
uniform vec3 uRipple3;
uniform float uIsLight;
uniform float uIntro;

vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec2 fade(vec2 t) { return t * t * t * (t * (t * 6.0 - 15.0) + 10.0); }

float cnoise(vec2 P) {
  vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
  vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
  Pi = mod289(Pi);
  vec4 ix = Pi.xzxz;
  vec4 iy = Pi.yyww;
  vec4 fx = Pf.xzxz;
  vec4 fy = Pf.yyww;
  vec4 i = permute(permute(ix) + iy);
  vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0;
  vec4 gy = abs(gx) - 0.5;
  vec4 tx = floor(gx + 0.5);
  gx = gx - tx;
  vec2 g00 = vec2(gx.x, gy.x);
  vec2 g10 = vec2(gx.y, gy.y);
  vec2 g01 = vec2(gx.z, gy.z);
  vec2 g11 = vec2(gx.w, gy.w);
  vec4 norm = taylorInvSqrt(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
  g00 *= norm.x; g01 *= norm.y; g10 *= norm.z; g11 *= norm.w;
  float n00 = dot(g00, vec2(fx.x, fy.x));
  float n10 = dot(g10, vec2(fx.y, fy.y));
  float n01 = dot(g01, vec2(fx.z, fy.z));
  float n11 = dot(g11, vec2(fx.w, fy.w));
  vec2 fade_xy = fade(Pf.xy);
  vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
  return 2.3 * mix(n_x.x, n_x.y, fade_xy.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amp = 0.55;
  for (int i = 0; i < 4; i++) {
    value += amp * cnoise(p);
    p = p * 2.02 + vec2(3.1, 1.7);
    amp *= 0.5;
  }
  return value;
}

float bayer2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer2(a); }

vec3 paletteSample(float t, vec3 bg) {
  vec3 c1 = vec3(0.169, 0.333, 0.702);
  vec3 c2 = vec3(0.545, 0.459, 1.000);
  vec3 c3 = vec3(1.000, 0.310, 0.749);
  vec3 c4 = vec3(1.000, 0.596, 0.353);
  vec3 c5 = vec3(0.361, 0.875, 0.918);
  vec3 c6 = vec3(0.071, 0.780, 0.561);
  float s = clamp(t, 0.0, 1.0) * 6.0;
  if (s < 1.0) return mix(bg, c1, s);
  if (s < 2.0) return mix(c1, c2, s - 1.0);
  if (s < 3.0) return mix(c2, c3, s - 2.0);
  if (s < 4.0) return mix(c3, c4, s - 3.0);
  if (s < 5.0) return mix(c4, c5, s - 4.0);
  return mix(c5, c6, s - 5.0);
}

void applyRipple(
  vec3 rip, vec2 uv, vec2 aspectUv, float aspect, float vScale,
  inout vec2 totalWarp, inout float totalBoost, inout float totalCrest
) {
  float age = rip.z;
  if (age < 0.0 || age >= 2.1) return;
  float ry = rip.y * vScale;
  vec2 aspectRipple = vec2((rip.x - 0.5) * aspect, ry - 0.5);
  vec2 rDiff = aspectUv - aspectRipple;
  float rDist = length(rDiff);
  float life = age / 2.1;
  float fadeOut = (1.0 - life) * (1.0 - life);
  float travel = age * 1.45;
  float broadEnv = exp(-pow((rDist - travel) / 0.46, 2.0)) * fadeOut;
  float waveTrain = sin((rDist - travel) * 14.0);
  totalWarp += normalize(rDiff + 0.0001) * waveTrain * broadEnv * 0.14;
  totalBoost += (0.35 + 0.65 * max(0.0, waveTrain)) * broadEnv * 0.46;
  float hx = abs(uv.x - rip.x);
  float hTravel = age * 0.42;
  float hEnv = exp(-pow((hx - hTravel) / 0.22, 2.0)) * fadeOut;
  totalCrest += sin((hx - hTravel) * 24.0) * hEnv * 0.22;
}

void main() {
  vec2 cell = floor(gl_FragCoord.xy);
  vec2 uv = (cell + 0.5) / uResolution;
  float vScale = 210.0 / 148.0;
  float vy = uv.y * vScale;
  float my = uMouse.y * vScale;
  float aspect = 800.0 / 148.0;

  vec2 aspectUv = vec2((uv.x - 0.5) * aspect, vy - 0.5);
  vec2 aspectMouse = vec2((uMouse.x - 0.5) * aspect, my - 0.5);
  vec2 diff = aspectUv - aspectMouse;
  float dist = length(diff);

  float cAngle = atan(diff.y, diff.x);
  float shapeWobble = 0.028 * sin(cAngle * 3.0 + uTime * 1.1)
    + 0.018 * cos(cAngle * 5.0 - uTime * 0.85)
    + 0.036 * cnoise(vec2(uv.x * 7.5 + uTime * 0.35, vy * 6.0));
  float organicDist = max(0.0, dist + shapeWobble);
  float radialFalloff = clamp(1.0 - organicDist / 0.42, 0.0, 1.0);
  float touch = uPresence * pow(radialFalloff, 1.35);
  float fieldReach = uPresence * (1.0 - smoothstep(0.0, 0.96, dist));

  vec2 attract = -diff * fieldReach * 0.42;
  vec2 swirl = vec2(-diff.y, diff.x) * touch * 0.24;
  vec2 push = normalize(diff + 0.0001) * sin(dist * 18.0 - uTime * 4.5) * 0.014 * touch;

  vec2 rippleWarp = vec2(0.0);
  float rippleBoost = 0.0;
  float rippleCrestDisp = 0.0;
  applyRipple(uRipple0, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
  applyRipple(uRipple1, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
  applyRipple(uRipple2, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
  applyRipple(uRipple3, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);

  vec2 p = vec2(uv.x * 2.6, vy * 1.45) + attract + swirl + push + rippleWarp;
  vec2 q = vec2(fbm(p + vec2(uTime * 0.08, 0.0)), fbm(p + vec2(5.2, 1.3 - uTime * 0.06)));
  vec2 r = vec2(fbm(p + 1.65 * q + vec2(1.7, 9.2 + uTime * 0.05)), fbm(p + 1.65 * q + vec2(8.3, 2.8 - uTime * 0.04)));
  float f = fbm(p + 1.4 * r);

  float horizPull = exp(-pow((uv.x - uMouse.x) * 5.9, 2.0));
  float vertProximity = smoothstep(1.50, 0.12, my);
  float magneticLift = uPresence * horizPull * vertProximity * clamp(my - 0.14, 0.0, 0.78) * 1.15;

  float crestHeight = 0.44 + 0.18 * sin(uv.x * 4.8 + uTime * 0.3) + 0.12 * q.x
    + 0.09 * cos(uv.x * 9.5 - uTime * 0.2) + magneticLift + rippleCrestDisp;
  float waveMask = 1.0 - smoothstep(crestHeight - 0.22, crestHeight + 0.24, vy);

  float introEase = 1.0 - pow(1.0 - clamp(uIntro, 0.0, 1.0), 3.0);
  float introRise = smoothstep(introEase * 1.45, introEase * 1.45 - 0.55, vy);

  float cursorMix = touch * (0.72 + 0.24 * abs(f));
  float intensity = clamp((waveMask * (0.58 + 0.68 * abs(f)) + cursorMix + rippleBoost) * introRise * introEase, 0.0, 1.0);
  float colorCoord = clamp(0.16 + 0.72 * (0.5 + 0.5 * f) + 0.22 * uv.x + 0.16 * r.y + touch * 0.08 + rippleBoost * 0.35, 0.0, 1.0);
  float contour = smoothstep(0.08, 0.0, abs(fract(f * 3.8 + q.y * 0.6) - 0.5));

  vec3 bg = mix(vec3(0.0196), vec3(0.961, 0.957, 0.941), uIsLight);
  vec3 ribbonColor = paletteSample(colorCoord, bg);
  ribbonColor = mix(ribbonColor, vec3(1.0, 0.98, 0.945), contour * 0.28 * (1.0 - uIsLight));

  float threshold = bayer8(cell);
  float density = floor(intensity * 5.0 + threshold) / 5.0;
  if (density <= 0.02) {
    gl_FragColor = vec4(0.0);
  } else {
    vec3 raw = mix(bg, ribbonColor, clamp(density, 0.0, 1.0));
    vec3 quantized = clamp(floor(raw * 6.0 + (threshold - 0.5)) / 6.0, 0.0, 1.0);
    float a = smoothstep(0.02, 0.32, density);
    gl_FragColor = vec4(quantized * a, a);
  }
}`;

const canvasRef = ref<HTMLCanvasElement | null>(null);
const state = {
  time: 0,
  intro: 0,
  targetX: 0.5,
  targetY: 0.35,
  smoothX: 0.5,
  smoothY: 0.35,
  hovering: false,
  presence: 0,
  ripples: [] as Ripple[],
};
let raf = 0;

function spawnRipple(x = 0.5, y = 0.34) {
  state.ripples = [{ x, y, age: 0 }, ...state.ripples.slice(0, 3)];
}

function replayIntro() {
  state.intro = 0;
}

defineExpose({ spawnRipple, replayIntro });

function toNorm(e: PointerEvent): [number, number] {
  const el = canvasRef.value;
  if (!el) return [0.5, 0.35];
  const rect = el.getBoundingClientRect();
  const nx = Math.max(0, Math.min(1, (e.clientX - rect.left) / Math.max(1, rect.width)));
  const ny = Math.max(0, Math.min(1, 1 - (e.clientY - rect.top) / Math.max(1, rect.height)));
  return [nx, ny];
}

function onPointerMove(e: PointerEvent) {
  const [nx, ny] = toNorm(e);
  state.targetX = nx;
  state.targetY = ny;
  state.hovering = true;
}

function onPointerDown(e: PointerEvent) {
  const [nx, ny] = toNorm(e);
  state.targetX = nx;
  state.targetY = ny;
  state.hovering = true;
  spawnRipple(nx, ny);
}

function onPointerLeave() {
  state.hovering = false;
}

function onPointerUp(e: PointerEvent) {
  if (e.pointerType === 'touch') state.hovering = false;
}

onMounted(() => {
  const canvas = canvasRef.value;
  const gl = canvas?.getContext('webgl', { alpha: true });
  if (!canvas || !gl) return;

  const compile = (type: number, src: string) => {
    const sh = gl.createShader(type)!;
    gl.shaderSource(sh, src);
    gl.compileShader(sh);
    return sh;
  };
  const prog = gl.createProgram()!;
  gl.attachShader(prog, compile(gl.VERTEX_SHADER, VERTEX_SHADER));
  gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, FRAGMENT_SHADER));
  gl.linkProgram(prog);

  const buf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  const posLoc = gl.getAttribLocation(prog, 'position');
  gl.enableVertexAttribArray(posLoc);
  gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);

  const uTime = gl.getUniformLocation(prog, 'uTime');
  const uRes = gl.getUniformLocation(prog, 'uResolution');
  const uMouse = gl.getUniformLocation(prog, 'uMouse');
  const uPresence = gl.getUniformLocation(prog, 'uPresence');
  const uRipples = [0, 1, 2, 3].map((i) => gl.getUniformLocation(prog, `uRipple${i}`));
  const uIsLight = gl.getUniformLocation(prog, 'uIsLight');
  const uIntro = gl.getUniformLocation(prog, 'uIntro');

  let last = performance.now();
  const loop = (now: number) => {
    const dt = Math.min(0.05, (now - last) / 1000) * Math.max(0.1, props.speed);
    last = now;

    const follow = 1 - Math.exp(-dt / 0.045);
    state.smoothX += (state.targetX - state.smoothX) * follow;
    state.smoothY += (state.targetY - state.smoothY) * follow;

    const targetPres = state.hovering ? 1 : 0;
    const presRate = 1 - Math.exp(-dt / (state.hovering ? 0.12 : 0.35));
    state.presence += (targetPres - state.presence) * presRate;
    if (state.presence < 0.002 && !state.hovering) state.presence = 0;

    state.ripples = state.ripples
      .map((r) => ({ ...r, age: r.age + dt }))
      .filter((r) => r.age < RIPPLE_DURATION);

    if (props.playing) state.time += dt;
    state.intro = Math.min(1, state.intro + dt / 1.14);

    gl.viewport(0, 0, 400, 105);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(prog);
    gl.uniform1f(uTime, state.time);
    gl.uniform2f(uRes, 400, 105);
    gl.uniform2f(uMouse, state.smoothX, state.smoothY);
    gl.uniform1f(uPresence, state.presence);
    gl.uniform1f(uIsLight, props.theme === 'light' ? 1 : 0);
    gl.uniform1f(uIntro, state.intro);

    for (let i = 0; i < 4; i++) {
      const r = state.ripples[i];
      gl.uniform3f(uRipples[i], r ? r.x : 0.5, r ? r.y : 0.5, r ? r.age : -1);
    }

    gl.drawArrays(gl.TRIANGLES, 0, 3);
    raf = requestAnimationFrame(loop);
  };
  raf = requestAnimationFrame(loop);
});

onBeforeUnmount(() => cancelAnimationFrame(raf));
</script>

<template>
  <canvas
    ref="canvasRef"
    width="400"
    height="105"
    role="img"
    aria-label="Interactive Bayer-dithered generative wave"
    class="block w-full object-cover object-bottom cursor-crosshair select-none touch-none"
    style="image-rendering: pixelated"
    @pointermove="onPointerMove"
    @pointerdown="onPointerDown"
    @pointerleave="onPointerLeave"
    @pointerup="onPointerUp"
    @pointercancel="onPointerLeave"
  />
</template>
```
::

::framework{name="react"}
### Usage
```tsx [PageFooter.tsx]
import { useRef, useState } from 'react';
import { DitherFooter, type DitherFooterHandle } from './DitherFooter';

export function PageFooter() {
  const ref = useRef<DitherFooterHandle>(null);
  const [playing, setPlaying] = useState(true);
  const [speed, setSpeed] = useState(1);
  const [theme, setTheme] = useState<'dark' | 'light'>('dark');

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-2 font-mono text-xs">
        <button type="button" onClick={() => setPlaying((p) => !p)}>{playing ? 'Pause' : 'Play'}</button>
        <button type="button" onClick={() => setSpeed((s) => (s === 2 ? 0.5 : s * 2))}>{speed}x</button>
        <button type="button" onClick={() => setTheme((t) => (t === 'dark' ? 'light' : 'dark'))}>{theme}</button>
        <button type="button" onClick={() => ref.current?.spawnRipple()}>Ripple</button>
        <button type="button" onClick={() => ref.current?.replayIntro()}>Replay intro</button>
      </div>
      <DitherFooter
        ref={ref}
        playing={playing}
        speed={speed}
        theme={theme}
        className="h-36 rounded-[14px]"
      />
    </div>
  );
}
```

### Source
```tsx [DitherFooter.tsx]
import { forwardRef, useEffect, useImperativeHandle, useRef } from 'react';

export interface DitherFooterHandle {
  spawnRipple: (x?: number, y?: number) => void;
  replayIntro: () => void;
}

export interface DitherFooterProps {
  playing?: boolean;
  speed?: number;
  theme?: 'dark' | 'light';
  className?: string;
}

interface Ripple {
  x: number;
  y: number;
  age: number;
}

const RIPPLE_DURATION = 2.1;
const VERTEX_SHADER = `
attribute vec2 position;
varying vec2 vUv;
void main() {
  vUv = position * 0.5 + 0.5;
  gl_Position = vec4(position, 0.0, 1.0);
}`;

const FRAGMENT_SHADER = `
precision highp float;

varying vec2 vUv;

uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uMouse;
uniform float uPresence;
uniform vec3 uRipple0;
uniform vec3 uRipple1;
uniform vec3 uRipple2;
uniform vec3 uRipple3;
uniform float uIsLight;
uniform float uIntro;

vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec2 fade(vec2 t) { return t * t * t * (t * (t * 6.0 - 15.0) + 10.0); }

float cnoise(vec2 P) {
  vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
  vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
  Pi = mod289(Pi);
  vec4 ix = Pi.xzxz;
  vec4 iy = Pi.yyww;
  vec4 fx = Pf.xzxz;
  vec4 fy = Pf.yyww;
  vec4 i = permute(permute(ix) + iy);
  vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0;
  vec4 gy = abs(gx) - 0.5;
  vec4 tx = floor(gx + 0.5);
  gx = gx - tx;
  vec2 g00 = vec2(gx.x, gy.x);
  vec2 g10 = vec2(gx.y, gy.y);
  vec2 g01 = vec2(gx.z, gy.z);
  vec2 g11 = vec2(gx.w, gy.w);
  vec4 norm = taylorInvSqrt(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
  g00 *= norm.x; g01 *= norm.y; g10 *= norm.z; g11 *= norm.w;
  float n00 = dot(g00, vec2(fx.x, fy.x));
  float n10 = dot(g10, vec2(fx.y, fy.y));
  float n01 = dot(g01, vec2(fx.z, fy.z));
  float n11 = dot(g11, vec2(fx.w, fy.w));
  vec2 fade_xy = fade(Pf.xy);
  vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
  return 2.3 * mix(n_x.x, n_x.y, fade_xy.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amp = 0.55;
  for (int i = 0; i < 4; i++) {
    value += amp * cnoise(p);
    p = p * 2.02 + vec2(3.1, 1.7);
    amp *= 0.5;
  }
  return value;
}

float bayer2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer2(a); }

vec3 paletteSample(float t, vec3 bg) {
  vec3 c1 = vec3(0.169, 0.333, 0.702);
  vec3 c2 = vec3(0.545, 0.459, 1.000);
  vec3 c3 = vec3(1.000, 0.310, 0.749);
  vec3 c4 = vec3(1.000, 0.596, 0.353);
  vec3 c5 = vec3(0.361, 0.875, 0.918);
  vec3 c6 = vec3(0.071, 0.780, 0.561);
  float s = clamp(t, 0.0, 1.0) * 6.0;
  if (s < 1.0) return mix(bg, c1, s);
  if (s < 2.0) return mix(c1, c2, s - 1.0);
  if (s < 3.0) return mix(c2, c3, s - 2.0);
  if (s < 4.0) return mix(c3, c4, s - 3.0);
  if (s < 5.0) return mix(c4, c5, s - 4.0);
  return mix(c5, c6, s - 5.0);
}

void applyRipple(
  vec3 rip, vec2 uv, vec2 aspectUv, float aspect, float vScale,
  inout vec2 totalWarp, inout float totalBoost, inout float totalCrest
) {
  float age = rip.z;
  if (age < 0.0 || age >= 2.1) return;
  float ry = rip.y * vScale;
  vec2 aspectRipple = vec2((rip.x - 0.5) * aspect, ry - 0.5);
  vec2 rDiff = aspectUv - aspectRipple;
  float rDist = length(rDiff);
  float life = age / 2.1;
  float fadeOut = (1.0 - life) * (1.0 - life);
  float travel = age * 1.45;
  float broadEnv = exp(-pow((rDist - travel) / 0.46, 2.0)) * fadeOut;
  float waveTrain = sin((rDist - travel) * 14.0);
  totalWarp += normalize(rDiff + 0.0001) * waveTrain * broadEnv * 0.14;
  totalBoost += (0.35 + 0.65 * max(0.0, waveTrain)) * broadEnv * 0.46;
  float hx = abs(uv.x - rip.x);
  float hTravel = age * 0.42;
  float hEnv = exp(-pow((hx - hTravel) / 0.22, 2.0)) * fadeOut;
  totalCrest += sin((hx - hTravel) * 24.0) * hEnv * 0.22;
}

void main() {
  vec2 cell = floor(gl_FragCoord.xy);
  vec2 uv = (cell + 0.5) / uResolution;
  float vScale = 210.0 / 148.0;
  float vy = uv.y * vScale;
  float my = uMouse.y * vScale;
  float aspect = 800.0 / 148.0;

  vec2 aspectUv = vec2((uv.x - 0.5) * aspect, vy - 0.5);
  vec2 aspectMouse = vec2((uMouse.x - 0.5) * aspect, my - 0.5);
  vec2 diff = aspectUv - aspectMouse;
  float dist = length(diff);

  float cAngle = atan(diff.y, diff.x);
  float shapeWobble = 0.028 * sin(cAngle * 3.0 + uTime * 1.1)
    + 0.018 * cos(cAngle * 5.0 - uTime * 0.85)
    + 0.036 * cnoise(vec2(uv.x * 7.5 + uTime * 0.35, vy * 6.0));
  float organicDist = max(0.0, dist + shapeWobble);
  float radialFalloff = clamp(1.0 - organicDist / 0.42, 0.0, 1.0);
  float touch = uPresence * pow(radialFalloff, 1.35);
  float fieldReach = uPresence * (1.0 - smoothstep(0.0, 0.96, dist));

  vec2 attract = -diff * fieldReach * 0.42;
  vec2 swirl = vec2(-diff.y, diff.x) * touch * 0.24;
  vec2 push = normalize(diff + 0.0001) * sin(dist * 18.0 - uTime * 4.5) * 0.014 * touch;

  vec2 rippleWarp = vec2(0.0);
  float rippleBoost = 0.0;
  float rippleCrestDisp = 0.0;
  applyRipple(uRipple0, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
  applyRipple(uRipple1, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
  applyRipple(uRipple2, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
  applyRipple(uRipple3, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);

  vec2 p = vec2(uv.x * 2.6, vy * 1.45) + attract + swirl + push + rippleWarp;
  vec2 q = vec2(fbm(p + vec2(uTime * 0.08, 0.0)), fbm(p + vec2(5.2, 1.3 - uTime * 0.06)));
  vec2 r = vec2(fbm(p + 1.65 * q + vec2(1.7, 9.2 + uTime * 0.05)), fbm(p + 1.65 * q + vec2(8.3, 2.8 - uTime * 0.04)));
  float f = fbm(p + 1.4 * r);

  float horizPull = exp(-pow((uv.x - uMouse.x) * 5.9, 2.0));
  float vertProximity = smoothstep(1.50, 0.12, my);
  float magneticLift = uPresence * horizPull * vertProximity * clamp(my - 0.14, 0.0, 0.78) * 1.15;

  float crestHeight = 0.44 + 0.18 * sin(uv.x * 4.8 + uTime * 0.3) + 0.12 * q.x
    + 0.09 * cos(uv.x * 9.5 - uTime * 0.2) + magneticLift + rippleCrestDisp;
  float waveMask = 1.0 - smoothstep(crestHeight - 0.22, crestHeight + 0.24, vy);

  float introEase = 1.0 - pow(1.0 - clamp(uIntro, 0.0, 1.0), 3.0);
  float introRise = smoothstep(introEase * 1.45, introEase * 1.45 - 0.55, vy);

  float cursorMix = touch * (0.72 + 0.24 * abs(f));
  float intensity = clamp((waveMask * (0.58 + 0.68 * abs(f)) + cursorMix + rippleBoost) * introRise * introEase, 0.0, 1.0);
  float colorCoord = clamp(0.16 + 0.72 * (0.5 + 0.5 * f) + 0.22 * uv.x + 0.16 * r.y + touch * 0.08 + rippleBoost * 0.35, 0.0, 1.0);
  float contour = smoothstep(0.08, 0.0, abs(fract(f * 3.8 + q.y * 0.6) - 0.5));

  vec3 bg = mix(vec3(0.0196), vec3(0.961, 0.957, 0.941), uIsLight);
  vec3 ribbonColor = paletteSample(colorCoord, bg);
  ribbonColor = mix(ribbonColor, vec3(1.0, 0.98, 0.945), contour * 0.28 * (1.0 - uIsLight));

  float threshold = bayer8(cell);
  float density = floor(intensity * 5.0 + threshold) / 5.0;
  if (density <= 0.02) {
    gl_FragColor = vec4(0.0);
  } else {
    vec3 raw = mix(bg, ribbonColor, clamp(density, 0.0, 1.0));
    vec3 quantized = clamp(floor(raw * 6.0 + (threshold - 0.5)) / 6.0, 0.0, 1.0);
    float a = smoothstep(0.02, 0.32, density);
    gl_FragColor = vec4(quantized * a, a);
  }
}`;

export const DitherFooter = forwardRef<DitherFooterHandle, DitherFooterProps>(
  function DitherFooter({ playing = true, speed = 1, theme = 'dark', className = 'h-36 rounded-[14px]' }, ref) {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const propsRef = useRef({ playing, speed, theme });
    propsRef.current = { playing, speed, theme };

    const stateRef = useRef({
      time: 0,
      intro: 0,
      targetX: 0.5,
      targetY: 0.35,
      smoothX: 0.5,
      smoothY: 0.35,
      hovering: false,
      presence: 0,
      ripples: [] as Ripple[],
    });

    useImperativeHandle(ref, () => ({
      spawnRipple(x = 0.5, y = 0.34) {
        stateRef.current.ripples = [{ x, y, age: 0 }, ...stateRef.current.ripples.slice(0, 3)];
      },
      replayIntro() {
        stateRef.current.intro = 0;
      },
    }));

    useEffect(() => {
      const canvas = canvasRef.current;
      const gl = canvas?.getContext('webgl', { alpha: true });
      if (!canvas || !gl) return;

      const compile = (type: number, src: string) => {
        const sh = gl.createShader(type)!;
        gl.shaderSource(sh, src);
        gl.compileShader(sh);
        return sh;
      };
      const prog = gl.createProgram()!;
      gl.attachShader(prog, compile(gl.VERTEX_SHADER, VERTEX_SHADER));
      gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, FRAGMENT_SHADER));
      gl.linkProgram(prog);

      const buf = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
      const posLoc = gl.getAttribLocation(prog, 'position');
      gl.enableVertexAttribArray(posLoc);
      gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);

      const uTime = gl.getUniformLocation(prog, 'uTime');
      const uRes = gl.getUniformLocation(prog, 'uResolution');
      const uMouse = gl.getUniformLocation(prog, 'uMouse');
      const uPresence = gl.getUniformLocation(prog, 'uPresence');
      const uRipples = [0, 1, 2, 3].map((i) => gl.getUniformLocation(prog, `uRipple${i}`));
      const uIsLight = gl.getUniformLocation(prog, 'uIsLight');
      const uIntro = gl.getUniformLocation(prog, 'uIntro');

      let raf = 0;
      let last = performance.now();
      const loop = (now: number) => {
        const st = stateRef.current;
        const cfg = propsRef.current;
        const dt = Math.min(0.05, (now - last) / 1000) * Math.max(0.1, cfg.speed);
        last = now;

        const follow = 1 - Math.exp(-dt / 0.045);
        st.smoothX += (st.targetX - st.smoothX) * follow;
        st.smoothY += (st.targetY - st.smoothY) * follow;

        const targetPres = st.hovering ? 1 : 0;
        const presRate = 1 - Math.exp(-dt / (st.hovering ? 0.12 : 0.35));
        st.presence += (targetPres - st.presence) * presRate;
        if (st.presence < 0.002 && !st.hovering) st.presence = 0;

        st.ripples = st.ripples
          .map((r) => ({ ...r, age: r.age + dt }))
          .filter((r) => r.age < RIPPLE_DURATION);

        if (cfg.playing) st.time += dt;
        st.intro = Math.min(1, st.intro + dt / 1.14);

        gl.viewport(0, 0, 400, 105);
        gl.clearColor(0, 0, 0, 0);
        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.useProgram(prog);
        gl.uniform1f(uTime, st.time);
        gl.uniform2f(uRes, 400, 105);
        gl.uniform2f(uMouse, st.smoothX, st.smoothY);
        gl.uniform1f(uPresence, st.presence);
        gl.uniform1f(uIsLight, cfg.theme === 'light' ? 1 : 0);
        gl.uniform1f(uIntro, st.intro);

        for (let i = 0; i < 4; i++) {
          const r = st.ripples[i];
          gl.uniform3f(uRipples[i], r ? r.x : 0.5, r ? r.y : 0.5, r ? r.age : -1);
        }

        gl.drawArrays(gl.TRIANGLES, 0, 3);
        raf = requestAnimationFrame(loop);
      };
      raf = requestAnimationFrame(loop);
      return () => cancelAnimationFrame(raf);
    }, []);

    const toNorm = (e: React.PointerEvent<HTMLCanvasElement>): [number, number] => {
      const rect = e.currentTarget.getBoundingClientRect();
      return [
        Math.max(0, Math.min(1, (e.clientX - rect.left) / Math.max(1, rect.width))),
        Math.max(0, Math.min(1, 1 - (e.clientY - rect.top) / Math.max(1, rect.height))),
      ];
    };

    return (
      <canvas
        ref={canvasRef}
        width={400}
        height={105}
        role="img"
        aria-label="Interactive Bayer-dithered generative wave"
        className={`block w-full object-cover object-bottom cursor-crosshair select-none touch-none ${className}`}
        style={{ imageRendering: 'pixelated' }}
        onPointerMove={(e) => {
          const [nx, ny] = toNorm(e);
          stateRef.current.targetX = nx;
          stateRef.current.targetY = ny;
          stateRef.current.hovering = true;
        }}
        onPointerDown={(e) => {
          const [nx, ny] = toNorm(e);
          stateRef.current.targetX = nx;
          stateRef.current.targetY = ny;
          stateRef.current.hovering = true;
          stateRef.current.ripples = [{ x: nx, y: ny, age: 0 }, ...stateRef.current.ripples.slice(0, 3)];
        }}
        onPointerLeave={() => {
          stateRef.current.hovering = false;
        }}
        onPointerUp={(e) => {
          if (e.pointerType === 'touch') stateRef.current.hovering = false;
        }}
        onPointerCancel={() => {
          stateRef.current.hovering = false;
        }}
      />
    );
  }
);
```
::

::framework{name="elm"}
### Usage
```elm [Main.elm]
import Browser.Events
import Effects.DitherFooter as DitherFooter

-- In init:
--   footer = DitherFooter.init prefersReducedMotion
--
-- In subscriptions:
--   Browser.Events.onAnimationFrameDelta FrameDelta
--
-- In update:
--   FrameDelta dt -> { model | footer = DitherFooter.tick model.playing dt model.footer }
--   FooterMsg sub -> { model | footer = DitherFooter.update sub model.footer }
--   SpawnRipple -> { model | footer = DitherFooter.spawnRipple 0.5 0.34 model.footer }
--   ReplayIntro -> { model | footer = DitherFooter.replayIntro model.footer }

viewFooter : Bool -> DitherFooter.Model -> Html Msg
viewFooter isLight footerModel =
    DitherFooter.view isLight footerModel
        |> Html.map FooterMsg
```

### Source
```elm [Effects/DitherFooter.elm]
module Effects.DitherFooter exposing
    ( Model
    , Msg
    , activeRippleCount
    , init
    , isAnimating
    , replayIntro
    , spawnRipple
    , tick
    , update
    , view
    , viewSized
    )

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import WebGL exposing (Mesh, Shader)


type alias Ripple =
    { x : Float
    , y : Float
    , age : Float
    }


type alias Model =
    { time : Float
    , intro : Float
    , targetMouse : ( Float, Float )
    , smoothMouse : ( Float, Float )
    , hovering : Bool
    , presence : Float
    , ripples : List Ripple
    }


type Msg
    = PointerMove Float Float
    | PointerLeave
    | PointerDown Float Float


rippleDuration : Float
rippleDuration =
    2.1


init : Bool -> Model
init prefersReduced =
    { time = 0
    , intro =
        if prefersReduced then
            1.0

        else
            0.0
    , targetMouse = ( 0.5, 0.35 )
    , smoothMouse = ( 0.5, 0.35 )
    , hovering = False
    , presence = 0
    , ripples = []
    }


isAnimating : Model -> Bool
isAnimating model =
    model.intro
        < 1.0
        || model.hovering
        || model.presence
        > 0.005
        || not (List.isEmpty model.ripples)


activeRippleCount : Model -> Int
activeRippleCount model =
    List.length model.ripples


replayIntro : Model -> Model
replayIntro model =
    { model | intro = 0.0 }


spawnRipple : Float -> Float -> Model -> Model
spawnRipple nx ny model =
    let
        fresh =
            { x = clamp 0 1 nx, y = clamp 0 1 ny, age = 0.0 }
    in
    { model | ripples = fresh :: List.take 3 model.ripples }


update : Msg -> Model -> Model
update msg model =
    case msg of
        PointerMove nx ny ->
            { model
                | targetMouse = ( nx, ny )
                , hovering = True
            }

        PointerLeave ->
            { model | hovering = False }

        PointerDown nx ny ->
            let
                fresh =
                    { x = nx, y = ny, age = 0.0 }

                nextRipples =
                    fresh :: List.take 3 model.ripples
            in
            { model
                | targetMouse = ( nx, ny )
                , hovering = True
                , ripples = nextRipples
            }


tick : Bool -> Float -> Model -> Model
tick motionEnabled dtMs model =
    let
        dt =
            min 0.05 (dtMs / 1000)

        ( tx, ty ) =
            model.targetMouse

        ( sx, sy ) =
            model.smoothMouse

        follow =
            1 - e ^ (-dt / 0.045)

        nextSmooth =
            ( sx + (tx - sx) * follow
            , sy + (ty - sy) * follow
            )

        targetPresence =
            if model.hovering then
                1

            else
                0

        presenceRate =
            if model.hovering then
                1 - e ^ (-dt / 0.12)

            else
                1 - e ^ (-dt / 0.35)

        nextPresence =
            model.presence + (targetPresence - model.presence) * presenceRate

        nextRipples =
            model.ripples
                |> List.map (\r -> { r | age = r.age + dt })
                |> List.filter (\r -> r.age < rippleDuration)

        nextTime =
            if motionEnabled then
                model.time + dt

            else
                model.time

        nextIntro =
            min 1.0 (model.intro + dt / 1.14)
    in
    { model
        | time = nextTime
        , intro = nextIntro
        , smoothMouse = nextSmooth
        , presence =
            if nextPresence < 0.002 && not model.hovering then
                0

            else
                nextPresence
        , ripples = nextRipples
    }


pointerDecoder : (Float -> Float -> Msg) -> Decode.Decoder Msg
pointerDecoder toMsg =
    Decode.map4
        (\ox oy cw ch ->
            let
                w =
                    max 1 cw

                h =
                    max 1 ch

                nx =
                    clamp 0 1 (ox / w)

                ny =
                    clamp 0 1 (1 - (oy / h))
            in
            toMsg nx ny
        )
        (Decode.field "offsetX" Decode.float)
        (Decode.field "offsetY" Decode.float)
        (Decode.at [ "currentTarget", "clientWidth" ] Decode.float)
        (Decode.at [ "currentTarget", "clientHeight" ] Decode.float)


touchEndDecoder : Decode.Decoder Msg
touchEndDecoder =
    Decode.field "pointerType" Decode.string
        |> Decode.andThen
            (\kind ->
                if kind == "touch" then
                    Decode.succeed PointerLeave

                else
                    Decode.fail "keep mouse hover"
            )


rippleAt : Int -> List Ripple -> Vec3
rippleAt index list =
    case List.drop index list |> List.head of
        Just r ->
            vec3 r.x r.y r.age

        Nothing ->
            vec3 0.5 0.5 -1.0


view : Bool -> Model -> Html Msg
view isLight model =
    viewSized "block w-full h-32 sm:h-auto aspect-[800/210] object-cover object-bottom cursor-crosshair select-none touch-none" isLight model


viewSized : String -> Bool -> Model -> Html Msg
viewSized canvasClass isLight model =
    let
        ( mx, my ) =
            model.smoothMouse

        lightFloat =
            if isLight then
                1.0

            else
                0.0
    in
    WebGL.toHtmlWith
        [ WebGL.alpha True ]
        [ Attr.width 400
        , Attr.height 105
        , Attr.attribute "role" "img"
        , Attr.attribute "aria-label" "Interactive colorful Bayer-dithered generative wave artwork"
        , Attr.style "image-rendering" "pixelated"
        , Attr.class canvasClass
        , Events.on "pointermove" (pointerDecoder PointerMove)
        , Events.on "pointerleave" (Decode.succeed PointerLeave)
        , Events.on "pointerup" touchEndDecoder
        , Events.on "pointercancel" (Decode.succeed PointerLeave)
        , Events.on "pointerdown" (pointerDecoder PointerDown)
        ]
        [ WebGL.entity
            vertexShader
            fragmentShader
            quadMesh
            { uTime = model.time
            , uResolution = vec2 400 105
            , uMouse = vec2 mx my
            , uPresence = model.presence
            , uRipple0 = rippleAt 0 model.ripples
            , uRipple1 = rippleAt 1 model.ripples
            , uRipple2 = rippleAt 2 model.ripples
            , uRipple3 = rippleAt 3 model.ripples
            , uIsLight = lightFloat
            , uIntro = model.intro
            }
        ]


type alias Vertex =
    { position : Vec2
    }


quadMesh : Mesh Vertex
quadMesh =
    WebGL.triangles
        [ ( Vertex (vec2 -1 -1)
          , Vertex (vec2 3 -1)
          , Vertex (vec2 -1 3)
          )
        ]


type alias Uniforms =
    { uTime : Float
    , uResolution : Vec2
    , uMouse : Vec2
    , uPresence : Float
    , uRipple0 : Vec3
    , uRipple1 : Vec3
    , uRipple2 : Vec3
    , uRipple3 : Vec3
    , uIsLight : Float
    , uIntro : Float
    }


vertexShader : Shader Vertex Uniforms { vUv : Vec2 }
vertexShader =
    [glsl|
        attribute vec2 position;
        varying vec2 vUv;
        void main() {
            vUv = position * 0.5 + 0.5;
            gl_Position = vec4(position, 0.0, 1.0);
        }
    |]


fragmentShader : Shader {} Uniforms { vUv : Vec2 }
fragmentShader =
    [glsl|
        precision highp float;

        varying vec2 vUv;

        uniform float uTime;
        uniform vec2 uResolution;
        uniform vec2 uMouse;
        uniform float uPresence;
        uniform vec3 uRipple0;
        uniform vec3 uRipple1;
        uniform vec3 uRipple2;
        uniform vec3 uRipple3;
        uniform float uIsLight;
        uniform float uIntro;

        vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
        vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
        vec2 fade(vec2 t) { return t * t * t * (t * (t * 6.0 - 15.0) + 10.0); }

        float cnoise(vec2 P) {
            vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
            vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
            Pi = mod289(Pi);
            vec4 ix = Pi.xzxz;
            vec4 iy = Pi.yyww;
            vec4 fx = Pf.xzxz;
            vec4 fy = Pf.yyww;
            vec4 i = permute(permute(ix) + iy);
            vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0;
            vec4 gy = abs(gx) - 0.5;
            vec4 tx = floor(gx + 0.5);
            gx = gx - tx;
            vec2 g00 = vec2(gx.x, gy.x);
            vec2 g10 = vec2(gx.y, gy.y);
            vec2 g01 = vec2(gx.z, gy.z);
            vec2 g11 = vec2(gx.w, gy.w);
            vec4 norm = taylorInvSqrt(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
            g00 *= norm.x; g01 *= norm.y; g10 *= norm.z; g11 *= norm.w;
            float n00 = dot(g00, vec2(fx.x, fy.x));
            float n10 = dot(g10, vec2(fx.y, fy.y));
            float n01 = dot(g01, vec2(fx.z, fy.z));
            float n11 = dot(g11, vec2(fx.w, fy.w));
            vec2 fade_xy = fade(Pf.xy);
            vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
            return 2.3 * mix(n_x.x, n_x.y, fade_xy.y);
        }

        float fbm(vec2 p) {
            float value = 0.0;
            float amp = 0.55;
            for (int i = 0; i < 4; i++) {
                value += amp * cnoise(p);
                p = p * 2.02 + vec2(3.1, 1.7);
                amp *= 0.5;
            }
            return value;
        }

        float bayer2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
        float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
        float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer2(a); }

        vec3 paletteSample(float t, vec3 bg) {
            vec3 c1 = vec3(0.169, 0.333, 0.702);
            vec3 c2 = vec3(0.545, 0.459, 1.000);
            vec3 c3 = vec3(1.000, 0.310, 0.749);
            vec3 c4 = vec3(1.000, 0.596, 0.353);
            vec3 c5 = vec3(0.361, 0.875, 0.918);
            vec3 c6 = vec3(0.071, 0.780, 0.561);
            float s = clamp(t, 0.0, 1.0) * 6.0;
            if (s < 1.0) return mix(bg, c1, s);
            if (s < 2.0) return mix(c1, c2, s - 1.0);
            if (s < 3.0) return mix(c2, c3, s - 2.0);
            if (s < 4.0) return mix(c3, c4, s - 3.0);
            if (s < 5.0) return mix(c4, c5, s - 4.0);
            return mix(c5, c6, s - 5.0);
        }

        void applyRipple(
            vec3 rip, vec2 uv, vec2 aspectUv, float aspect, float vScale,
            inout vec2 totalWarp, inout float totalBoost, inout float totalCrest
        ) {
            float age = rip.z;
            if (age < 0.0 || age >= 2.1) return;
            float ry = rip.y * vScale;
            vec2 aspectRipple = vec2((rip.x - 0.5) * aspect, ry - 0.5);
            vec2 rDiff = aspectUv - aspectRipple;
            float rDist = length(rDiff);
            float life = age / 2.1;
            float fadeOut = (1.0 - life) * (1.0 - life);
            float travel = age * 1.45;
            float broadEnv = exp(-pow((rDist - travel) / 0.46, 2.0)) * fadeOut;
            float waveTrain = sin((rDist - travel) * 14.0);
            totalWarp += normalize(rDiff + 0.0001) * waveTrain * broadEnv * 0.14;
            totalBoost += (0.35 + 0.65 * max(0.0, waveTrain)) * broadEnv * 0.46;
            float hx = abs(uv.x - rip.x);
            float hTravel = age * 0.42;
            float hEnv = exp(-pow((hx - hTravel) / 0.22, 2.0)) * fadeOut;
            totalCrest += sin((hx - hTravel) * 24.0) * hEnv * 0.22;
        }

        void main() {
            vec2 cell = floor(gl_FragCoord.xy);
            vec2 uv = (cell + 0.5) / uResolution;
            float vScale = 210.0 / 148.0;
            float vy = uv.y * vScale;
            float my = uMouse.y * vScale;
            float aspect = 800.0 / 148.0;

            vec2 aspectUv = vec2((uv.x - 0.5) * aspect, vy - 0.5);
            vec2 aspectMouse = vec2((uMouse.x - 0.5) * aspect, my - 0.5);
            vec2 diff = aspectUv - aspectMouse;
            float dist = length(diff);

            float cAngle = atan(diff.y, diff.x);
            float shapeWobble = 0.028 * sin(cAngle * 3.0 + uTime * 1.1)
                + 0.018 * cos(cAngle * 5.0 - uTime * 0.85)
                + 0.036 * cnoise(vec2(uv.x * 7.5 + uTime * 0.35, vy * 6.0));
            float organicDist = max(0.0, dist + shapeWobble);
            float radialFalloff = clamp(1.0 - organicDist / 0.42, 0.0, 1.0);
            float touch = uPresence * pow(radialFalloff, 1.35);
            float fieldReach = uPresence * (1.0 - smoothstep(0.0, 0.96, dist));

            vec2 attract = -diff * fieldReach * 0.42;
            vec2 swirl = vec2(-diff.y, diff.x) * touch * 0.24;
            vec2 push = normalize(diff + 0.0001) * sin(dist * 18.0 - uTime * 4.5) * 0.014 * touch;

            vec2 rippleWarp = vec2(0.0);
            float rippleBoost = 0.0;
            float rippleCrestDisp = 0.0;
            applyRipple(uRipple0, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
            applyRipple(uRipple1, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
            applyRipple(uRipple2, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
            applyRipple(uRipple3, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);

            vec2 p = vec2(uv.x * 2.6, vy * 1.45) + attract + swirl + push + rippleWarp;
            vec2 q = vec2(fbm(p + vec2(uTime * 0.08, 0.0)), fbm(p + vec2(5.2, 1.3 - uTime * 0.06)));
            vec2 r = vec2(fbm(p + 1.65 * q + vec2(1.7, 9.2 + uTime * 0.05)), fbm(p + 1.65 * q + vec2(8.3, 2.8 - uTime * 0.04)));
            float f = fbm(p + 1.4 * r);

            float horizPull = exp(-pow((uv.x - uMouse.x) * 5.9, 2.0));
            float vertProximity = smoothstep(1.50, 0.12, my);
            float magneticLift = uPresence * horizPull * vertProximity * clamp(my - 0.14, 0.0, 0.78) * 1.15;

            float crestHeight = 0.44 + 0.18 * sin(uv.x * 4.8 + uTime * 0.3) + 0.12 * q.x
                + 0.09 * cos(uv.x * 9.5 - uTime * 0.2) + magneticLift + rippleCrestDisp;
            float waveMask = 1.0 - smoothstep(crestHeight - 0.22, crestHeight + 0.24, vy);

            float introEase = 1.0 - pow(1.0 - clamp(uIntro, 0.0, 1.0), 3.0);
            float introRise = smoothstep(introEase * 1.45, introEase * 1.45 - 0.55, vy);

            float cursorMix = touch * (0.72 + 0.24 * abs(f));
            float intensity = clamp((waveMask * (0.58 + 0.68 * abs(f)) + cursorMix + rippleBoost) * introRise * introEase, 0.0, 1.0);
            float colorCoord = clamp(0.16 + 0.72 * (0.5 + 0.5 * f) + 0.22 * uv.x + 0.16 * r.y + touch * 0.08 + rippleBoost * 0.35, 0.0, 1.0);
            float contour = smoothstep(0.08, 0.0, abs(fract(f * 3.8 + q.y * 0.6) - 0.5));

            vec3 bg = mix(vec3(0.0196), vec3(0.961, 0.957, 0.941), uIsLight);
            vec3 ribbonColor = paletteSample(colorCoord, bg);
            ribbonColor = mix(ribbonColor, vec3(1.0, 0.98, 0.945), contour * 0.28 * (1.0 - uIsLight));

            float threshold = bayer8(cell);
            float density = floor(intensity * 5.0 + threshold) / 5.0;
            if (density <= 0.02) {
                gl_FragColor = vec4(0.0);
            } else {
                vec3 raw = mix(bg, ribbonColor, clamp(density, 0.0, 1.0));
                vec3 quantized = clamp(floor(raw * 6.0 + (threshold - 0.5)) / 6.0, 0.0, 1.0);
                float a = smoothstep(0.02, 0.32, density);
                gl_FragColor = vec4(quantized * a, a);
            }
        }
    |]
```
::
