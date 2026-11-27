import type { BlogPostPayload } from '../src/types/elm';

export function buildBlogPosts(blogDir: string): Promise<readonly BlogPostPayload[]>;
