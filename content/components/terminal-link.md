---
title: Terminal Action Link
category: Buttons
order: 4
preview: terminal-link
summary: Minimal typographic button & nav variants — bracket keycap, underline draw, dot beacon, slash, and icon chip.
tags:
  - Button
  - Navigation
  - Minimal
---

Five lightweight, surface-free button & navigation link variants inspired by CLI and editorial interfaces: **Bracket Keycap**, **Underline Draw**, **Dot Beacon**, **Minimal Slash**, and **Inset Icon Chip**.

::framework{name="vue"}
### Usage
```vue [Nav.vue]
<script setup lang="ts">
import TerminalLink from './TerminalLink.vue';
</script>

<template>
  <div class="flex flex-wrap items-center gap-4">
    <TerminalLink variant="keycap">Portfolio</TerminalLink>
    <TerminalLink variant="underline">Check PRs →</TerminalLink>
    <TerminalLink variant="beacon">Live</TerminalLink>
    <TerminalLink variant="slash">blog</TerminalLink>
    <TerminalLink variant="chip">Back</TerminalLink>
  </div>
</template>
```

### Source
```vue [TerminalLink.vue]
<script setup lang="ts">
export type TerminalVariant = 'keycap' | 'underline' | 'beacon' | 'slash' | 'chip';

const props = withDefaults(defineProps<{ variant?: TerminalVariant }>(), { variant: 'keycap' });
</script>

<template>
  <button
    type="button"
    :class="[
      'group inline-flex items-center gap-x-1.5 font-mono text-xs text-zinc-400 hover:text-zinc-100 transition-colors duration-150 cursor-pointer',
      props.variant === 'underline' ? 'underline decoration-zinc-600 hover:decoration-zinc-100 underline-offset-4' : '',
    ]"
  >
    <span v-if="variant === 'keycap'" class="text-zinc-600 group-hover:text-zinc-300">[</span>
    <span v-if="variant === 'beacon'" class="size-1.5 rounded-full bg-[#c2b4ff]" />
    <span v-if="variant === 'slash'" class="text-zinc-600">/</span>
    <span v-if="variant === 'chip'" class="inline-flex items-center justify-center size-5 rounded-md bg-zinc-800 text-zinc-200 transition-transform group-hover:-translate-x-0.5">←</span>
    <span><slot /></span>
    <span v-if="variant === 'keycap'" class="text-zinc-600 group-hover:text-zinc-300">]</span>
  </button>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Nav.tsx]
import { TerminalLink } from './TerminalLink';

export function Nav() {
  return (
    <div className="flex flex-wrap items-center gap-4">
      <TerminalLink variant="keycap">Portfolio</TerminalLink>
      <TerminalLink variant="underline">Check PRs →</TerminalLink>
      <TerminalLink variant="beacon">Live</TerminalLink>
      <TerminalLink variant="slash">blog</TerminalLink>
      <TerminalLink variant="chip">Back</TerminalLink>
    </div>
  );
}
```

### Source
```tsx [TerminalLink.tsx]
import type { ButtonHTMLAttributes, ReactNode } from 'react';

export type TerminalVariant = 'keycap' | 'underline' | 'beacon' | 'slash' | 'chip';

export function TerminalLink({
  variant = 'keycap',
  children,
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: TerminalVariant; children: ReactNode }) {
  return (
    <button
      type="button"
      {...props}
      className={`group inline-flex items-center gap-x-1.5 font-mono text-xs text-zinc-400 hover:text-zinc-100 transition-colors duration-150 cursor-pointer ${
        variant === 'underline' ? 'underline decoration-zinc-600 hover:decoration-zinc-100 underline-offset-4' : ''
      } ${className}`}
    >
      {variant === 'keycap' && <span className="text-zinc-600 group-hover:text-zinc-300">[</span>}
      {variant === 'beacon' && <span className="size-1.5 rounded-full bg-[#c2b4ff]" />}
      {variant === 'slash' && <span className="text-zinc-600">/</span>}
      {variant === 'chip' && (
        <span className="inline-flex items-center justify-center size-5 rounded-md bg-zinc-800 text-zinc-200 transition-transform group-hover:-translate-x-0.5">←</span>
      )}
      <span>{children}</span>
      {variant === 'keycap' && <span className="text-zinc-600 group-hover:text-zinc-300">]</span>}
    </button>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Nav.elm]
viewNav : msg -> Html msg
viewNav onClick =
    div [ Attr.class "flex flex-wrap items-center gap-4" ]
        [ TerminalLink.view TerminalLink.Keycap onClick "Portfolio"
        , TerminalLink.view TerminalLink.Underline onClick "Check PRs →"
        , TerminalLink.view TerminalLink.Beacon onClick "Live"
        , TerminalLink.view TerminalLink.Slash onClick "blog"
        ]
```

### Source
```elm [TerminalLink.elm]
module TerminalLink exposing (Variant(..), view)

import Html exposing (Html, button, span, text)
import Html.Attributes as Attr
import Html.Events as Events


type Variant
    = Keycap
    | Underline
    | Beacon
    | Slash
    | Chip


view : Variant -> msg -> String -> Html msg
view variant onClick label =
    let
        base =
            "group inline-flex items-center gap-x-1.5 font-mono text-xs text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 cursor-pointer"
    in
    button
        [ Attr.type_ "button"
        , Events.onClick onClick
        , Attr.class
            (if variant == Underline then
                base ++ " underline decoration-current/35 hover:decoration-current underline-offset-4"

             else
                base
            )
        ]
        (case variant of
            Keycap ->
                [ span [ Attr.class "text-[var(--page-subtle)]" ] [ text "[" ], text label, span [ Attr.class "text-[var(--page-subtle)]" ] [ text "]" ] ]

            Beacon ->
                [ span [ Attr.class "size-1.5 rounded-full bg-[var(--callout-note-bg)]" ] [], text label ]

            Slash ->
                [ span [ Attr.class "text-[var(--page-subtle)]" ] [ text "/" ], text label ]

            Chip ->
                [ span [ Attr.class "inline-flex items-center justify-center size-5 btn-squircle bg-[var(--tab-bg)] text-[var(--page-fg)]" ] [ text "←" ], text label ]

            Underline ->
                [ text label ]
        )
```
::
