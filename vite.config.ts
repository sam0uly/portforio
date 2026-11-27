import { defineConfig, type Plugin } from 'vite';
import tailwindcss from '@tailwindcss/vite';
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { buildBlogPosts } from './scripts/buildBlogPosts.mjs';
import { buildComponents } from './scripts/buildComponents.mjs';
import { generateSeoFiles, loadRawBlogPosts } from './scripts/generateSeo.mjs';

interface RouteMeta {
  readonly title: string;
  readonly description: string;
  readonly canonicalUrl: string;
  readonly ogType: 'website' | 'article';
  readonly ogImage: string;
  readonly ogImageAlt: string;
}

function elmPlugin(): Plugin {
  let isProduction = false;

  function compileElm(entryPath: string): string {
    const tempDir = mkdtempSync(join(tmpdir(), 'elm-vite-'));
    const outputFile = join(tempDir, 'elm.js');
    const args = ['make', entryPath, `--output=${outputFile}`];
    if (isProduction) {
      args.push('--optimize');
    }

    try {
      execFileSync('elm', args, {
        cwd: process.cwd(),
        stdio: ['ignore', 'pipe', 'pipe'],
        encoding: 'utf8',
      });
      const compiled = readFileSync(outputFile, 'utf8');
      let wrapped = compiled.replace(/\}\(this\)\);\s*$/, '}(elmScope));');
      if (isProduction) {
        wrapped = wrapped.replace(/(?<!function )\b([FA][2-9])\(/g, '/*#__PURE__*/$1(');
      }
      return `const elmScope = {};\n${wrapped}\nexport const Elm = elmScope.Elm;\nexport default elmScope.Elm;\n`;
    } finally {
      try {
        unlinkSync(outputFile);
      } catch {
        // Ignore temp file cleanup errors
      }
    }
  }

  return {
    name: 'vite-plugin-elm-custom',
    configResolved(config) {
      isProduction = config.command === 'build';
    },
    resolveId(id) {
      if (id.endsWith('.elm')) {
        return resolve(process.cwd(), id.replace(/^\//, ''));
      }
      return null;
    },
    load(id) {
      if (id.endsWith('.elm')) {
        return compileElm(id);
      }
      return null;
    },
    handleHotUpdate({ file, server }) {
      if (file.endsWith('.elm')) {
        const mainModule = server.moduleGraph.getModuleById(resolve(process.cwd(), 'src/elm/Main.elm'));
        if (mainModule) {
          server.moduleGraph.invalidateModule(mainModule);
        }
        server.ws.send({ type: 'full-reload' });
        return [];
      }
      return undefined;
    },
  };
}

function blogPostsPlugin(): Plugin {
  const virtualId = 'virtual:blog-posts';
  const resolvedVirtualId = `\0${virtualId}`;
  const blogDir = resolve(process.cwd(), 'content/blog');
  let cachedPosts: Awaited<ReturnType<typeof buildBlogPosts>> | null = null;

  const getPosts = async () => {
    if (!cachedPosts) {
      cachedPosts = await buildBlogPosts(blogDir);
    }
    return cachedPosts;
  };

  return {
    name: 'vite-plugin-blog-posts',
    buildStart() {
      cachedPosts = null;
      generateSeoFiles(process.cwd());
    },
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const match = req.url?.match(/^\/blog-data\/([a-zA-Z0-9_-]+)\.json(?:\?.*)?$/);
        if (!match) {
          next();
          return;
        }
        const slug = match[1];
        const posts = await getPosts();
        const post = posts.find((p) => p.slug === slug);
        if (!post) {
          res.statusCode = 404;
          res.end('Not found');
          return;
        }
        res.setHeader('Content-Type', 'application/json; charset=utf-8');
        res.end(JSON.stringify(post.blocks));
      });
    },
    resolveId(id) {
      if (id === virtualId) return resolvedVirtualId;
      return null;
    },
    async load(id) {
      if (id !== resolvedVirtualId) return null;
      const posts = await getPosts();
      const metadataOnly = posts.map(({ blocks: _blocks, ...meta }) => ({ ...meta, blocks: [] }));
      return `export default ${JSON.stringify(metadataOnly)};`;
    },
    async closeBundle() {
      const distDir = resolve(process.cwd(), 'dist');
      const blogDataDir = join(distDir, 'blog-data');
      mkdirSync(blogDataDir, { recursive: true });
      const posts = await getPosts();
      for (const post of posts) {
        writeFileSync(join(blogDataDir, `${post.slug}.json`), JSON.stringify(post.blocks), 'utf8');
      }
    },
    handleHotUpdate({ file, server }) {
      if (file.startsWith(blogDir) && file.endsWith('.md')) {
        cachedPosts = null;
        const mod = server.moduleGraph.getModuleById(resolvedVirtualId);
        if (mod) server.moduleGraph.invalidateModule(mod);
        server.ws.send({ type: 'full-reload' });
        return [];
      }
      return undefined;
    },
  };
}

