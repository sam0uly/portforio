import { defineConfig } from 'vite';
import tailwindcss from '@tailwindcss/vite';
import { execFileSync } from 'node:child_process';
import { readFileSync, unlinkSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

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
      const wrapped = compiled.replace(/\}\(this\)\);\s*$/, '}(elmScope));');
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

export default defineConfig({
  plugins: [tailwindcss(), elmPlugin()],
});
