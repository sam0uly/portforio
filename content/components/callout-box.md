---
title: Callout Box
category: Blog
order: 8
preview: callout-box
summary: Borderless squircle callout with pastel Bayer badges for Note, Tip, Warning, and Important blocks.
tags:
  - Blog
  - Callout
  - Pastel
---

Used throughout the blog posts to highlight key takeaways, warnings, and tips. Combines a soft tinted squircle container with a crisp pastel Bayer-dithered label badge (`Note` violet, `Tip` mint, `Warning` peach).

::framework{name="vue"}
### Usage
```vue [Article.vue]
<script setup lang="ts">
import CalloutBox from './CalloutBox.vue';
</script>

<template>
  <CalloutBox variant="tip" label="Tip">
    Prefer opaque custom types in Elm so invalid states cannot be constructed.
  </CalloutBox>
</template>
```

### Source
```vue [CalloutBox.vue]
<script setup lang="ts">
const VARIANTS = {
  note: { bg: '#c2b4ff', fg: '#140f24' },
  tip: { bg: '#8ce6ba', fg: '#0b2117' },
  warn: { bg: '#ffc48a', fg: '#261405' },
} as const;

const props = withDefaults(
  defineProps<{ variant?: keyof typeof VARIANTS; label?: string }>(),
  { variant: 'note', label: 'Note' }
);
</script>

<template>
  <aside class="rounded-[14px] bg-zinc-900/65 p-4 space-y-2.5">
    <span class="inline-flex items-stretch h-[20px] font-mono text-[10px] tracking-[0.08em]">
      <span
        class="inline-flex items-center pl-2 pr-1.5 leading-none font-medium"
        :style="{ backgroundColor: VARIANTS[props.variant].bg, color: VARIANTS[props.variant].fg }"
      >
        {{ label }}
      </span>
    </span>
    <div class="text-sm leading-relaxed text-zinc-300">
      <slot />
    </div>
  </aside>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Article.tsx]
import { CalloutBox } from './CalloutBox';

export function Article() {
  return (
    <CalloutBox variant="tip" label="Tip">
      Prefer opaque custom types in Elm so invalid states cannot be constructed.
    </CalloutBox>
  );
}
```

### Source
```tsx [CalloutBox.tsx]
import type { ReactNode } from 'react';

const VARIANTS = {
  note: { bg: '#c2b4ff', fg: '#140f24' },
  tip: { bg: '#8ce6ba', fg: '#0b2117' },
  warn: { bg: '#ffc48a', fg: '#261405' },
} as const;

export function CalloutBox({
  variant = 'note',
  label = 'Note',
  children,
}: {
  variant?: keyof typeof VARIANTS;
  label?: string;
  children: ReactNode;
}) {
  const { bg, fg } = VARIANTS[variant];
  return (
    <aside className="rounded-[14px] bg-zinc-900/65 p-4 space-y-2.5">
      <span className="inline-flex items-stretch h-[20px] font-mono text-[10px] tracking-[0.08em]">
        <span className="inline-flex items-center pl-2 pr-1.5 leading-none font-medium" style={{ backgroundColor: bg, color: fg }}>
          {label}
        </span>
      </span>
      <div className="text-sm leading-relaxed text-zinc-300">{children}</div>
    </aside>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Article.elm]
viewTip : Html msg
viewTip =
    CalloutBox.view CalloutBox.Tip "Tip"
        [ p [] [ text "Prefer opaque custom types in Elm so invalid states cannot be constructed." ] ]
```

### Source
```elm [CalloutBox.elm]
module CalloutBox exposing (Variant(..), view)

import Html exposing (Html, aside, div, span, text)
import Html.Attributes as Attr


type Variant
    = Note
    | Tip
    | Warn


view : Variant -> String -> List (Html msg) -> Html msg
view variant label children =
    let
        ( bg, fg ) =
            case variant of
                Note ->
                    ( "var(--callout-note-bg)", "var(--callout-note-fg)" )

                Tip ->
                    ( "var(--callout-tip-bg)", "var(--callout-tip-fg)" )

                Warn ->
                    ( "var(--callout-warn-bg)", "var(--callout-warn-fg)" )
    in
    aside [ Attr.class "box-squircle bg-[var(--tab-bg)]/55 p-4 space-y-2.5" ]
        [ span
            [ Attr.class "inline-flex items-center h-[20px] px-2 font-mono text-[10px] font-medium"
            , Attr.style "background-color" bg
            , Attr.style "color" fg
            ]
            [ text label ]
        , div [ Attr.class "text-sm leading-relaxed text-[var(--page-muted)]" ] children
        ]
```
::
