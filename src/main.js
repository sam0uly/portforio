import './styles.css';
import { registerGrainientElement } from './grainient.js';
import { loadBlogPosts } from './blogContent.js';
import { Elm } from './Main.elm';

registerGrainientElement();

const locale =
  (Array.isArray(navigator.languages) && navigator.languages[0]) ||
  navigator.language ||
  'en-US';

const yearFmt = new Intl.DateTimeFormat(locale, { year: 'numeric', timeZone: 'UTC' });
const intFmt = new Intl.NumberFormat(locale, { maximumFractionDigits: 0 });
const reducedMotionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');

function readRouteFromPath() {
  return window.location.pathname.replace(/\/+$/, '') || '/';
}

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags: {
    currentYear: yearFmt.format(new Date()),
    diveDepthMeters: intFmt.format(35),
    prefersReducedMotion: reducedMotionQuery.matches,
    initialRoute: readRouteFromPath(),
    blogPosts: loadBlogPosts(locale),
  },
});

if (app.ports?.pushRoute) {
  app.ports.pushRoute.subscribe((routePath) => {
    const nextPath = routePath.startsWith('/') ? routePath : `/${routePath}`;
    if (window.location.pathname !== nextPath) {
      history.pushState(null, '', nextPath);
    }
  });
}

