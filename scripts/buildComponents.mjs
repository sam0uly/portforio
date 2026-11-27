import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { highlightCode, parseBlocks, parseFrontmatter } from './buildBlogPosts.mjs';

async function parseFrameworkBody(raw) {
  const lines = raw.split(/\r?\n/);
  let currentSection = 'source';
  let usage = null;
  let source = null;

  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const heading = line.match(/^###\s+(usage|source)\s*$/i);
    if (heading) {
      currentSection = heading[1].toLowerCase();
      i += 1;
      continue;
    }

    const fence = line.match(/^```([a-zA-Z0-9_-]*)(?:\s+\[([^\]]+)\])?\s*$/);
    if (fence) {
      const lang = fence[1] || 'text';
      const filename = fence[2] || '';
      const codeLines = [];
      i += 1;
      while (i < lines.length && !lines[i].startsWith('```')) {
        codeLines.push(lines[i]);
        i += 1;
      }
      if (i < lines.length) i += 1;
      const code = codeLines.join('\n').trimEnd();
      const tokens = await highlightCode(code, lang);
      const snippet = { lang, filename, code, lines: tokens };
      if (currentSection === 'usage') usage = snippet;
      else source = snippet;
      continue;
    }

    i += 1;
  }

  return { usage, source };
}

async function parseComponentMarkdown(slug, raw) {
  const { meta, body } = parseFrontmatter(raw);
  const fwRegex = /^::framework\{name="([^"]+)"\}\r?\n([\s\S]*?)^::\s*$/gm;

  const frameworks = [];
  let description = body;
  const firstMatch = body.search(/^::framework\{/m);
  if (firstMatch !== -1) {
    description = body.slice(0, firstMatch).trim();
  }

  let match;
  while ((match = fwRegex.exec(body)) !== null) {
    const id = match[1].trim().toLowerCase();
    const { usage, source } = await parseFrameworkBody(match[2]);
    frameworks.push({ id, usage, source });
  }

  const descriptionBlocks = description
    ? await parseBlocks(description.split(/\r?\n/), null, new Set())
    : [];

  return {
    slug,
    title: meta.title || slug,
    category: meta.category || 'Components',
    order: Number(meta.order || 99),
    preview: meta.preview || slug,
    summary: meta.summary || '',
    tags: Array.isArray(meta.tags) ? meta.tags : [],
    description,
    descriptionBlocks,
    frameworks,
  };
}

export async function buildComponents(dir) {
  if (!existsSync(dir)) return [];
  const files = readdirSync(dir).filter((f) => f.endsWith('.md')).sort();
  const items = [];
  for (const file of files) {
    const slug = file.replace(/\.md$/, '');
    const raw = readFileSync(join(dir, file), 'utf8');
    items.push(await parseComponentMarkdown(slug, raw));
  }
  items.sort((a, b) => a.order - b.order || a.title.localeCompare(b.title));
  return items;
}
