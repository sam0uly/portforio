---
title: Code Block & Morph Copy
category: Blog
order: 9
preview: code-block
summary: Squircle syntax-highlighted code surface with Bayer filename badge and animated copy-to-checkmark icon.
tags:
  - Blog
  - Code
  - Clipboard
---

The blog post code block component. Pairs a Bayer-dithered filename tag with a `size-8` squircle copy button whose clipboard icon smoothly rotates and morphs into a drawn SVG checkmark on click.

::framework{name="vue"}
### Usage
```vue [Post.vue]
<script setup lang="ts">
import CodeBlock from './CodeBlock.vue';
</script>

<template>
  <CodeBlock filename="main.go" code="package main\n\nfunc main() {}" />
</template>
```

### Source
```vue [CodeBlock.vue]
<script setup lang="ts">
import { ref } from 'vue';

const props = defineProps<{ filename: string; code: string }>();
const copied = ref(false);

async function copy() {
  await navigator.clipboard.writeText(props.code);
  copied.value = true;
  setTimeout(() => (copied.value = false), 1800);
}
</script>

<template>
  <div class="rounded-[14px] bg-zinc-950 overflow-hidden">
    <div class="flex items-center justify-between pl-4 pr-2.5 pt-2.5 pb-1">
      <span class="px-2 py-0.5 bg-zinc-800 font-mono text-[10px] text-zinc-200">{{ filename }}</span>
      <button
        type="button"
        @click="copy"
        class="inline-flex items-center justify-center size-8 rounded-[10px] text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800/80 transition-colors cursor-pointer"
        :aria-label="copied ? 'Copied' : 'Copy code'"
      >
        <svg viewBox="0 0 16 16" fill="none" class="size-3.5 overflow-visible" aria-hidden="true">
          <g :class="['origin-center transition-all duration-300', copied ? 'scale-75 -rotate-12 opacity-0' : 'scale-100 opacity-100']">
            <rect x="5.75" y="5.75" width="7.5" height="7.5" rx="1.75" stroke="currentColor" stroke-width="1.45" />
            <path d="M3.75 10.25H3.5A1.75 1.75 0 0 1 1.75 8.5V3.5A1.75 1.75 0 0 1 3.5 1.75h5A1.75 1.75 0 0 1 10.25 3.5v.25" stroke="currentColor" stroke-width="1.45" stroke-linecap="round" />
          </g>
          <path
            d="M3.5 8.6L6.4 11.4L12.5 4.6"
            stroke="currentColor"
            stroke-width="1.7"
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-dasharray="16"
            :stroke-dashoffset="copied ? 0 : 16"
            :class="['transition-all duration-300', copied ? 'opacity-100 delay-75' : 'opacity-0']"
          />
        </svg>
      </button>
    </div>
    <pre class="pt-2 pb-4 px-4 overflow-x-auto font-mono text-[13px] leading-[1.7] text-zinc-100"><code>{{ code }}</code></pre>
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Post.tsx]
import { CodeBlock } from './CodeBlock';

export function Post() {
  return <CodeBlock filename="main.go" code={'package main\n\nfunc main() {}'} />;
}
```

### Source
```tsx [CodeBlock.tsx]
import { useState } from 'react';

export function CodeBlock({ filename, code }: { filename: string; code: string }) {
  const [copied, setCopied] = useState(false);

  const onCopy = async () => {
    await navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 1800);
  };

  return (
    <div className="rounded-[14px] bg-zinc-950 overflow-hidden">
      <div className="flex items-center justify-between pl-4 pr-2.5 pt-2.5 pb-1">
        <span className="px-2 py-0.5 bg-zinc-800 font-mono text-[10px] text-zinc-200">{filename}</span>
        <button
          type="button"
          onClick={onCopy}
          aria-label={copied ? 'Copied' : 'Copy code'}
          className="inline-flex items-center justify-center size-8 rounded-[10px] text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800/80 transition-colors cursor-pointer"
        >
          <svg viewBox="0 0 16 16" fill="none" className="size-3.5 overflow-visible" aria-hidden="true">
            <g className={`origin-center transition-all duration-300 ${copied ? 'scale-75 -rotate-12 opacity-0' : 'scale-100 opacity-100'}`}>
              <rect x="5.75" y="5.75" width="7.5" height="7.5" rx="1.75" stroke="currentColor" strokeWidth="1.45" />
              <path d="M3.75 10.25H3.5A1.75 1.75 0 0 1 1.75 8.5V3.5A1.75 1.75 0 0 1 3.5 1.75h5A1.75 1.75 0 0 1 10.25 3.5v.25" stroke="currentColor" strokeWidth="1.45" strokeLinecap="round" />
            </g>
            <path
              d="M3.5 8.6L6.4 11.4L12.5 4.6"
              stroke="currentColor"
              strokeWidth="1.7"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeDasharray={16}
              strokeDashoffset={copied ? 0 : 16}
              className={`transition-all duration-300 ${copied ? 'opacity-100 delay-75' : 'opacity-0'}`}
            />
          </svg>
        </button>
      </div>
      <pre className="pt-2 pb-4 px-4 overflow-x-auto font-mono text-[13px] leading-[1.7] text-zinc-100">
        <code>{code}</code>
      </pre>
    </div>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Post.elm]
viewCode : Bool -> Html Msg
viewCode isCopied =
    CodeBlock.view CopyCode isCopied "main.go" "package main\n\nfunc main() {}"
```

### Source
```elm [CodeBlock.elm]
module CodeBlock exposing (view)

import Html exposing (Html, button, code, div, pre, span, text)
import Html.Attributes as Attr
import Html.Events as Events


view : (String -> msg) -> Bool -> String -> String -> Html msg
view onCopy isCopied filename snippet =
    div [ Attr.class "box-squircle bg-[var(--code-bg)] overflow-hidden" ]
        [ div [ Attr.class "flex items-center justify-between pl-4 pr-2.5 pt-2.5 pb-1" ]
            [ span [ Attr.class "px-2 py-0.5 bg-[var(--tab-bg)] font-mono text-[10px] text-[var(--tab-fg)]" ] [ text filename ]
            , button
                [ Attr.type_ "button"
                , Events.onClick (onCopy snippet)
                , Attr.class "inline-flex items-center justify-center size-8 btn-squircle text-[var(--page-subtle)] hover:text-[var(--page-fg)] hover:bg-[var(--tab-bg)]/80"
                ]
                [ text (if isCopied then "✓" else "Copy") ]
            ]
        , pre [ Attr.class "pt-2 pb-4 px-4 overflow-x-auto font-mono text-[13px] leading-[1.7]" ]
            [ code [] [ text snippet ] ]
        ]
```
::
