import { defineConfig } from 'vite';
import tailwindcss from '@tailwindcss/vite';
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, readFileSync, unlinkSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { buildBlogPosts } from './scripts/buildBlogPosts.mjs';
import { generateSeoFiles } from './scripts/generateSeo.mjs';

function elmPlugin() {
  let isProduction = false;

  function compileElm(entryPath) {
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
        const mainModule = server.moduleGraph.getModuleById(
          resolve(process.cwd(), 'src/Main.elm')
        );
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

function blogPostsPlugin() {
  const virtualId = 'virtual:blog-posts';
  const resolvedVirtualId = `\0${virtualId}`;
  const blogDir = resolve(process.cwd(), 'content/blog');

  return {
    name: 'vite-plugin-blog-posts',
    buildStart() {
      generateSeoFiles(process.cwd());
    },
    resolveId(id) {
      if (id === virtualId) return resolvedVirtualId;
      return null;
    },
    async load(id) {
      if (id !== resolvedVirtualId) return null;
      const posts = await buildBlogPosts(blogDir);
      return `export default ${JSON.stringify(posts)};`;
    },
    handleHotUpdate({ file, server }) {
      if (file.startsWith(blogDir) && file.endsWith('.md')) {
        const mod = server.moduleGraph.getModuleById(resolvedVirtualId);
        if (mod) server.moduleGraph.invalidateModule(mod);
        server.ws.send({ type: 'full-reload' });
        return [];
      }
      return undefined;
    },
  };
}

function spaFallbackPlugin() {
  return {
    name: 'vite-plugin-spa-404',
    closeBundle() {
      const distDir = resolve(process.cwd(), 'dist');
      const indexFile = join(distDir, 'index.html');
      const fallbackFile = join(distDir, '404.html');
      if (existsSync(indexFile)) {
        copyFileSync(indexFile, fallbackFile);
      }
    },
  };
}

export default defineConfig({
  plugins: [tailwindcss(), elmPlugin(), blogPostsPlugin(), spaFallbackPlugin()],
});
