const MAX_STIRS = 24;
const MAX_TWIRLS = 4;
const STIR_LIFE = 1.3;
const STIR_STEP = 0.06;
const TWIRL_LIFE = 2.6;
const INTRO_SECONDS = 1.4;
const LIFT = 0.28;

type RgbTuple = readonly [number, number, number];
type LabTuple = readonly [number, number, number];

interface StirSample {
  x: number;
  y: number;
  vx: number;
  vy: number;
  age: number;
  grow: number;
  done: boolean;
}

interface TwirlSpin {
  readonly x: number;
  readonly y: number;
  readonly dir: 1 | -1;
  age: number;
}

interface PointerState {
  x: number;
  y: number;
  sx: number;
  sy: number;
  vx: number;
  inside: boolean;
  fresh: boolean;
}

interface LinkedProgram<U extends string> {
  readonly program: WebGLProgram;
  readonly uniforms: Record<U, WebGLUniformLocation | null>;
}

const COLORS: readonly RgbTuple[] = [
  [0x0c / 255, 0x0a / 255, 0x14 / 255],
  [0x2b / 255, 0x55 / 255, 0xb3 / 255],
  [0x8b / 255, 0x75 / 255, 0xff / 255],
  [0xff / 255, 0x4f / 255, 0xbf / 255],
  [0xff / 255, 0x98 / 255, 0x5a / 255],
];

const VERTEX = `#version 300 es
out vec2 vUv;
void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  vUv = p;
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}`;

const FIELD = `#version 300 es
precision mediump float;
uniform float uAspect, uTime, uExtent, uSettle, uReveal;
uniform vec2 uDir;
uniform vec3 uRamp[5];
uniform int uStirCount, uTwirlCount;
uniform vec4 uStir[24], uTwirl[4], uOcclude;
uniform float uStirWeight[24];
in vec2 vUv;
out vec4 outColor;

vec2 hash2(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xx + q.yz) * q.zy) * 2.0 - 1.0;
}
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return 0.5 + 0.5 * mix(
    mix(dot(hash2(i), f), dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
    mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)), dot(hash2(i + 1.0), f - 1.0), u.x),
    u.y
  );
}
vec2 drift(vec2 p, float t) {
  vec2 w1 = vec2(noise(p * 0.85 + vec2(t * 0.11, t * 0.07)), noise(p * 0.85 + vec2(4.1, 1.7) - vec2(t * 0.08, t * 0.12)));
  vec2 w2 = vec2(noise(p * 1.55 + w1 * 1.8 + vec2(1.3, 7.1) + t * 0.05), noise(p * 1.55 + w1 * 1.8 + vec2(6.4, 2.2) - t * 0.06));
  return (w1 - 0.5) * 1.1 + (w2 - 0.5) * 0.55;
}
float coord(vec2 p) {
  vec2 q = p / 1.05 + vec2(-uDir.y, uDir.x) * uTime * 0.45;
  return dot(p + drift(q + vec2(4.438, 2.674), uTime) * 0.9975 * uSettle, uDir) / uExtent + 0.5;
}
vec3 labToRgb(vec3 lab) {
  float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
  float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
  float s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
  l = l * l * l; m = m * m * m; s = s * s * s;
  return vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
}
vec3 encode(vec3 c) {
  c = clamp(c, 0.0, 1.0);
  return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}
void main() {
  if (vUv.x > uOcclude.x && vUv.x < uOcclude.z && vUv.y < uOcclude.w) discard;
  vec2 p = (vUv - 0.5) * vec2(uAspect, 1.0);
  for (int i = 0; i < 24; i++) {
    if (i >= uStirCount) break;
    float w = uStirWeight[i];
    if (w <= 0.0) continue;
    vec2 d = p - uStir[i].xy;
    p -= uStir[i].zw * w * exp(-dot(d, d) / 0.045);
  }
  for (int i = 0; i < 4; i++) {
    if (i >= uTwirlCount) break;
    float angle = uTwirl[i].z;
    if (angle == 0.0) continue;
    vec2 d = p - uTwirl[i].xy;
    float r2 = dot(d, d), rad = uTwirl[i].w, falloff = exp(-r2 / (rad * rad));
    float a = angle * falloff, c = cos(a), s = sin(a);
    float splash = sin(sqrt(r2) * 16.0 - rad * 18.0) * falloff * 0.008 * angle;
    p = uTwirl[i].xy + mat2(c, -s, s, c) * d + normalize(d + 0.0001) * splash;
  }
  float raw = coord(p), s = clamp(raw, 0.0, 1.0), scaled = s * 4.0;
  int idx = int(min(floor(scaled), 3.0));
  float f = scaled - float(idx);
  vec3 lab = mix(uRamp[idx], uRamp[idx + 1], smoothstep(0.0, 1.0, f));
  vec2 grad = vec2(dFdx(raw), dFdy(raw)) / max(vec2(dFdx(p.x), dFdy(p.y)), vec2(0.0005));
  vec3 normal = normalize(vec3(-(grad * sin(3.14159265 * s) * 1.52), 1.0));
  vec3 light = normalize(vec3(-uDir.y, uDir.x, 1.2));
  float diffuse = dot(normal, light) - light.z;
  lab = uRamp[0] + (lab - uRamp[0]) * (1.0 + (diffuse * 0.35 + max(diffuse, 0.0) * diffuse * 0.6) * 0.38);
  lab = mix(uRamp[0], lab, smoothstep(0.0, 1.0, uReveal * 1.5 - length(vUv - 0.5) * 0.6));
  outColor = vec4(encode(labToRgb(lab)), 1.0);
}`;

