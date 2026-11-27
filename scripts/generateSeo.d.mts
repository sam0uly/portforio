export interface RawBlogPost {
  readonly slug: string;
  readonly title: string;
  readonly description: string;
  readonly date: string;
  readonly tags: readonly string[];
  readonly body: string;
}

export function loadRawBlogPosts(blogDir?: string): readonly RawBlogPost[];
export function generateSeoFiles(rootDir?: string): void;