if (app.ports?.routeChanged) {
  window.addEventListener('popstate', () => {
    app.ports.routeChanged.send(readRouteFromPath());
  });
}

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
  const topBlur = document.getElementById('sheet-blur-top');
  const bottomBlur = document.getElementById('sheet-blur-bottom');
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
  let hasMobileToc = false;
  let topBlurVisible = false;
  let bottomBlurVisible = false;
  let headingOffsets = [];
  let lastActiveHeading = '';

  const clampScroll = (y) => Math.max(0, Math.min(maxScroll, y));

  const setBlurVisible = (el, next, prev) => {
    if (!el || next === prev) return prev;
    el.dataset.visible = next ? 'true' : 'false';
    return next;
  };

  const paintEdgeBlurs = (y) => {
    const canScroll = maxScroll > 2;
    topBlurVisible = setBlurVisible(topBlur, canScroll && y > 8 && !hasMobileToc, topBlurVisible);
    bottomBlurVisible = setBlurVisible(bottomBlur, canScroll && y < maxScroll - 16, bottomBlurVisible);
  };

  const paintThumb = (y) => {
    paintEdgeBlurs(y);
    if (maxScroll <= 2) return;
    thumb.style.transform = `translate3d(0, ${((y / maxScroll) * travelPx).toFixed(2)}px, 0)`;
  };

  const tocScrollState = new Map();

  const centerTocNav = (navId, activeId, smooth) => {
    const tocNav = document.getElementById(navId);
    if (!tocNav || !activeId) return;
    const activeBtn = tocNav.querySelector(`[data-toc-id="${CSS.escape(activeId)}"]`);
    if (!activeBtn) return;
    const maxNavScroll = Math.max(0, tocNav.scrollHeight - tocNav.clientHeight);
    const targetTop = Math.max(
      0,
      Math.min(
        maxNavScroll,
        activeBtn.offsetTop - tocNav.offsetTop - tocNav.clientHeight / 2 + activeBtn.offsetHeight / 2
      )
    );

    const prev = tocScrollState.get(navId);
    if (!smooth || reducedMotionQuery.matches) {
      if (prev?.raf) cancelAnimationFrame(prev.raf);
      tocScrollState.delete(navId);
      tocNav.scrollTop = targetTop;
      return;
    }

    const state = prev || { current: tocNav.scrollTop, target: targetTop, raf: 0, last: 0 };
    if (!state.raf) state.current = tocNav.scrollTop;
    state.target = targetTop;
    tocScrollState.set(navId, state);

    if (state.raf) return;
    const step = (now) => {
      const el = document.getElementById(navId);
      if (!el) {
        state.raf = 0;
        tocScrollState.delete(navId);
        return;
      }
      const dt = state.last ? Math.min(0.05, (now - state.last) / 1000) : 1 / 60;
      state.last = now;
      const factor = 1 - Math.exp(-0.14 * dt * 60);
      state.current += (state.target - state.current) * factor;
      if (Math.abs(state.target - state.current) < 0.4) {
        el.scrollTop = state.target;
        state.raf = 0;
        state.last = 0;
        return;
      }
      el.scrollTop = state.current;
      state.raf = requestAnimationFrame(step);
    };
    state.raf = requestAnimationFrame(step);
  };

  document.addEventListener('click', (event) => {
    if (event.target instanceof Element && event.target.closest('#mobile-toc-toggle')) {
      requestAnimationFrame(() => centerTocNav('mobile-toc-nav', lastActiveHeading, true));
    }
  });

  const measureHeadings = () => {
    const article = document.getElementById('article-body');
    if (!article) {
      headingOffsets = [];
      lastActiveHeading = '';
      return;
    }
    const scrollerTop = scroller.getBoundingClientRect().top;
    const scrollTop = scroller.scrollTop;
    const nodes = article.querySelectorAll('h2[id], h3[id], h4[id], h5[id], h6[id]');
    headingOffsets = Array.from(nodes, (el) => ({
      id: el.id,
      top: el.getBoundingClientRect().top - scrollerTop + scrollTop,
    }));
  };

  const syncActiveHeading = (y) => {
    if (!app.ports?.activeHeadingChanged || !headingOffsets.length) return;
    const threshold = y + 96;
    let activeId = headingOffsets[0].id;
    for (let i = 0; i < headingOffsets.length; i += 1) {
      if (headingOffsets[i].top <= threshold) {
        activeId = headingOffsets[i].id;
      } else {
        break;
      }
    }
    if (activeId !== lastActiveHeading) {
      lastActiveHeading = activeId;
      app.ports.activeHeadingChanged.send(activeId);
      centerTocNav('desktop-toc-nav', activeId, true);
      centerTocNav('mobile-toc-nav', activeId, true);
    }
  };

  const commit = (y, syncWindow = true) => {
    const v = clampScroll(y);
    lastCommitted = v;
    scroller.scrollTop = v;
    if (syncWindow) window.scrollTo(0, v);
    paintThumb(v);
    syncActiveHeading(v);
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
      commit(current, true);
      raf = 0;
      lastTime = 0;
      return;
    }

    commit(current, false);
    raf = requestAnimationFrame(tick);
  };

  const measure = () => {
    maxScroll = Math.max(0, scroller.scrollHeight - scroller.clientHeight);
    hasMobileToc = window.innerWidth < 1280 && Boolean(document.getElementById('mobile-toc-toggle'));
    measureHeadings();
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
      syncActiveHeading(y);
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
      syncActiveHeading(y);
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

  const footerEl = document.getElementById('dither-footer');
  if (footerEl && app.ports?.footerVisibilityChanged && 'IntersectionObserver' in window) {
    let lastFooterVisible = null;
    const footerObserver = new IntersectionObserver(
      (entries) => {
        const isVisible = entries.some((entry) => entry.isIntersecting);
        if (isVisible !== lastFooterVisible) {
          lastFooterVisible = isVisible;
          app.ports.footerVisibilityChanged.send(isVisible);
        }
      },
      { root: scroller, rootMargin: '80px 0px' }
    );
    footerObserver.observe(footerEl);
  }

  return {
    reset() {
      stop();
      current = 0;
      target = 0;
      lastActiveHeading = '';
      commit(0);
      const tocNav = document.getElementById('desktop-toc-nav');
      if (tocNav) tocNav.scrollTop = 0;
      requestAnimationFrame(() => {
        measure();
      });
    },
    scrollTo(id) {
      const el = document.getElementById(id);
      if (!el) return;
      const scrollerRect = scroller.getBoundingClientRect();
      const elRect = el.getBoundingClientRect();
      const topOffset = window.innerWidth < 1280 ? 68 : 24;
      const nextTarget = clampScroll(scroller.scrollTop + (elRect.top - scrollerRect.top) - topOffset);
      if (reducedMotionQuery.matches) {
        stop();
        current = nextTarget;
        target = nextTarget;
        commit(nextTarget);
        return;
      }
      current = scroller.scrollTop;
      target = nextTarget;
      if (!raf) raf = requestAnimationFrame(tick);
    },
  };
}

const scrollController = setupUnifiedScroll();

if (app.ports?.resetScroll && scrollController) {
  app.ports.resetScroll.subscribe(() => {
    scrollController.reset();
  });
}

if (app.ports?.scrollToHeading && scrollController) {
  app.ports.scrollToHeading.subscribe((id) => {
    scrollController.scrollTo(id);
  });
}