const COMPOSITE = `#version 300 es
precision mediump float;
uniform sampler2D uField;
uniform float uGrainSize, uFrame;
uniform vec4 uOcclude;
in vec2 vUv;
out vec4 outColor;

float hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}
void main() {
  if (vUv.x > uOcclude.x && vUv.x < uOcclude.z && vUv.y < uOcclude.w) discard;
  vec3 color = texture(uField, vUv).rgb;
  vec2 pixel = floor(gl_FragCoord.xy / max(uGrainSize, 0.5)) + uFrame * vec2(17.0, 59.0);
  float grain = hash(pixel) + hash(pixel + 7.13) - 1.0;
  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  outColor = vec4(clamp(color + grain * 0.08 * (0.45 + 2.2 * luma * (1.0 - luma)), 0.0, 1.0), 1.0);
}`;

const FIELD_UNIFORMS = [
  'uAspect',
  'uTime',
  'uExtent',
  'uSettle',
  'uReveal',
  'uDir',
  'uRamp',
  'uStirCount',
  'uTwirlCount',
  'uStir',
  'uTwirl',
  'uOcclude',
  'uStirWeight',
] as const;

const COMP_UNIFORMS = ['uField', 'uGrainSize', 'uFrame', 'uOcclude'] as const;

const toLin = (v: number): number => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);

const toLab = ([r, g, b]: RgbTuple): LabTuple => {
  const lr = toLin(r);
  const lg = toLin(g);
  const lb = toLin(b);
  const l = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
  const m = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
  const s = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
  return [
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  ];
};

const DARK_LABS: readonly LabTuple[] = COLORS.map(toLab);
const LIGHT_LABS: readonly LabTuple[] = (
  [[0.97, 0, 0] as LabTuple, ...DARK_LABS.slice(1).reverse()]
).map(([L, a, b]): LabTuple => [L + (1 - L) * LIFT, a * (1 - LIFT), b * (1 - LIFT)]);

function linkProgram<U extends string>(
  gl: WebGL2RenderingContext,
  fragSrc: string,
  names: readonly U[]
): LinkedProgram<U> | null {
  const compile = (type: number, src: string): WebGLShader | null => {
    const shader = gl.createShader(type);
    if (!shader) return null;
    gl.shaderSource(shader, src);
    gl.compileShader(shader);
    if (gl.getShaderParameter(shader, gl.COMPILE_STATUS)) return shader;
    gl.deleteShader(shader);
    return null;
  };
  const vert = compile(gl.VERTEX_SHADER, VERTEX);
  const frag = compile(gl.FRAGMENT_SHADER, fragSrc);
  const program = gl.createProgram();
  if (!vert || !frag || !program) return null;
  gl.attachShader(program, vert);
  gl.attachShader(program, frag);
  gl.linkProgram(program);
  gl.deleteShader(vert);
  gl.deleteShader(frag);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    gl.deleteProgram(program);
    return null;
  }
  const uniforms = {} as Record<U, WebGLUniformLocation | null>;
  for (const name of names) {
    uniforms[name] = gl.getUniformLocation(program, name);
  }
  return { program, uniforms };
}

class GrainientBgElement extends HTMLElement {
  private syncHandler: (() => void) | null = null;
  private cleanupHandler: (() => void) | null = null;

