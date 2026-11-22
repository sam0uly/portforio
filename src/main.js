import './styles.css';
import { registerGrainientElement } from './grainient.js';
import { Elm } from './Main.elm';

registerGrainientElement();

const locale =
  (Array.isArray(navigator.languages) && navigator.languages[0]) ||
  navigator.language ||
  'en-US';

const yearFmt = new Intl.DateTimeFormat(locale, { year: 'numeric', timeZone: 'UTC' });
const intFmt = new Intl.NumberFormat(locale, { maximumFractionDigits: 0 });
const reducedMotionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags: {
    currentYear: yearFmt.format(new Date()),
    diveDepthMeters: intFmt.format(35),
    prefersReducedMotion: reducedMotionQuery.matches,
  },
});

if (app.ports?.setTheme) {
  app.ports.setTheme.subscribe((themeName) => {
    const isLight = themeName === 'light';
    const root = document.documentElement;
    root.classList.toggle('light', isLight);
    root.classList.toggle('dark', !isLight);
    root.style.colorScheme = isLight ? 'light' : 'dark';
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', isLight ? '#f5f4f0' : '#050505');
  });
}

if (app.ports?.copyToClipboard) {
  app.ports.copyToClipboard.subscribe(async (value) => {
    try {
      await navigator.clipboard.writeText(value);
      app.ports.clipboardResult?.send(true);
    } catch {
      app.ports.clipboardResult?.send(false);
    }
  });
}

if (app.ports?.reducedMotionChanged) {
  reducedMotionQuery.addEventListener('change', (event) => {
    app.ports.reducedMotionChanged.send(event.matches);
  });
}

