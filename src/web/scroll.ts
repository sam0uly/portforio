import type { ElmPorts, HeadingId } from '../types/elm';

export interface ScrollController {
  readonly reset: () => void;
  readonly scrollTo: (id: HeadingId) => void;
}

interface HeadingOffset {
  readonly id: HeadingId;
  readonly top: number;
}

interface TocAnimState {
  cur: number;
  goal: number;
  raf: number;
  last: number;
}

const WHEEL_EXEMPT_SELECTOR =
  '#desktop-pr-wing, #desktop-toc-wing, #mobile-pr-overlay, #mobile-toc-nav, [data-local-scroll]';
const STOP_KEYS = new Set([' ', 'PageDown', 'PageUp', 'ArrowDown', 'ArrowUp', 'Home', 'End']);

export function createScrollController(
  ports: ElmPorts | undefined,
  reducedMotionQuery: MediaQueryList
): ScrollController | null {
  const scroller = document.getElementById('dither-stage');
  const content = document.getElementById('main-content');
  const track = document.getElementById('mobile-scroll-track');
  const thumb = document.getElementById('mobile-scroll-thumb');
  const topBlur = document.getElementById('sheet-blur-top');
  const bottomBlur = document.getElementById('sheet-blur-bottom');

  if (!scroller || !track || !thumb) return null;

  let maxScroll = 0;
  let travelPx = 0;
  let trackTop = 0;
  let current = 0;
  let target = 0;
  let lastWritten = -1;
  let raf = 0;
  let lastTime = 0;
  let dragging = false;
  let dragOffset = 0;
  let hasMobileToc = false;
  let topBlurVis = false;
  let bottomBlurVis = false;
  let headingOffsets: readonly HeadingOffset[] = [];
  let lastActive: HeadingId | '' = '';

  const tocState = new Map<string, TocAnimState>();

  const clampScroll = (y: number): number => Math.max(0, Math.min(maxScroll, y));

  const setBlur = (el: HTMLElement | null, next: boolean, prev: boolean): boolean => {
    if (!el || next === prev) return prev;
    el.dataset['visible'] = next ? 'true' : 'false';
    return next;
  };

  const paintThumb = (y: number): void => {
    const can = maxScroll > 2;
    topBlurVis = setBlur(topBlur, can && y > 8 && !hasMobileToc, topBlurVis);
    bottomBlurVis = setBlur(bottomBlur, can && y < maxScroll - 72, bottomBlurVis);
    if (can) {
      thumb.style.transform = `translate3d(0, ${((y / maxScroll) * travelPx).toFixed(2)}px, 0)`;
    }
  };

  const cancelTocAnims = (): void => {
    for (const st of tocState.values()) {
      if (st.raf) cancelAnimationFrame(st.raf);
    }
    tocState.clear();
  };

  const centerTocNav = (navId: string, activeId: HeadingId | '', smooth: boolean): void => {
    if (!activeId) return;
    const nav = document.getElementById(navId);
    if (!nav) return;
    const btn = nav.querySelector<HTMLElement>(`[data-toc-id="${CSS.escape(activeId)}"]`);
    if (!btn) return;

    const maxNav = Math.max(0, nav.scrollHeight - nav.clientHeight);
    const goal = Math.max(
      0,
      Math.min(maxNav, btn.offsetTop - nav.offsetTop - nav.clientHeight / 2 + btn.offsetHeight / 2)
    );
    const prev = tocState.get(navId);

    if (!smooth || reducedMotionQuery.matches) {
      if (prev?.raf) cancelAnimationFrame(prev.raf);
      tocState.delete(navId);
      nav.scrollTop = goal;
      return;
    }

    const st: TocAnimState = prev ?? { cur: nav.scrollTop, goal, raf: 0, last: 0 };
    if (!st.raf) st.cur = nav.scrollTop;
    st.goal = goal;
    tocState.set(navId, st);
    if (st.raf) return;

    const step = (now: number): void => {
      const el = document.getElementById(navId);
      if (!el) {
        st.raf = 0;
        tocState.delete(navId);
        return;
      }
      const dt = st.last ? Math.min(0.05, (now - st.last) / 1000) : 1 / 60;
      st.last = now;
      st.cur += (st.goal - st.cur) * (1 - Math.exp(-0.14 * dt * 60));
      if (Math.abs(st.goal - st.cur) < 0.4) {
        el.scrollTop = st.goal;
        st.raf = 0;
        st.last = 0;
        return;
      }
      el.scrollTop = st.cur;
      st.raf = requestAnimationFrame(step);
    };
    st.raf = requestAnimationFrame(step);
  };

  document.addEventListener('click', (e: MouseEvent) => {
    if (e.target instanceof Element && e.target.closest('#mobile-toc-toggle')) {
      requestAnimationFrame(() => centerTocNav('mobile-toc-nav', lastActive, true));
    }
  });

  const measureHeadings = (): void => {
    const article = document.getElementById('article-body');
    if (!article) {
      headingOffsets = [];
      lastActive = '';
      return;
    }
    const sTop = scroller.getBoundingClientRect().top;
    const sScroll = scroller.scrollTop;
    headingOffsets = Array.from(
      article.querySelectorAll<HTMLElement>('h2[id], h3[id], h4[id], h5[id], h6[id]'),
      (el): HeadingOffset => ({
        id: el.id as HeadingId,
        top: el.getBoundingClientRect().top - sTop + sScroll,
      })
    );
  };

  const syncHeading = (y: number): void => {
    const first = headingOffsets[0];
    if (!ports?.activeHeadingChanged || !first) return;
    let id: HeadingId = first.id;
    for (const h of headingOffsets) {
      if (h.top <= y + 96) id = h.id;
      else break;
    }
    if (id !== lastActive) {
      lastActive = id;
      ports.activeHeadingChanged.send(id);
      centerTocNav('desktop-toc-nav', id, true);
      centerTocNav('mobile-toc-nav', id, true);
    }
  };

  const stop = (): void => {
    if (raf) {
      cancelAnimationFrame(raf);
      raf = 0;
      lastTime = 0;
    }
  };

  const commit = (y: number): void => {
    const v = clampScroll(y);
    lastWritten = v;
    scroller.scrollTop = v;
    paintThumb(v);
    syncHeading(v);
  };

  const tick = (now: number): void => {
    const dt = lastTime ? Math.min(0.05, (now - lastTime) / 1000) : 1 / 60;
    lastTime = now;
    current += (target - current) * (1 - Math.exp(-0.1 * dt * 60));
    if (Math.abs(target - current) < 0.15) {
      current = target;
      commit(current);
      raf = 0;
      lastTime = 0;
      return;
    }
    commit(current);
    raf = requestAnimationFrame(tick);
  };

  const measure = (): void => {
    maxScroll = Math.max(0, scroller.scrollHeight - scroller.clientHeight);
    hasMobileToc = window.innerWidth < 1280 && Boolean(document.getElementById('mobile-toc-toggle'));
    measureHeadings();

    if (maxScroll <= 2) {
      track.style.opacity = '0';
      track.style.pointerEvents = 'none';
      stop();
      current = 0;
      target = 0;
      commit(0);
      return;
    }

    track.style.opacity = '1';
    track.style.pointerEvents = 'auto';
    const rect = track.getBoundingClientRect();
    trackTop = rect.top;
    const innerH = Math.max(0, rect.height - 6);
    const ratio = scroller.clientHeight / Math.max(1, scroller.scrollHeight);
    const thumbH = Math.max(36, Math.min(innerH * 0.85, innerH * ratio));
    thumb.style.height = `${thumbH.toFixed(1)}px`;
    travelPx = Math.max(0, innerH - thumbH);

    if (raf) {
      target = clampScroll(target);
      current = clampScroll(current);
    } else {
      current = target = clampScroll(scroller.scrollTop);
    }
    paintThumb(current);
    syncHeading(current);
  };

  const subScrollState = new WeakMap<HTMLElement, { cur: number; tgt: number; raf: number; last: number }>();

  const smoothSubScroll = (el: HTMLElement, dy: number): void => {
    const maxSub = Math.max(0, el.scrollHeight - el.clientHeight);
    if (maxSub <= 1) return;
    let st = subScrollState.get(el);
    if (!st) {
      st = { cur: el.scrollTop, tgt: el.scrollTop, raf: 0, last: 0 };
      subScrollState.set(el, st);
    }
    if (!st.raf) {
      st.cur = st.tgt = el.scrollTop;
      st.last = 0;
    }
    st.tgt = Math.max(0, Math.min(maxSub, st.tgt + dy));
    if (st.raf) return;
    const step = (now: number): void => {
      if (!st) return;
      const dt = st.last ? Math.min(0.05, (now - st.last) / 1000) : 1 / 60;
      st.last = now;
      st.cur += (st.tgt - st.cur) * (1 - Math.exp(-0.1 * dt * 60));
      if (Math.abs(st.tgt - st.cur) < 0.15) {
        el.scrollTop = st.tgt;
        st.raf = 0;
        st.last = 0;
        return;
      }
      el.scrollTop = st.cur;
      st.raf = requestAnimationFrame(step);
    };
    st.raf = requestAnimationFrame(step);
  };

  window.addEventListener(
    'wheel',
    (e: WheelEvent) => {
      if (e.ctrlKey || reducedMotionQuery.matches || Math.abs(e.deltaX) > Math.abs(e.deltaY)) {
        return;
      }
      if (e.target instanceof Element) {
        const subWrap = e.target.closest<HTMLElement>(WHEEL_EXEMPT_SELECTOR);
        if (subWrap) {
          const subScroller =
            subWrap.querySelector<HTMLElement>('.overflow-y-auto') ??
            (subWrap.classList.contains('overflow-y-auto') ? subWrap : null);
          if (subScroller && subScroller.scrollHeight - subScroller.clientHeight > 1) {
            e.preventDefault();
            const subRaw =
              e.deltaMode === 1
                ? e.deltaY * 20
                : e.deltaMode === 2
                  ? e.deltaY * subScroller.clientHeight * 0.85
                  : e.deltaY;
            smoothSubScroll(subScroller, subRaw * 0.85);
          }
          return;
        }
      }
      if (maxScroll <= 2) return;
      e.preventDefault();

      const raw =
        e.deltaMode === 1
          ? e.deltaY * 20
          : e.deltaMode === 2
            ? e.deltaY * scroller.clientHeight * 0.85
            : e.deltaY;
      const dy = raw * 0.85;

      if (!raf) {
        current = target = scroller.scrollTop;
        lastTime = 0;
      }
      target = clampScroll(target + dy);
      if (!raf) raf = requestAnimationFrame(tick);
    },
    { passive: false }
  );

  window.addEventListener('touchstart', stop, { passive: true });
  window.addEventListener(
    'keydown',
    (e: KeyboardEvent) => {
      if (STOP_KEYS.has(e.key)) stop();
    },
    { passive: true }
  );

  scroller.addEventListener(
    'scroll',
    () => {
      if (raf || dragging) return;
      const y = scroller.scrollTop;
      if (Math.abs(y - lastWritten) <= 1.5) return;
      lastWritten = y;
      current = target = y;
      paintThumb(y);
      syncHeading(y);
    },
    { passive: true }
  );

  const scrollToClientY = (cy: number): void => {
    if (maxScroll <= 2 || travelPx <= 0) return;
    current = target = Math.max(0, Math.min(1, (cy - trackTop - 3 - dragOffset) / travelPx)) * maxScroll;
    commit(current);
  };

  track.addEventListener('pointerdown', (e: PointerEvent) => {
    if (maxScroll <= 2) return;
    e.preventDefault();
    e.stopPropagation();
    stop();
    dragging = true;
    document.body.style.userSelect = 'none';
    track.setPointerCapture(e.pointerId);
    trackTop = track.getBoundingClientRect().top;
    const r = thumb.getBoundingClientRect();
    if (e.clientY >= r.top && e.clientY <= r.bottom) {
      dragOffset = e.clientY - r.top;
    } else {
      dragOffset = r.height * 0.5;
      scrollToClientY(e.clientY);
    }
  });

  track.addEventListener('pointermove', (e: PointerEvent) => {
    if (!dragging) return;
    e.preventDefault();
    scrollToClientY(e.clientY);
  });

  const endDrag = (e: PointerEvent): void => {
    if (!dragging) return;
    dragging = false;
    document.body.style.userSelect = '';
    if (track.hasPointerCapture(e.pointerId)) track.releasePointerCapture(e.pointerId);
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
  if (footerEl && ports?.footerVisibilityChanged && 'IntersectionObserver' in window) {
    let lastVis: boolean | null = null;
    new IntersectionObserver(
      (entries) => {
        const vis = entries.some((entry) => entry.isIntersecting);
        if (vis !== lastVis) {
          lastVis = vis;
          ports.footerVisibilityChanged?.send(vis);
        }
      },
      { root: scroller, rootMargin: '80px 0px' }
    ).observe(footerEl);
  }

  return {
    reset(): void {
      stop();
      cancelTocAnims();
      current = 0;
      target = 0;
      lastActive = '';
      commit(0);
      const nav = document.getElementById('desktop-toc-nav');
      if (nav) nav.scrollTop = 0;
      requestAnimationFrame(measure);
    },
    scrollTo(id: HeadingId): void {
      const el = document.getElementById(id);
      if (!el) return;
      const topOffset = window.innerWidth < 1280 ? 68 : 24;
      const next = clampScroll(
        scroller.scrollTop + (el.getBoundingClientRect().top - scroller.getBoundingClientRect().top) - topOffset
      );
      if (reducedMotionQuery.matches) {
        stop();
        current = target = next;
        commit(next);
        return;
      }
      current = scroller.scrollTop;
      target = next;
      lastTime = 0;
      if (!raf) raf = requestAnimationFrame(tick);
    },
  };
}
