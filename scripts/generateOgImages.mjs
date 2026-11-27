import { execFileSync, spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { extname, join, normalize, resolve } from 'node:path';
import { loadRawBlogPosts } from './generateSeo.mjs';

const ROOT = process.cwd();
const DIST_DIR = resolve(ROOT, 'dist');
const OG_OUT_DIR = join(DIST_DIR, 'og');
const WIDTH = 1200;
const HEIGHT = 630;

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
};

function findChromeBinary() {
  const candidates = [
    process.env.CHROME_PATH,
    'google-chrome',
    'google-chrome-stable',
    'chromium',
    'chromium-browser',
  ].filter(Boolean);

  for (const bin of candidates) {
    try {
      const resolved = execFileSync('which', [bin], {
        stdio: ['ignore', 'pipe', 'ignore'],
        encoding: 'utf8',
      }).trim();
      if (resolved) return resolved;
    } catch {
      if (existsSync(bin)) return bin;
    }
  }
  return null;
}

function startStaticServer(rootDir) {
  return new Promise((resolveServer, rejectServer) => {
    const server = createServer((req, res) => {
      const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
      const safePath = normalize(urlPath).replace(/^(\.\.[/\\])+/, '');
      let filePath = join(rootDir, safePath === '/' ? 'index.html' : safePath);

      if (!existsSync(filePath) || extname(filePath) === '') {
        const indexCandidate = join(filePath, 'index.html');
        if (existsSync(indexCandidate)) {
          filePath = indexCandidate;
        } else {
          filePath = join(rootDir, 'index.html');
        }
      }

      try {
        const data = readFileSync(filePath);
        const contentType = MIME_TYPES[extname(filePath).toLowerCase()] || 'application/octet-stream';
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(data);
      } catch {
        res.writeHead(404);
        res.end('Not found');
      }
    });

    server.on('error', rejectServer);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolveServer({ server, port: address.port });
    });
  });
}

function launchChrome(chromePath, userDataDir) {
  return new Promise((resolveChrome, rejectChrome) => {
    const child = spawn(
      chromePath,
      [
        '--headless=new',
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--hide-scrollbars',
        '--remote-debugging-port=0',
        `--window-size=${WIDTH},${HEIGHT}`,
        `--user-data-dir=${userDataDir}`,
        'about:blank',
      ],
      {
        stdio: ['ignore', 'ignore', 'pipe'],
        detached: true,
      }
    );

    let stderrBuf = '';
    let settled = false;
    const portFile = join(userDataDir, 'DevToolsActivePort');

    const finish = (browserWsUrl) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      clearInterval(portPoller);
      resolveChrome({ child, browserWsUrl });
    };

    const fail = (err) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      clearInterval(portPoller);
      try {
        process.kill(-child.pid, 'SIGTERM');
      } catch {
        // ignore
      }
      rejectChrome(err);
    };

    const portPoller = setInterval(() => {
      if (settled || !existsSync(portFile)) return;
      try {
        const lines = readFileSync(portFile, 'utf8').trim().split(/\r?\n/);
        if (lines.length >= 2 && /^\d+$/.test(lines[0])) {
          finish(`ws://127.0.0.1:${lines[0]}${lines[1]}`);
        }
      } catch {
        // file still being written
      }
    }, 50);

    const timeout = setTimeout(() => {
      fail(new Error(`Timed out waiting for Chrome DevTools:\n${stderrBuf}`));
    }, 20000);

    child.stderr.on('data', (chunk) => {
      stderrBuf += chunk.toString('utf8');
      const match = stderrBuf.match(/DevTools listening on (ws:\/\/[^\s]+)/);
      if (match) finish(match[1]);
    });

    child.on('error', fail);

    child.on('exit', (code) => {
      fail(new Error(`Chrome exited early (${code}):\n${stderrBuf}`));
    });
  });
}