  static get observedAttributes(): readonly string[] {
    return ['light-mode', 'paused'];
  }

  attributeChangedCallback(): void {
    this.syncHandler?.();
  }

  connectedCallback(): void {
    if (this.cleanupHandler) return;

    const canvas = document.createElement('canvas');
    canvas.setAttribute('aria-hidden', 'true');
    canvas.style.cssText =
      'position:absolute;inset:0;display:block;width:100%;height:100%;contain:strict;transform:translateZ(0);';
    this.appendChild(canvas);

    const gl = canvas.getContext('webgl2', {
      alpha: false,
      antialias: false,
      depth: false,
      stencil: false,
      powerPreference: 'high-performance',
    });
    if (!gl) return;

    const field = linkProgram(gl, FIELD, FIELD_UNIFORMS);
    const comp = linkProgram(gl, COMPOSITE, COMP_UNIFORMS);
    if (!field || !comp) return;

    const vao = gl.createVertexArray();
    const target = gl.createTexture();
    const buf = gl.createFramebuffer();
    if (!vao || !target || !buf) return;

    gl.bindTexture(gl.TEXTURE_2D, target);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    const reduceQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    let reduce = reduceQuery.matches;
    let light: boolean | null = null;
    let paused = false;
    let rampInit = false;
    let morphing = false;
    let time = 0;
    let intro = reduce ? 1 : 0;
    let frameSeed = 0;
    let grainClock = 0;
    let raf = 0;
    let last = 0;
    let visible = true;
    let nextDir: 1 | -1 = 1;

    const view = { w: 1, h: 1, dpr: 1 };
    const fSize = { w: 0, h: 0 };
    const ramp = new Float32Array(15);
    const targetRamp = new Float32Array(15);
    const stirs = new Float32Array(MAX_STIRS * 4);
    const stirW = new Float32Array(MAX_STIRS);
    const twirls = new Float32Array(MAX_TWIRLS * 4);
    const occlude = new Float32Array(4);
    const trail: StirSample[] = [];
    const spins: TwirlSpin[] = [];
    const ptr: PointerState = { x: 0.5, y: 0.5, sx: 0.5, sy: 0.5, vx: 0, inside: false, fresh: true };
    const rad = (55 * Math.PI) / 180;
    const dirX = Math.sin(rad);
    const dirY = Math.cos(rad);

    const syncAttrs = (): void => {
      paused = this.getAttribute('paused') === 'true';
      const nextLight = this.getAttribute('light-mode') === 'true';
      if (nextLight !== light) {
        light = nextLight;
        (light ? LIGHT_LABS : DARK_LABS).forEach((lab, i) => targetRamp.set(lab, i * 3));
        if (!rampInit || reduce) {
          ramp.set(targetRamp);
          rampInit = true;
          morphing = false;
        } else {
          morphing = true;
        }
      }
    };

    const measureOcclude = (): void => {
      const sheet = document.getElementById('content-sheet');
      if (!sheet || view.w < 1 || view.h < 1) {
        occlude.fill(0);
        return;
      }
      const r = sheet.getBoundingClientRect();
      const minX = (r.left + 10) / view.w;
      const maxX = (r.right - 10) / view.w;
      const maxY = 1 - (r.top + 56) / view.h;
      if (maxX > minX && maxY > 0) occlude.set([minX, 0, maxX, maxY]);
      else occlude.fill(0);
    };

    const draw = (): void => {
      if (fSize.w < 1 || fSize.h < 1) return;
      const aspect = view.w / view.h;
      gl.bindVertexArray(vao);
      gl.disable(gl.BLEND);
      gl.bindFramebuffer(gl.FRAMEBUFFER, buf);
      gl.viewport(0, 0, fSize.w, fSize.h);
      gl.useProgram(field.program);
      gl.uniform1f(field.uniforms.uAspect, aspect);
      gl.uniform1f(field.uniforms.uTime, time);
      gl.uniform3fv(field.uniforms.uRamp, ramp);
      gl.uniform2f(field.uniforms.uDir, dirX, dirY);
      gl.uniform1f(field.uniforms.uExtent, aspect * Math.abs(dirX) + Math.abs(dirY));
      gl.uniform4fv(field.uniforms.uStir, stirs);
      gl.uniform1fv(field.uniforms.uStirWeight, stirW);
      gl.uniform1i(field.uniforms.uStirCount, trail.length);
      gl.uniform1i(field.uniforms.uTwirlCount, spins.length);
      gl.uniform4fv(field.uniforms.uTwirl, twirls);
      gl.uniform4fv(field.uniforms.uOcclude, occlude);
      gl.uniform1f(field.uniforms.uSettle, intro * intro * (3 - 2 * intro));
      gl.uniform1f(field.uniforms.uReveal, intro);
      gl.drawArrays(gl.TRIANGLES, 0, 3);

      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.useProgram(comp.program);
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, target);
      gl.uniform1i(comp.uniforms.uField, 0);
      gl.uniform1f(comp.uniforms.uGrainSize, 0.85 * view.dpr);
      gl.uniform1f(comp.uniforms.uFrame, frameSeed);
      gl.uniform4fv(comp.uniforms.uOcclude, occlude);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    };

