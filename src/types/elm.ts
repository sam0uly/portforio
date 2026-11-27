export type PostSlug = string & { readonly __brand: 'PostSlug' };
export type HeadingId = string & { readonly __brand: 'HeadingId' };
export type ThemeName = 'dark' | 'light';

export interface SeoMeta {
  readonly title: string;
  readonly description: string;
  readonly canonical: string;
  readonly ogType: 'website' | 'article';
  readonly ogImage: string;
  readonly ogImageAlt: string;
}

export interface BlogTocItemPayload {
  readonly id: HeadingId;
  readonly text: string;
  readonly level: number;
}

export interface BlogPostPayload {
  readonly slug: PostSlug;
  readonly title: string;
  readonly summary: string;
  readonly dateIso: string;
  readonly readTime: string;
  readonly tags: readonly string[];
  readonly toc: readonly BlogTocItemPayload[];
  readonly blocks: readonly unknown[];
}

export interface ComponentCodePayload {
  readonly lang: string;
  readonly filename: string;
  readonly code: string;
  readonly lines: readonly unknown[];
}

export interface ComponentFrameworkPayload {
  readonly id: 'vue' | 'react' | 'elm';
  readonly usage: ComponentCodePayload | null;
  readonly source: ComponentCodePayload | null;
}

export interface ComponentEntryPayload {
  readonly slug: PostSlug;
  readonly title: string;
  readonly category: string;
  readonly order: number;
  readonly preview: string;
  readonly summary: string;
  readonly tags: readonly string[];
  readonly description: string;
  readonly descriptionBlocks: readonly unknown[];
  readonly frameworks: readonly ComponentFrameworkPayload[];
}

export interface ElmFlags {
  readonly currentYear: string;
  readonly diveDepthMeters: string;
  readonly prefersReducedMotion: boolean;
  readonly blogPosts: readonly BlogPostPayload[];
  readonly components: readonly ComponentEntryPayload[];
}

export interface OutPort<T> {
  readonly subscribe: (callback: (value: T) => void) => void;
  readonly unsubscribe: (callback: (value: T) => void) => void;
}

export interface InPort<T> {
  readonly send: (value: T) => void;
}

export interface ElmPorts {
  readonly copyToClipboard?: OutPort<string>;
  readonly clipboardResult?: InPort<boolean>;
  readonly reducedMotionChanged?: InPort<boolean>;
  readonly setTheme?: OutPort<ThemeName>;
  readonly syncMeta?: OutPort<SeoMeta>;
  readonly resetScroll?: OutPort<null>;
  readonly scrollToHeading?: OutPort<HeadingId>;
  readonly activeHeadingChanged?: InPort<HeadingId>;
  readonly footerVisibilityChanged?: InPort<boolean>;
  readonly playSynthNotes?: OutPort<readonly number[]>;
}

export interface ElmApp {
  readonly ports?: ElmPorts;
}
