import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createHighlighter } from 'shiki';

const DARK_THEME = 'catppuccin-mocha';
const LIGHT_THEME = 'catppuccin-latte';

const LANG_ALIASES = {
  sh: 'bash',
  shell: 'bash',
  zsh: 'bash',
  golang: 'go',
  ts: 'typescript',
  js: 'javascript',
  yml: 'yaml',
  md: 'markdown',
  text: 'text',
  txt: 'text',
  plaintext: 'text',
};

let highlighterPromise = null;
const loadedLangs = new Set(['text']);

function getHighlighter() {
  if (!highlighterPromise) {
    highlighterPromise = createHighlighter({
      themes: [DARK_THEME, LIGHT_THEME],
      langs: ['go', 'bash', 'nix', 'json'],
    }).then((h) => {
      for (const l of ['go', 'bash', 'nix', 'json']) loadedLangs.add(l);
      return h;
    });
  }
  return highlighterPromise;
}

async function highlightCode(code, rawLang) {
  const normalized = String(rawLang || '').trim().toLowerCase();
  const lang = LANG_ALIASES[normalized] || normalized || 'text';
  if (lang === 'text') {
    return code.split('\n').map((line) => (line ? [{ t: line, d: '', l: '' }] : []));
  }

  const highlighter = await getHighlighter();
  if (!loadedLangs.has(lang)) {
    try {
      await highlighter.loadLanguage(lang);
      loadedLangs.add(lang);
    } catch {
      return code.split('\n').map((line) => (line ? [{ t: line, d: '', l: '' }] : []));
    }
  }

  const { tokens } = highlighter.codeToTokens(code, {
    lang,
    themes: { dark: DARK_THEME, light: LIGHT_THEME },
    defaultColor: false,
  });

  return tokens.map((line) => {
    const out = [];
    for (const tok of line) {
      if (!tok.content) continue;
      const d = tok.htmlStyle?.['--shiki-dark'] || '';
      const l = tok.htmlStyle?.['--shiki-light'] || '';
      const prev = out[out.length - 1];
      if (prev && prev.d === d && prev.l === l) {
        prev.t += tok.content;
      } else {
        out.push({ t: tok.content, d, l });
      }
    }
    return out;
  });
}