    const frame = (now: number): void => {
      raf = 0;
      if (!visible || document.hidden) return;
      const dt = last ? Math.min(0.05, Math.max(0.001, (now - last) / 1000)) : 1 / 60;
      last = now;

      if (!reduce && !paused) time += dt * 0.16;
      if (intro < 1) intro = Math.min(1, intro + dt / INTRO_SECONDS);
      if (!paused && !reduce && (grainClock += dt) > 1 / 24) {
        grainClock = 0;
        frameSeed = (frameSeed + 1) % 97;
      }

      const aspect = view.w / view.h;
      const follow = 1 - Math.exp(-dt / 0.06);
      const px = ptr.sx;
      const py = ptr.sy;
      ptr.sx += (ptr.x - ptr.sx) * follow;
      ptr.sy += (ptr.y - ptr.sy) * follow;
      const vx = ((ptr.sx - px) / dt) * aspect;
      const vy = (ptr.sy - py) / dt;
      ptr.vx = vx;

      for (const s of trail) {
        if (s.done) s.age += dt;
      }
      if (!paused && ptr.inside && Math.hypot(vx, vy) > 0.02 && !reduce) {
        const currentHead = trail[0];
        if (!currentHead || currentHead.done) {
          trail.unshift({ x: 0, y: 0, vx: 0, vy: 0, age: 0, grow: 0, done: false });
          if (trail.length > MAX_STIRS) trail.pop();
        }
        const h = trail[0];
        if (h) {
          h.x = (ptr.sx - 0.5) * aspect;
          h.y = ptr.sy - 0.5;
          h.vx = vx;
          h.vy = vy;
          h.grow = Math.min(1, h.grow + dt / STIR_STEP);
          h.done = h.grow >= 1;
        }
      } else if (trail[0]) {
        trail[0].done = true;
      }

      while (trail.length > 0) {
        const tail = trail[trail.length - 1];
        if (tail && tail.age > STIR_LIFE) trail.pop();
        else break;
      }

      for (let i = 0; i < MAX_STIRS; i++) {
        const s = trail[i];
        if (!s) {
          stirW[i] = 0;
          continue;
        }
        const fade = 1 - s.age / STIR_LIFE;
        const cap = Math.min(1, 2.2 / Math.max(Math.hypot(s.vx, s.vy), 0.001));
        stirs.set([s.x, s.y, s.vx * cap, s.vy * cap], i * 4);
        stirW[i] = fade * fade * s.grow * 0.05;
      }

      for (const sp of spins) sp.age += dt;
      while (spins.length > 0) {
        const tail = spins[spins.length - 1];
        if (tail && tail.age > TWIRL_LIFE) spins.pop();
        else break;
      }

      for (let i = 0; i < MAX_TWIRLS; i++) {
        const sp = spins[i];
        if (!sp) {
          twirls[i * 4 + 2] = 0;
          continue;
        }
        const k = sp.age / TWIRL_LIFE;
        const env = Math.min(1, sp.age / 0.14) * (1 - k) * (1 - k);
        twirls.set([sp.x, sp.y, sp.dir * 4.4 * env, 0.28 + 0.28 * Math.min(1, sp.age / 0.7)], i * 4);
      }

      if (morphing) {
        const b = 1 - Math.exp(-dt / 0.18);
        let diff = 0;
        for (let i = 0; i < 15; i++) {
          const cur = ramp[i] ?? 0;
          const tgt = targetRamp[i] ?? 0;
          const next = cur + (tgt - cur) * b;
          ramp[i] = next;
          diff = Math.max(diff, Math.abs(tgt - next));
        }
        if (diff < 0.0006) {
          ramp.set(targetRamp);
          morphing = false;
        }
      }

      draw();
      if ((!reduce && !paused) || intro < 1 || morphing || trail.length > 0 || spins.length > 0) {
        raf = requestAnimationFrame(frame);
      } else {
        last = 0;
      }
    };