function createCdpClient(wsUrl) {
  return new Promise((resolveClient, rejectClient) => {
    const ws = new WebSocket(wsUrl);
    let nextId = 1;
    const pending = new Map();
    const listeners = new Map();

    ws.addEventListener('open', () => {
      resolveClient({
        send(method, params = {}, sessionId = undefined) {
          const id = nextId++;
          const payload = { id, method, params };
          if (sessionId) payload.sessionId = sessionId;
          return new Promise((res, rej) => {
            pending.set(id, { res, rej, method });
            ws.send(JSON.stringify(payload));
          });
        },
        on(eventName, handler) {
          if (!listeners.has(eventName)) listeners.set(eventName, new Set());
          listeners.get(eventName).add(handler);
        },
        close() {
          ws.close();
        },
      });
    });

    ws.addEventListener('error', (err) => rejectClient(err));

    ws.addEventListener('message', (event) => {
      const msg = JSON.parse(typeof event.data === 'string' ? event.data : event.data.toString());
      if (msg.id && pending.has(msg.id)) {
        const { res, rej, method } = pending.get(msg.id);
        pending.delete(msg.id);
        if (msg.error) {
          rej(new Error(`CDP ${method} failed: ${msg.error.message}`));
        } else {
          res(msg.result);
        }
      } else if (msg.method && listeners.has(msg.method)) {
        for (const handler of listeners.get(msg.method)) {
          handler(msg.params, msg.sessionId);
        }
      }
    });
  });
}

async function evalJs(cdp, sessionId, expression) {
  const result = await cdp.send(
    'Runtime.evaluate',
    {
      expression,
      awaitPromise: true,
      returnByValue: true,
    },
    sessionId
  );
  if (result.exceptionDetails) {
    throw new Error(`Page JS error: ${result.exceptionDetails.text}`);
  }
  return result.result?.value;
}

async function captureCard(cdp, sessionId, cardId, outFile) {
  await evalJs(
    cdp,
    sessionId,
    `(async () => {
      let portal = document.getElementById('og-capture-portal');
      if (!portal) {
        portal = document.createElement('div');
        portal.id = 'og-capture-portal';
        document.body.appendChild(portal);
      }
      const card = document.getElementById(${JSON.stringify(cardId)});
      if (!card) throw new Error('Card not found: ' + ${JSON.stringify(cardId)});
      const clone = card.cloneNode(true);
      clone.removeAttribute('id');
      clone.classList.add('og-capture-active');
      portal.replaceChildren(clone);
      await document.fonts.ready;
      const imgs = Array.from(clone.querySelectorAll('img'));
      await Promise.all(imgs.map((img) => img.complete ? img.decode().catch(() => {}) : new Promise((r) => { img.onload = r; img.onerror = r; })));
      await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
      return true;
    })()`
  );

  const { data } = await cdp.send(
    'Page.captureScreenshot',
    {
      format: 'jpeg',
      quality: 92,
      clip: { x: 0, y: 0, width: WIDTH, height: HEIGHT, scale: 1 },
    },
    sessionId
  );

  writeFileSync(outFile, Buffer.from(data, 'base64'));
}