function slugify(text) {
  return text
    .toLowerCase()
    .replace(/[`*_~]/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');
}

function unescapeMd(str) {
  return str.replace(/\\([\\`*_{}[\]()#+\-.!~|])/g, '$1');
}

function parseFrontmatter(raw) {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { meta: {}, body: raw };

  const lines = match[1].split(/\r?\n/);
  const meta = {};
  let currentKey = null;
  let mode = null;

  for (const line of lines) {
    if (!line.trim()) continue;

    const listMatch = line.match(/^\s+-\s+(.*)$/);
    if (listMatch && currentKey && mode === 'list') {
      meta[currentKey].push(listMatch[1].trim().replace(/^['"]|['"]$/g, ''));
      continue;
    }

    const contMatch = line.match(/^\s+(.+)$/);
    if (contMatch && currentKey && mode === 'scalar') {
      meta[currentKey] = meta[currentKey]
        ? `${meta[currentKey]} ${contMatch[1].trim()}`
        : contMatch[1].trim();
      continue;
    }

    const kvMatch = line.match(/^([a-zA-Z0-9_-]+):\s*(.*)$/);
    if (kvMatch) {
      currentKey = kvMatch[1];
      const val = kvMatch[2].trim();
      if (val === '') {
        meta[currentKey] = currentKey === 'tags' ? [] : '';
        mode = currentKey === 'tags' ? 'list' : 'scalar';
      } else {
        meta[currentKey] = val.replace(/^['"]|['"]$/g, '');
        mode = 'scalar';
      }
    }
  }

  return { meta, body: match[2] };
}

function parseInlines(input) {
  const text = unescapeMd(input);
  const tokens = [];
  let i = 0;

  const pushText = (s) => {
    if (!s) return;
    const prev = tokens[tokens.length - 1];
    if (prev && prev.kind === 'text') prev.text += s;
    else tokens.push({ kind: 'text', text: s });
  };

  while (i < text.length) {
    if (text[i] === '`') {
      const end = text.indexOf('`', i + 1);
      if (end !== -1) {
        tokens.push({ kind: 'code', text: text.slice(i + 1, end) });
        i = end + 1;
        continue;
      }
    }

    if (text[i] === '[') {
      const closeBracket = text.indexOf(']', i + 1);
      if (closeBracket !== -1 && text[closeBracket + 1] === '(') {
        const closeParen = text.indexOf(')', closeBracket + 2);
        if (closeParen !== -1) {
          const label = text.slice(i + 1, closeBracket);
          const href = text.slice(closeBracket + 2, closeParen).trim();
          tokens.push({ kind: 'link', text: label, href });
          i = closeParen + 1;
          continue;
        }
      }
    }

    if (text.startsWith('**_', i)) {
      const end = text.indexOf('_**', i + 3);
      if (end !== -1) {
        tokens.push({ kind: 'strongItalic', text: text.slice(i + 3, end) });
        i = end + 3;
        continue;
      }
    }
    if (text.startsWith('***', i)) {
      const end = text.indexOf('***', i + 3);
      if (end !== -1) {
        tokens.push({ kind: 'strongItalic', text: text.slice(i + 3, end) });
        i = end + 3;
        continue;
      }
    }

    if (text.startsWith('**', i)) {
      const end = text.indexOf('**', i + 2);
      if (end !== -1) {
        const inner = text.slice(i + 2, end);
        if (/^https?:\/\/\S+$/.test(inner)) {
          tokens.push({ kind: 'link', text: inner, href: inner });
        } else {
          tokens.push({ kind: 'strong', text: inner });
        }
        i = end + 2;
        continue;
      }
    }

    if (text.startsWith('~~', i)) {
      const end = text.indexOf('~~', i + 2);
      if (end !== -1) {
        tokens.push({ kind: 'strike', text: text.slice(i + 2, end) });
        i = end + 2;
        continue;
      }
    }

    if (text[i] === '_' && (i === 0 || !/[a-zA-Z0-9]/.test(text[i - 1]))) {
      const end = text.indexOf('_', i + 1);
      if (end !== -1 && (end + 1 === text.length || !/[a-zA-Z0-9]/.test(text[end + 1]))) {
        tokens.push({ kind: 'italic', text: text.slice(i + 1, end) });
        i = end + 1;
        continue;
      }
    }
    if (text[i] === '*' && text[i + 1] !== ' ') {
      const end = text.indexOf('*', i + 1);
      if (end !== -1 && end > i + 1) {
        tokens.push({ kind: 'italic', text: text.slice(i + 1, end) });
        i = end + 1;
        continue;
      }
    }

    pushText(text[i]);
    i += 1;
  }

  return tokens;
}

function parseDirectiveAttrs(raw) {
  const attrs = {};
  const regex = /([a-zA-Z0-9_-]+)="([^"]*)"/g;
  let m;
  while ((m = regex.exec(raw)) !== null) {
    attrs[m[1]] = m[2];
  }
  return attrs;
}

function parseTableRow(line) {
  return line
    .trim()
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map((cell) => parseInlines(cell.trim()));
}

function isTableSeparator(line) {
  return /^\|?(\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?$/.test(line.trim());
}

async function parseBlocks(lines, toc, usedIds) {
  const blocks = [];
  let i = 0;

  while (i < lines.length) {
    const rawLine = lines[i];
    const trimmed = rawLine.trim();

    if (!trimmed) {
      i += 1;
      continue;
    }

    if (/^-{3,}$/.test(trimmed)) {
      blocks.push({ kind: 'hr' });
      i += 1;
      continue;
    }

    const fenceMatch = trimmed.match(/^```([a-zA-Z0-9_-]*)(?:\s+\[([^\]]+)\])?/);
    if (fenceMatch) {
      const lang = fenceMatch[1] || '';
      const filename = fenceMatch[2] || '';
      const codeLines = [];
      i += 1;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.push(lines[i]);
        i += 1;
      }
      if (i < lines.length) i += 1;
      const code = codeLines.join('\n');
      const highlighted = await highlightCode(code, lang);
      blocks.push({ kind: 'code', lang, filename, code, lines: highlighted });
      continue;
    }

    if (trimmed === '::card-group') {
      const cards = [];
      i += 1;
      while (i < lines.length) {
        const cur = lines[i].trim();
        if (cur === '::') {
          i += 1;
          break;
        }
        const cardOpen = cur.match(/^::card(?:\{([^}]*)\})?$/);
        if (cardOpen) {
          const attrs = parseDirectiveAttrs(cardOpen[1] || '');
          const inner = [];
          i += 1;
          while (i < lines.length && lines[i].trim() !== '::') {
            inner.push(lines[i]);
            i += 1;
          }
          if (i < lines.length) i += 1;
          cards.push({
            title: attrs.title || '',
            blocks: await parseBlocks(inner, null, usedIds),
          });
          continue;
        }
        i += 1;
      }
      if (cards.length > 0) blocks.push({ kind: 'cardGroup', cards });
      continue;
    }

    const singleCard = trimmed.match(/^::card(?:\{([^}]*)\})?$/);
    if (singleCard) {
      const attrs = parseDirectiveAttrs(singleCard[1] || '');
      const inner = [];
      i += 1;
      while (i < lines.length && lines[i].trim() !== '::') {
        inner.push(lines[i]);
        i += 1;
      }
      if (i < lines.length) i += 1;
      blocks.push({
        kind: 'cardGroup',
        cards: [{ title: attrs.title || '', blocks: await parseBlocks(inner, null, usedIds) }],
      });
      continue;
    }

    const calloutMatch = trimmed.match(/^::callout(?:\{([^}]*)\})?$/);
    if (calloutMatch) {
      const attrs = parseDirectiveAttrs(calloutMatch[1] || '');
      const inner = [];
      i += 1;
      while (i < lines.length && lines[i].trim() !== '::') {
        inner.push(lines[i]);
        i += 1;
      }
      if (i < lines.length) i += 1;
      blocks.push({
        kind: 'callout',
        variant: attrs.type || 'note',
        blocks: await parseBlocks(inner, null, usedIds),
      });
      continue;
    }

    if (trimmed === '::') {
      i += 1;
      continue;
    }

    const headingMatch = trimmed.match(/^(#{2,6})\s+(.+)$/);
    if (headingMatch) {
      const level = headingMatch[1].length;
      const rawHeading = headingMatch[2].trim();
      const plainText = unescapeMd(
        rawHeading
          .replace(/~~([^~]+)~~/g, '$1')
          .replace(/[*_`]/g, '')
          .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      );
      const baseId = slugify(plainText) || `section-${blocks.length}`;
      const count = usedIds.get(baseId) || 0;
      usedIds.set(baseId, count + 1);
      const id = count === 0 ? baseId : `${baseId}-${count + 1}`;
      if (toc) toc.push({ id, text: plainText, level });
      blocks.push({ kind: 'heading', level, id, inlines: parseInlines(rawHeading) });
      i += 1;
      continue;
    }

    if (trimmed.startsWith('>')) {
      const quoteLines = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        quoteLines.push(lines[i].trim().replace(/^>\s?/, ''));
        i += 1;
      }
      blocks.push({ kind: 'blockquote', inlines: parseInlines(quoteLines.join(' ')) });
      continue;
    }

    if (trimmed.includes('|') && i + 1 < lines.length && isTableSeparator(lines[i + 1])) {
      const headers = parseTableRow(trimmed);
      i += 2;
      const rows = [];
      while (i < lines.length && lines[i].trim().includes('|') && lines[i].trim() !== '') {
        rows.push(parseTableRow(lines[i]));
        i += 1;
      }
      blocks.push({ kind: 'table', headers, rows });
      continue;
    }

    if (/^[-*]\s+/.test(trimmed)) {
      const items = [];
      while (i < lines.length && /^[-*]\s+/.test(lines[i].trim())) {
        items.push(parseInlines(lines[i].trim().replace(/^[-*]\s+/, '')));
        i += 1;
      }
      blocks.push({ kind: 'list', ordered: false, items });
      continue;
    }

    if (/^\d+\.\s+/.test(trimmed)) {
      const items = [];
      while (i < lines.length && /^\d+\.\s+/.test(lines[i].trim())) {
        items.push(parseInlines(lines[i].trim().replace(/^\d+\.\s+/, '')));
        i += 1;
      }
      blocks.push({ kind: 'list', ordered: true, items });
      continue;
    }

    const paraLines = [];
    while (i < lines.length) {
      const t = lines[i].trim();
      if (
        !t ||
        /^-{3,}$/.test(t) ||
        t.startsWith('```') ||
        t.startsWith('::') ||
        /^#{2,6}\s+/.test(t) ||
        t.startsWith('>') ||
        /^[-*]\s+/.test(t) ||
        /^\d+\.\s+/.test(t) ||
        (t.includes('|') && i + 1 < lines.length && isTableSeparator(lines[i + 1]))
      ) {
        break;
      }
      paraLines.push(t);
      i += 1;
    }
    blocks.push({ kind: 'paragraph', inlines: parseInlines(paraLines.join(' ')) });
  }

  return blocks;
}

export async function buildBlogPosts(blogDir) {
  const files = readdirSync(blogDir).filter((f) => f.endsWith('.md')).sort();
  const posts = [];

  for (const file of files) {
    const slug = file.replace(/\.md$/, '');
    const raw = readFileSync(join(blogDir, file), 'utf8');
    const { meta, body } = parseFrontmatter(raw);
    const toc = [];
    const usedIds = new Map();
    const blocks = await parseBlocks(body.split(/\r?\n/), toc, usedIds);
    const words = body.replace(/```[\s\S]*?```/g, ' ').trim().split(/\s+/).filter(Boolean).length;
    const mins = Math.max(1, Math.round(words / 220));
    const dateIso = String(meta.date || '2026-01-01');

    posts.push({
      slug,
      title: meta.title || slug,
      summary: meta.description || '',
      dateIso,
      readTime: `${mins}\u00A0min`,
      tags: Array.isArray(meta.tags) ? meta.tags : [],
      toc,
      blocks,
    });
  }

  posts.sort((a, b) => (a.dateIso < b.dateIso ? 1 : a.dateIso > b.dateIso ? -1 : 0));
  return posts;
}