function setupUnifiedScroll() {
  const scroller = document.getElementById('dither-stage');
  const content = document.getElementById('main-content');
  const track = document.getElementById('mobile-scroll-track');
  const thumb = document.getElementById('mobile-scroll-thumb');
  if (!scroller || !track || !thumb) return;

  const LERP = 0.1;
  let maxScroll = 0;
  let travelPx = 0;
  let trackTop = 0;
  let current = 0;
  let target = 0;
  let lastCommitted = 0;
  let raf = 0;
  let lastTime = 0;
  let dragging = false;
  let dragOffset = 0;

  const clampScroll = (y) => Math.max(0, Math.min(maxScroll, y));

  const paintThumb = (y) => {
    if (maxScroll <= 2) return;
    thumb.style.transform = `translate3d(0, ${((y / maxScroll) * travelPx).toFixed(2)}px, 0)`;
  };

  const commit = (y) => {
    const v = clampScroll(y);
    lastCommitted = v;
    scroller.scrollTop = v;
    window.scrollTo(0, v);
    paintThumb(v);
  };

  const stop = () => {
    if (!raf) return;
    cancelAnimationFrame(raf);
    raf = 0;
    lastTime = 0;
  };

  const tick = (now) => {
    const dt = lastTime ? Math.min(0.05, (now - lastTime) / 1000) : 1 / 60;
    lastTime = now;

    const factor = 1 - Math.exp(-LERP * dt * 60);
    current += (target - current) * factor;

    if (Math.abs(target - current) < 0.1) {
      current = target;
      commit(current);
      raf = 0;
      lastTime = 0;
      return;
    }

    commit(current);
    raf = requestAnimationFrame(tick);
  };

  const measure = () => {
    maxScroll = Math.max(0, scroller.scrollHeight - scroller.clientHeight);
    if (maxScroll <= 2) {
      document.body.style.height = '';
      track.style.opacity = '0';
      track.style.pointerEvents = 'none';
      stop();
      current = 0;
      target = 0;
      commit(0);
      return;
    }
    document.body.style.height = `${Math.ceil(window.innerHeight + maxScroll)}px`;
    track.style.opacity = '1';
    track.style.pointerEvents = 'auto';
    const rect = track.getBoundingClientRect();
    trackTop = rect.top;
    const innerH = Math.max(0, rect.height - 2.5);
    const thumbH = thumb.clientHeight || innerH * 0.4;
    travelPx = Math.max(0, innerH - thumbH);
    current = clampScroll(scroller.scrollTop || window.scrollY);
    target = raf ? clampScroll(target) : current;
    commit(current);
  };

  window.addEventListener(
    'wheel',
    (event) => {
      if (maxScroll <= 2 || event.ctrlKey || reducedMotionQuery.matches) return;
      if (Math.abs(event.deltaX) > Math.abs(event.deltaY)) return;
      event.preventDefault();

      let dy = event.deltaY;
      if (event.deltaMode === 1) dy *= 20;
      else if (event.deltaMode === 2) dy *= scroller.clientHeight * 0.85;

      if (!raf) {
        current = scroller.scrollTop;
        target = current;
      }
      target = clampScroll(target + dy);
      if (!raf) raf = requestAnimationFrame(tick);
    },
    { passive: false }
  );

  window.addEventListener('touchstart', stop, { passive: true });
  window.addEventListener(
    'keydown',
    (event) => {
      if (
        event.key === ' ' ||
        event.key === 'PageDown' ||
        event.key === 'PageUp' ||
        event.key === 'ArrowDown' ||
        event.key === 'ArrowUp' ||
        event.key === 'Home' ||
        event.key === 'End'
      ) {
        stop();
      }
    },
    { passive: true }
  );

  window.addEventListener(
    'scroll',
    () => {
      if (dragging) return;
      const y = window.scrollY;
      if (Math.abs(y - lastCommitted) <= 1.5) return;
      stop();
      current = y;
      target = y;
      lastCommitted = y;
      scroller.scrollTop = y;
      paintThumb(y);
    },
    { passive: true }
  );

  scroller.addEventListener(
    'scroll',
    () => {
      if (dragging) return;
      const y = scroller.scrollTop;
      if (Math.abs(y - lastCommitted) <= 1.5) return;
      stop();
      current = y;
      target = y;
      lastCommitted = y;
      window.scrollTo(0, y);
      paintThumb(y);
    },
    { passive: true }
  );

  const scrollToClientY = (clientY) => {
    if (maxScroll <= 2 || travelPx <= 0) return;
    const p = Math.max(0, Math.min(1, (clientY - trackTop - 2.5 - dragOffset) / travelPx));
    current = p * maxScroll;
    target = current;
    commit(current);
  };

  track.addEventListener('pointerdown', (event) => {
    if (maxScroll <= 2) return;
    event.preventDefault();
    event.stopPropagation();
    stop();
    dragging = true;
    document.body.style.userSelect = 'none';
    track.setPointerCapture(event.pointerId);
    trackTop = track.getBoundingClientRect().top;
    const tRect = thumb.getBoundingClientRect();
    if (event.clientY >= tRect.top && event.clientY <= tRect.bottom) {
      dragOffset = event.clientY - tRect.top;
    } else {
      dragOffset = tRect.height * 0.5;
      scrollToClientY(event.clientY);
    }
  });

  track.addEventListener('pointermove', (event) => {
    if (!dragging) return;
    event.preventDefault();
    scrollToClientY(event.clientY);
  });

  const endDrag = (event) => {
    if (!dragging) return;
    dragging = false;
    document.body.style.userSelect = '';
    if (track.hasPointerCapture(event.pointerId)) {
      track.releasePointerCapture(event.pointerId);
    }
  };

  track.addEventListener('pointerup', endDrag);
  track.addEventListener('pointercancel', endDrag);

  const ro = new ResizeObserver(measure);
  ro.observe(scroller);
  ro.observe(track);
  if (content) ro.observe(content);
  window.addEventListener('resize', measure, { passive: true });
  document.fonts?.ready?.then(measure);
  measure();
}

setupUnifiedScroll();