function escapeHtmlAttr(value: string): string {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function buildRouteHtml(template: string, meta: RouteMeta): string {
  const esc = escapeHtmlAttr;
  const replaceMeta =
    (attrName: string, attrValue: string, content: string) =>
    (html: string): string => {
      const re = new RegExp(`(<meta\\b[^>]*\\b${attrName}="${attrValue}"[^>]*\\bcontent=")[^"]*("[^>]*>)`, 'i');
      return html.replace(re, `$1${esc(content)}$2`);
    };

  let html = template;
  html = html.replace(/<title>[^<]*<\/title>/i, `<title>${esc(meta.title)}</title>`);
  html = html.replace(
    /(<link\b[^>]*\brel="canonical"[^>]*\bhref=")[^"]*("[^>]*>)/i,
    `$1${esc(meta.canonicalUrl)}$2`
  );
  for (const step of [
    replaceMeta('name', 'description', meta.description),
    replaceMeta('property', 'og:type', meta.ogType),
    replaceMeta('property', 'og:url', meta.canonicalUrl),
    replaceMeta('property', 'og:title', meta.title),
    replaceMeta('property', 'og:description', meta.description),
    replaceMeta('property', 'og:image', meta.ogImage),
    replaceMeta('property', 'og:image:secure_url', meta.ogImage),
    replaceMeta('property', 'og:image:alt', meta.ogImageAlt),
    replaceMeta('name', 'twitter:url', meta.canonicalUrl),
    replaceMeta('name', 'twitter:title', meta.title),
    replaceMeta('name', 'twitter:description', meta.description),
    replaceMeta('name', 'twitter:image', meta.ogImage),
    replaceMeta('name', 'twitter:image:alt', meta.ogImageAlt),
  ]) {
    html = step(html);
  }
  return html;
}

function spaFallbackPlugin(): Plugin {
  const SITE_ORIGIN = 'https://portforio.samouly.fun';
  return {
    name: 'vite-plugin-spa-404',
    closeBundle() {
      const distDir = resolve(process.cwd(), 'dist');
      const indexFile = join(distDir, 'index.html');
      const fallbackFile = join(distDir, '404.html');
      if (!existsSync(indexFile)) return;

      copyFileSync(indexFile, fallbackFile);
      const template = readFileSync(indexFile, 'utf8');

      const blogDirOut = join(distDir, 'blog');
      mkdirSync(blogDirOut, { recursive: true });
      writeFileSync(
        join(blogDirOut, 'index.html'),
        buildRouteHtml(template, {
          title: 'Writing | Alaa El-Samouly (Samouly)',
          description:
            'Technical writing by Alaa El-Samouly (Samouly) on Go, Linux distributions, NixOS, terminal tooling, and software engineering.',
          canonicalUrl: `${SITE_ORIGIN}/blog`,
          ogType: 'website',
          ogImage: `${SITE_ORIGIN}/og/blog.jpg`,
          ogImageAlt: 'Writing by Alaa El-Samouly (Samouly) on Go, Linux, NixOS, and software engineering.',
        }),
        'utf8'
      );

      const posts = loadRawBlogPosts(resolve(process.cwd(), 'content/blog'));
      for (const post of posts) {
        const postDirOut = join(blogDirOut, post.slug);
        mkdirSync(postDirOut, { recursive: true });
        writeFileSync(
          join(postDirOut, 'index.html'),
          buildRouteHtml(template, {
            title: `${post.title} | Samouly`,
            description:
              post.description || `Technical article "${post.title}" by Alaa El-Samouly (Samouly).`,
            canonicalUrl: `${SITE_ORIGIN}/blog/${post.slug}`,
            ogType: 'article',
            ogImage: `${SITE_ORIGIN}/og/blog-${post.slug}.jpg`,
            ogImageAlt: `${post.title} by Alaa El-Samouly (Samouly).`,
          }),
          'utf8'
        );
      }
    },
  };
}

function componentsPlugin(): Plugin {
  const virtualId = 'virtual:components';
  const resolvedVirtualId = `\0${virtualId}`;
  const compDir = resolve(process.cwd(), 'content/components');
  let cached: Awaited<ReturnType<typeof buildComponents>> | null = null;

  const getComponents = async () => {
    if (!cached) {
      cached = await buildComponents(compDir);
    }
    return cached;
  };

  return {
    name: 'vite-plugin-components',
    buildStart() {
      cached = null;
    },
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const match = req.url?.match(/^\/component-data\/([a-zA-Z0-9_-]+)\.json(?:\?.*)?$/);
        if (!match) {
          next();
          return;
        }
        const slug = match[1];
        const list = await getComponents();
        const item = list.find((c) => c.slug === slug);
        if (!item) {
          res.statusCode = 404;
          res.end('Not found');
          return;
        }
        res.setHeader('Content-Type', 'application/json; charset=utf-8');
        res.end(
          JSON.stringify({
            description: item.description,
            descriptionBlocks: item.descriptionBlocks,
            frameworks: item.frameworks,
          })
        );
      });
    },
    resolveId(id) {
      if (id === virtualId) return resolvedVirtualId;
      return null;
    },
    async load(id) {
      if (id !== resolvedVirtualId) return null;
      const list = await getComponents();
      const metadataOnly = list.map(
        ({ frameworks: _fw, descriptionBlocks: _blocks, ...meta }) => ({
          ...meta,
          descriptionBlocks: [],
          frameworks: [],
        })
      );
      return `export default ${JSON.stringify(metadataOnly)};`;
    },
    async closeBundle() {
      const distDir = resolve(process.cwd(), 'dist');
      const dataDir = join(distDir, 'component-data');
      mkdirSync(dataDir, { recursive: true });
      const list = await getComponents();
      for (const item of list) {
        writeFileSync(
          join(dataDir, `${item.slug}.json`),
          JSON.stringify({
            description: item.description,
            descriptionBlocks: item.descriptionBlocks,
            frameworks: item.frameworks,
          }),
          'utf8'
        );
      }

      const indexFile = join(distDir, 'index.html');
      if (!existsSync(indexFile)) return;
      const template = readFileSync(indexFile, 'utf8');
      const SITE_ORIGIN = 'https://portforio.samouly.fun';
      const compOutDir = join(distDir, 'components');
      mkdirSync(compOutDir, { recursive: true });
      writeFileSync(
        join(compOutDir, 'index.html'),
        buildRouteHtml(template, {
          title: 'Components | Alaa El-Samouly (Samouly)',
          description:
            'Interactive UI components crafted by Alaa El-Samouly with copy-paste Tailwind source code for Vue, React, and Elm.',
          canonicalUrl: `${SITE_ORIGIN}/components`,
          ogType: 'website',
          ogImage: `${SITE_ORIGIN}/og-image.jpg`,
          ogImageAlt: 'UI Components by Alaa El-Samouly (Samouly) for Vue, React, and Elm.',
        }),
        'utf8'
      );
      for (const item of list) {
        const itemDir = join(compOutDir, item.slug);
        mkdirSync(itemDir, { recursive: true });
        writeFileSync(
          join(itemDir, 'index.html'),
          buildRouteHtml(template, {
            title: `${item.title} | Components · Samouly`,
            description: item.summary,
            canonicalUrl: `${SITE_ORIGIN}/components/${item.slug}`,
            ogType: 'article',
            ogImage: `${SITE_ORIGIN}/og-image.jpg`,
            ogImageAlt: `${item.title} component for Vue, React, and Elm by Alaa El-Samouly.`,
          }),
          'utf8'
        );
      }
    },
    handleHotUpdate({ file, server }) {
      if (file.startsWith(compDir) && file.endsWith('.md')) {
        cached = null;
        const mod = server.moduleGraph.getModuleById(resolvedVirtualId);
        if (mod) server.moduleGraph.invalidateModule(mod);
        server.ws.send({ type: 'full-reload' });
        return [];
      }
      return undefined;
    },
  };
}

export default defineConfig({
  plugins: [tailwindcss(), elmPlugin(), blogPostsPlugin(), componentsPlugin(), spaFallbackPlugin()],
});