async function main() {
  if (!existsSync(join(DIST_DIR, 'index.html'))) {
    throw new Error('dist/index.html not found. Run `bun run build` first.');
  }

  const chromePath = findChromeBinary();
  if (!chromePath) {
    console.warn('[og] Chrome/Chromium not found; skipping OG image generation.');
    return;
  }

  mkdirSync(OG_OUT_DIR, { recursive: true });
  const posts = loadRawBlogPosts(resolve(ROOT, 'content/blog'));
  const userDataDir = mkdtempSync(join(tmpdir(), 'samouly-og-chrome-'));
  const { server, port } = await startStaticServer(DIST_DIR);

  let chromeChild = null;
  let cdp = null;

  try {
    const launched = await launchChrome(chromePath, userDataDir);
    chromeChild = launched.child;
    cdp = await createCdpClient(launched.browserWsUrl);

    const { targetId } = await cdp.send('Target.createTarget', {
      url: 'about:blank',
    });
    const { sessionId } = await cdp.send('Target.attachToTarget', {
      targetId,
      flatten: true,
    });

    await cdp.send('Page.enable', {}, sessionId);
    await cdp.send('Runtime.enable', {}, sessionId);
    await cdp.send(
      'Emulation.setEmulatedMedia',
      {
        features: [
          { name: 'prefers-reduced-motion', value: 'reduce' },
          { name: 'prefers-color-scheme', value: 'dark' },
        ],
      },
      sessionId
    );
    await cdp.send(
      'Emulation.setDeviceMetricsOverride',
      {
        width: WIDTH,
        height: HEIGHT,
        deviceScaleFactor: 1,
        mobile: false,
      },
      sessionId
    );

    const loaded = new Promise((res) => {
      cdp.on('Page.loadEventFired', (_, sid) => {
        if (sid === sessionId) res();
      });
    });
    await cdp.send('Page.navigate', { url: `http://127.0.0.1:${port}/og-images` }, sessionId);
    await loaded;

    await evalJs(
      cdp,
      sessionId,
      `(async () => {
        const deadline = Date.now() + 15000;
        while (Date.now() < deadline) {
          if (document.getElementById('og-blog-1') && document.getElementById('og-post-2')) break;
          await new Promise((r) => setTimeout(r, 50));
        }
        if (!document.getElementById('og-blog-1') || !document.getElementById('og-post-2')) {
          throw new Error('Timed out waiting for /og-images cards to render');
        }
        const style = document.createElement('style');
        style.textContent = \`
          body { overflow: hidden !important; }
          #og-capture-portal {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: ${WIDTH}px !important;
            height: ${HEIGHT}px !important;
            z-index: 2147483647 !important;
            margin: 0 !important;
            padding: 0 !important;
            background: var(--page-bg) !important;
          }
          #og-capture-portal .og-capture-active {
            width: ${WIDTH}px !important;
            height: ${HEIGHT}px !important;
            margin: 0 !important;
            border-radius: 0 !important;
            corner-shape: round !important;
            box-shadow: none !important;
            outline: none !important;
            --tw-ring-shadow: 0 0 #0000 !important;
          }
        \`;
        document.head.appendChild(style);
        return true;
      })()`
    );

    const blogOut = join(OG_OUT_DIR, 'blog.jpg');
    await captureCard(cdp, sessionId, 'og-blog-1', blogOut);
    console.log(`[og] generated dist/og/blog.jpg`);

    for (const post of posts) {
      await evalJs(
        cdp,
        sessionId,
        `(async () => {
          const btn = document.querySelector('button[data-og-slug=' + ${JSON.stringify(post.slug)} + ']');
          if (!btn) throw new Error('Post selector button not found: ' + ${JSON.stringify(post.slug)});
          btn.click();
          await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
          return true;
        })()`
      );

      const postOut = join(OG_OUT_DIR, `blog-${post.slug}.jpg`);
      await captureCard(cdp, sessionId, 'og-post-2', postOut);
      console.log(`[og] generated dist/og/blog-${post.slug}.jpg`);
    }
  } finally {
    if (cdp) {
      try {
        cdp.close();
      } catch {
        // Ignore close errors
      }
    }
    if (chromeChild?.pid) {
      try {
        process.kill(-chromeChild.pid, 'SIGTERM');
      } catch {
        try {
          chromeChild.kill('SIGTERM');
        } catch {
          // Ignore kill errors
        }
      }
    }
    server.close();
    try {
      rmSync(userDataDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 50 });
    } catch {
      // Ignore temp cleanup race while Chrome exits
    }
  }
}

main().catch((err) => {
  console.error('[og] failed:', err);
  process.exit(1);
});
