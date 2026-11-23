import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const SITE = 'https://portforio.samouly.fun';
const ROOT = process.cwd();
const BLOG_DIR = resolve(ROOT, 'content/blog');
const PUBLIC_DIR = resolve(ROOT, 'public');

function parseFrontmatter(raw) {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { meta: {}, body: raw };
  const lines = match[1].split(/\r?\n/);
  const meta = {};
  let key = null;
  let mode = null;
  for (const line of lines) {
    if (!line.trim()) continue;
    const listMatch = line.match(/^\s+-\s+(.*)$/);
    if (listMatch && key && mode === 'list') {
      meta[key].push(listMatch[1].trim().replace(/^['"]|['"]$/g, ''));
      continue;
    }
    const contMatch = line.match(/^\s+(.+)$/);
    if (contMatch && key && mode === 'scalar') {
      meta[key] = meta[key] ? `${meta[key]} ${contMatch[1].trim()}` : contMatch[1].trim();
      continue;
    }
    const kv = line.match(/^([a-zA-Z0-9_-]+):\s*(.*)$/);
    if (kv) {
      key = kv[1];
      const val = kv[2].trim();
      if (val === '') {
        meta[key] = key === 'tags' ? [] : '';
        mode = key === 'tags' ? 'list' : 'scalar';
      } else {
        meta[key] = val.replace(/^['"]|['"]$/g, '');
        mode = 'scalar';
      }
    }
  }
  return { meta, body: match[2].trim() };
}

function cleanMdcForLlms(markdown) {
  return markdown
    .replace(/^::card-group\s*$/gm, '')
    .replace(/^::card\{title="([^"]+)"\}\s*$/gm, '#### $1')
    .replace(/^::card\s*$/gm, '')
    .replace(/^::callout\{type="([^"]+)"\}\s*$/gm, (_, t) => `> **${t.toUpperCase()}**:`)
    .replace(/^::callout\s*$/gm, '> **NOTE**:')
    .replace(/^::\s*$/gm, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

export function loadRawBlogPosts(blogDir = BLOG_DIR) {
  const files = readdirSync(blogDir).filter((f) => f.endsWith('.md')).sort();
  const posts = files.map((file) => {
    const slug = file.replace(/\.md$/, '');
    const raw = readFileSync(join(blogDir, file), 'utf8');
    const { meta, body } = parseFrontmatter(raw);
    return {
      slug,
      title: meta.title || slug,
      description: meta.description || '',
      date: String(meta.date || '2026-01-01'),
      tags: Array.isArray(meta.tags) ? meta.tags : [],
      body,
    };
  });
  posts.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));
  return posts;
}

export function generateSeoFiles(rootDir = ROOT) {
  const blogDir = resolve(rootDir, 'content/blog');
  const publicDir = resolve(rootDir, 'public');
  const posts = loadRawBlogPosts(blogDir);
  const latestDate = posts[0]?.date || '2026-11-22';

  // 1. public/sitemap.xml
  const urls = [
    { loc: `${SITE}/`, lastmod: latestDate, changefreq: 'weekly', priority: '1.0' },
    { loc: `${SITE}/blog`, lastmod: latestDate, changefreq: 'weekly', priority: '0.9' },
    ...posts.map((p) => ({
      loc: `${SITE}/blog/${p.slug}`,
      lastmod: p.date,
      changefreq: 'monthly',
      priority: '0.8',
    })),
    { loc: `${SITE}/llms.txt`, lastmod: latestDate, changefreq: 'monthly', priority: '0.7' },
    { loc: `${SITE}/llms-full.txt`, lastmod: latestDate, changefreq: 'monthly', priority: '0.7' },
  ];
  const sitemapXml =
    `<?xml version="1.0" encoding="UTF-8"?>\n` +
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
    urls
      .map(
        (u) =>
          `  <url>\n` +
          `    <loc>${u.loc}</loc>\n` +
          `    <lastmod>${u.lastmod}</lastmod>\n` +
          `    <changefreq>${u.changefreq}</changefreq>\n` +
          `    <priority>${u.priority}</priority>\n` +
          `  </url>`
      )
      .join('\n') +
    `\n</urlset>\n`;
  writeFileSync(join(publicDir, 'sitemap.xml'), sitemapXml, 'utf8');

  // 2. public/llms.txt
  const llmsTxt = `# Alaa El-Samouly (Samouly)

> Official portfolio and technical blog of Alaa El-Samouly (also known as Samouly, sam0uly, Dev Alaa, Dev Samouly, and Software Engineer Samouly), an Egyptian software engineer at Charm specializing in Go terminal user interfaces (TUIs), developer CLI tooling, NixOS/Linux desktop systems, and modern web engineering.

## Identity

- **Full Name**: Alaa El-Samouly
- **Handles / Aliases**: Samouly, sam0uly, Dev Alaa, Dev Samouly, Software Engineer Samouly
- **Role**: Software Engineer at [Charm](https://charm.land)
- **Location**: Egypt
- **Primary Languages & Stack**: Go, Bubble Tea, Lip Gloss, Elm, WebGL, Nuxt, Vue, TypeScript, Tailwind CSS, NixOS, Hyprland, Lua (Neovim)

## Selected Projects

- [Twig](https://github.com/sam0uly/twig): Live diff viewer for working trees bigger than your screen (Go, currently building)
- [mural](https://github.com/sam0uly/mural): Terminal wallpaper manager with a built-in pure Go Wayland daemon (Go, TUI)
- [Spin](https://spincli.pages.dev): Language-agnostic CLI for generating and sharing reusable project templates (Go)
- [bubbleMonitor](https://github.com/sam0uly/bubbleMonitor): Terminal system monitor built with Bubble Tea (Go, TUI)
- [Mditor](https://github.com/sam0uly/mditor): Terminal markdown editor on Charm libraries (Go, Charm)
- [HyprLuna](https://github.com/Lunaris-Project/HyprLuna): Arch Linux desktop shell for Hyprland and Ags widgets
- [Samouly Flake](https://github.com/sam0uly/samouly-flake): Declarative NixOS configuration for Hyprland and Niri compositors
- [SamoulyVim](https://github.com/sam0uly/SamoulyVim): Personal Neovim configuration written in Lua

## Blog Articles

${posts.map((p) => `- [${p.title}](${SITE}/blog/${p.slug}) (${p.date}): ${p.description}`).join('\n')}

## Links & Contact

- [Portfolio](${SITE}/)
- [Blog](${SITE}/blog)
- [Full AI Context (includes complete blog articles)](${SITE}/llms-full.txt)
- [Main Site](https://samouly.fun/)
- [GitHub](https://github.com/sam0uly)
- [X (Twitter)](https://x.com/sam0uly)
- [Charm](https://charm.land)
- [Email](mailto:alasamouly@gmail.com)
`;
  writeFileSync(join(publicDir, 'llms.txt'), llmsTxt, 'utf8');

  // 3. public/llms-full.txt
  const blogSection = posts
    .map(
      (p) =>
        `### ${p.title}\n\n` +
        `- **URL**: ${SITE}/blog/${p.slug}\n` +
        `- **Date**: ${p.date}\n` +
        `- **Tags**: ${p.tags.join(', ')}\n` +
        `- **Summary**: ${p.description}\n\n` +
        `${cleanMdcForLlms(p.body)}`
    )
    .join('\n\n---\n\n');

  const llmsFullTxt = `# Alaa El-Samouly (Samouly) - Complete Profile, Projects & Blog Articles

## Summary

Alaa El-Samouly (commonly searched as **Samouly**, **sam0uly**, **Alaa**, **Dev Alaa**, **Dev Samouly**, or **Software Engineer Samouly**) is a software engineer from Egypt working at **Charm** (https://charm.land). He specializes in building expressive terminal user interfaces (TUIs) and command-line developer tools in **Go** (using Bubble Tea, Lip Gloss, Bubbles, and Huh), declarative Linux/NixOS desktop environments, and fast interactive web applications with **Elm**, **Nuxt**, **Vue**, **TypeScript**, and **Tailwind CSS**.

## Work & Engineering Focus

- **Current Employer**: Charm (https://charm.land) - Software Engineer
- **Terminal & CLI Engineering**: Go, Bubble Tea, Lip Gloss, terminal graphics, Wayland daemons, developer productivity tooling
- **Web Engineering**: Elm (including Elm WebGL GLSL shaders), Nuxt, Vue, TypeScript, Tailwind CSS v4, Web Interface Guidelines & accessibility
- **Linux & Systems**: NixOS, Nix Flakes, Home Manager, Hyprland, Niri, Arch Linux, Neovim (Lua)
- **Outside Software**: Tennis, freediving to 35 meters, bird hunting, and motorcycle touring on a Lifan KPV150.

## Open-Source Projects

### 1. Twig
- **Repository**: https://github.com/sam0uly/twig
- **Stack**: Go, TUI
- **Status**: Actively building
- **Description**: A live diff viewer designed for working trees bigger than your screen.

### 2. mural
- **Repository**: https://github.com/sam0uly/mural
- **Install**: \`go install github.com/sam0uly/mural@latest\`
- **Stack**: Go, TUI, Wayland
- **Description**: A terminal wallpaper manager that browses wallpaper directories as a responsive grid of in-terminal thumbnails and applies them with its own built-in pure Go Wayland wallpaper daemon (with fallbacks for Hyprland, Sway, GNOME, KDE Plasma, macOS, and Windows).

### 3. Spin
- **Website**: https://spincli.pages.dev
- **Repository**: https://github.com/sam0uly/spin
- **Stack**: Go, Bubble Tea, Lip Gloss, Bubbles, Huh
- **Description**: Framework-agnostic and language-agnostic CLI scaffolding tool for building, sharing, and generating reusable project templates.

### 4. bubbleMonitor (bub)
- **Repository**: https://github.com/sam0uly/bubbleMonitor
- **Stack**: Go, Bubble Tea, Lip Gloss, Bubbles
- **Description**: Feature-rich terminal system monitor displaying CPU, memory, disk, network stats, and live processes.

### 5. Mditor
- **Repository**: https://github.com/sam0uly/mditor
- **Stack**: Go, Charmbracelet ecosystem
- **Description**: Terminal-based markdown editor written in Go using Charm libraries.

### 6. HyprLuna
- **Repository**: https://github.com/Lunaris-Project/HyprLuna
- **Stack**: Arch Linux, Hyprland, Ags, Bash, JavaScript, SCSS
- **Description**: Full Arch Linux desktop environment shell pairing custom Hyprland configuration with Ags widgets and complete dotfiles.

### 7. Samouly Flake
- **Repository**: https://github.com/sam0uly/samouly-flake
- **Stack**: Nix, NixOS, Home Manager, Flakes, Hyprland, Niri
- **Description**: Reproducible, declarative NixOS system configuration supporting Hyprland and Niri compositors.

### 8. SamoulyVim
- **Repository**: https://github.com/sam0uly/SamoulyVim
- **Stack**: Lua, Neovim
- **Description**: Personal Neovim configuration written in Lua.

## Blog Articles (Full Text)

${blogSection}

## Contact & Verification

- **Email**: alasamouly@gmail.com (typically replies within 24 hours)
- **Portfolio**: ${SITE}/
- **Blog**: ${SITE}/blog
- **Main Site**: https://samouly.fun/
- **GitHub**: https://github.com/sam0uly
- **X (Twitter)**: https://x.com/sam0uly
- **Company**: https://charm.land
`;
  writeFileSync(join(publicDir, 'llms-full.txt'), llmsFullTxt, 'utf8');
}

if (import.meta.url === `file://${process.argv[1]}`) {
  generateSeoFiles();
}