    const wake = (): void => {
      if (!raf && visible && !document.hidden) raf = requestAnimationFrame(frame);
    };

    const resize = (): void => {
      view.w = Math.max(1, this.clientWidth || window.innerWidth);
      view.h = Math.max(1, this.clientHeight || window.innerHeight);
      view.dpr = Math.min(window.devicePixelRatio || 1, 1.25);
      canvas.width = Math.max(1, Math.round(view.w * view.dpr));
      canvas.height = Math.max(1, Math.round(view.h * view.dpr));
      const fw = Math.max(1, Math.round(canvas.width / 3));
      const fh = Math.max(1, Math.round(canvas.height / 3));
      if (fw !== fSize.w || fh !== fSize.h) {
        fSize.w = fw;
        fSize.h = fh;
        gl.bindTexture(gl.TEXTURE_2D, target);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, fw, fh, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
        gl.bindFramebuffer(gl.FRAMEBUFFER, buf);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, target, 0);
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      }
      measureOcclude();
      draw();
      wake();
    };

    const locate = (e: PointerEvent): void => {
      const x = e.clientX / view.w;
      const y = 1 - e.clientY / view.h;
      ptr.inside = x >= 0 && x <= 1 && y >= 0 && y <= 1;
      ptr.x = x;
      ptr.y = y;
      if (ptr.fresh || !ptr.inside) {
        ptr.sx = x;
        ptr.sy = y;
        ptr.fresh = false;
      }
    };

    const onMove = (e: PointerEvent): void => {
      if (e.pointerType === 'touch') return;
      locate(e);
      if (ptr.inside || trail.length > 0) wake();
    };

    const onDown = (e: PointerEvent): void => {
      if (e.target instanceof Element && e.target.closest('[data-grainient-shield]')) return;
      e.preventDefault();
      window.getSelection?.()?.removeAllRanges();
      locate(e);
      if (!ptr.inside || paused || reduce) return;
      const dir: 1 | -1 = Math.abs(ptr.vx) > 0.08 ? (ptr.vx < 0 ? 1 : -1) : nextDir;
      nextDir = dir === 1 ? -1 : 1;
      spins.unshift({ x: (ptr.x - 0.5) * (view.w / view.h), y: ptr.y - 0.5, age: 0, dir });
      if (spins.length > MAX_TWIRLS) spins.pop();
      wake();
    };

    const onLeave = (): void => {
      ptr.inside = false;
    };

    const onVis = (): void => {
      last = 0;
      wake();
    };

    const onRed = (e: MediaQueryListEvent): void => {
      reduce = e.matches;
      if (reduce) intro = 1;
      draw();
      wake();
    };

    const ro = new ResizeObserver(resize);
    ro.observe(this);
    const io = new IntersectionObserver((entries) => {
      visible = entries.some((entry) => entry.isIntersecting);
      if (visible) {
        last = 0;
        wake();
      }
    });
    io.observe(this);

    window.addEventListener('pointermove', onMove, { passive: true });
    window.addEventListener('pointerdown', onDown, { passive: false });
    document.documentElement.addEventListener('pointerleave', onLeave);
    document.addEventListener('visibilitychange', onVis);
    reduceQuery.addEventListener('change', onRed);

    this.syncHandler = (): void => {
      syncAttrs();
      draw();
      wake();
    };

    syncAttrs();
    resize();
    requestAnimationFrame(() => {
      measureOcclude();
      draw();
    });

    this.cleanupHandler = (): void => {
      cancelAnimationFrame(raf);
      ro.disconnect();
      io.disconnect();
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerdown', onDown);
      document.documentElement.removeEventListener('pointerleave', onLeave);
      document.removeEventListener('visibilitychange', onVis);
      reduceQuery.removeEventListener('change', onRed);
      gl.deleteTexture(target);
      gl.deleteFramebuffer(buf);
      gl.deleteVertexArray(vao);
      gl.deleteProgram(field.program);
      gl.deleteProgram(comp.program);
      canvas.remove();
      this.syncHandler = null;
      this.cleanupHandler = null;
    };
  }

  disconnectedCallback(): void {
    this.cleanupHandler?.();
  }
}

export function registerGrainientElement(): void {
  if (!customElements.get('grainient-bg')) {
    customElements.define('grainient-bg', GrainientBgElement);
  }
}
