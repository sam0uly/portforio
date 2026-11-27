/// <reference types="vite/client" />

declare module '*.elm' {
  import type { ElmApp, ElmFlags } from './elm';

  export const Elm: {
    readonly Main: {
      readonly init: (options: { readonly flags: ElmFlags }) => ElmApp;
    };
  };
  export default Elm;
}

declare module 'virtual:blog-posts' {
  import type { BlogPostPayload } from './elm';

  const posts: readonly BlogPostPayload[];
  export default posts;
}

declare module 'virtual:components' {
  import type { ComponentEntryPayload } from './elm';

  const components: readonly ComponentEntryPayload[];
  export default components;
}
