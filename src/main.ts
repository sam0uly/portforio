import './styles.css';
import blogPosts from 'virtual:blog-posts';
import components from 'virtual:components';
import { Elm } from './elm/Main.elm';
import type { HeadingId, SeoMeta, ThemeName } from './types/elm';
import { registerGrainientElement } from './web/grainient';
import { createScrollController, type ScrollController } from './web/scroll';

registerGrainientElement();

const locale =
  (Array.isArray(navigator.languages) && navigator.languages[0]) || navigator.language || 'en-US';
const reducedMotionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');

const app = Elm.Main.init({
  flags: {
    currentYear: new Intl.DateTimeFormat(locale, { year: 'numeric', timeZone: 'UTC' }).format(new Date()),
    diveDepthMeters: new Intl.NumberFormat(locale, { maximumFractionDigits: 0 }).format(35),
    prefersReducedMotion: reducedMotionQuery.matches,
    blogPosts,
    components,
  },
});

const setMeta = (selector: string, value: string): void => {
  document.querySelector(selector)?.setAttribute('content', value);
};

app.ports?.syncMeta?.subscribe((meta: SeoMeta) => {
  document.querySelector('link[rel="canonical"]')?.setAttribute('href', meta.canonical);
  setMeta('meta[name="description"]', meta.description);
  setMeta('meta[property="og:type"]', meta.ogType);
  setMeta('meta[property="og:url"]', meta.canonical);
  setMeta('meta[property="og:title"]', meta.title);
  setMeta('meta[property="og:description"]', meta.description);
  setMeta('meta[property="og:image"]', meta.ogImage);
  setMeta('meta[property="og:image:secure_url"]', meta.ogImage);
  setMeta('meta[property="og:image:alt"]', meta.ogImageAlt);
  setMeta('meta[name="twitter:url"]', meta.canonical);
  setMeta('meta[name="twitter:title"]', meta.title);
  setMeta('meta[name="twitter:description"]', meta.description);
  setMeta('meta[name="twitter:image"]', meta.ogImage);
  setMeta('meta[name="twitter:image:alt"]', meta.ogImageAlt);
});

app.ports?.setTheme?.subscribe((themeName: ThemeName) => {
  const isLight = themeName === 'light';
  const root = document.documentElement;
  root.classList.toggle('light', isLight);
  root.classList.toggle('dark', !isLight);
  root.style.colorScheme = isLight ? 'light' : 'dark';
  setMeta('meta[name="theme-color"]', isLight ? '#f5f4f0' : '#050505');
});

app.ports?.copyToClipboard?.subscribe(async (value: string) => {
  try {
    await navigator.clipboard.writeText(value);
    app.ports?.clipboardResult?.send(true);
  } catch {
    app.ports?.clipboardResult?.send(false);
  }
});

reducedMotionQuery.addEventListener('change', (e: MediaQueryListEvent) => {
  app.ports?.reducedMotionChanged?.send(e.matches);
});

let scrollCtrl: ScrollController | null = null;
const ensureScroll = (): ScrollController | null => {
  if (!scrollCtrl) {
    scrollCtrl = createScrollController(app.ports, reducedMotionQuery);
  }
  return scrollCtrl;
};

const initScrollWhenReady = (attemptsLeft: number): void => {
  if (ensureScroll() || attemptsLeft <= 0) return;
  requestAnimationFrame(() => initScrollWhenReady(attemptsLeft - 1));
};
requestAnimationFrame(() => initScrollWhenReady(10));

app.ports?.resetScroll?.subscribe(() => ensureScroll()?.reset());
app.ports?.scrollToHeading?.subscribe((id: HeadingId) => ensureScroll()?.scrollTo(id));

let audioCtx: AudioContext | null = null;
const PENTATONIC_HZ = [587.33, 523.25, 440.0, 392.0, 329.63, 261.63, 130.81] as const;

app.ports?.playSynthNotes?.subscribe((rows: readonly number[]) => {
  if (rows.length === 0) return;
  try {
    if (!audioCtx) {
      const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      audioCtx = new Ctx();
    }
    if (audioCtx.state === 'suspended') {
      void audioCtx.resume();
    }
    const now = audioCtx.currentTime;
    for (const row of rows) {
      const freq = PENTATONIC_HZ[row];
      if (freq === undefined) continue;
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      if (row === 6) {
        osc.type = 'sine';
        osc.frequency.setValueAtTime(140, now);
        osc.frequency.exponentialRampToValueAtTime(48, now + 0.14);
        gain.gain.setValueAtTime(0.18, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.16);
      } else {
        osc.type = row <= 2 ? 'triangle' : 'sine';
        osc.frequency.setValueAtTime(freq, now);
        gain.gain.setValueAtTime(0.09, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.24);
      }
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now);
      osc.stop(now + 0.25);
    }
  } catch {
    // ignore Web Audio restrictions
  }
});
