---
title: Progressive Blur
category: Effects
order: 6
preview: progressive-blur
summary: Multi-layer masked backdrop-filter blur (1.5px -> 5px -> 12px) that melts scrolling content cleanly into any edge.
tags:
  - Blur
  - CSS
  - Scroll
---

A 3-step progressive backdrop blur used at the top and bottom edges of the main sheet, TOC wing, and PR wing. Instead of a harsh uniform frosted bar, three overlapping `backdrop-filter` bands (`1.5px`, `5px`, `12px`) with stepped `mask-image` gradients smoothly ramp blur intensity toward the edge, topped with a subtle tint fade.

::framework{name="vue"}
### Usage
```vue [ScrollCard.vue]
<script setup lang="ts">
import ProgressiveBlur from './ProgressiveBlur.vue';
</script>

<template>
  <div class="relative h-64 rounded-[16px] bg-zinc-950 overflow-hidden">
    <div class="h-full overflow-y-auto px-4 py-10 space-y-3">
      <p v-for="i in 12" :key="i" class="text-sm text-zinc-300">Row {{ i }} — scrolling content</p>
    </div>
    <ProgressiveBlur position="top" class="h-14 text-zinc-950" />
    <ProgressiveBlur position="bottom" class="h-14 text-zinc-950" />
  </div>
</template>
```

### Source
```vue [ProgressiveBlur.vue]
<script setup lang="ts">
const props = withDefaults(defineProps<{ position?: 'top' | 'bottom' }>(), {
  position: 'top',
});
</script>

<template>
  <div
    aria-hidden="true"
    :class="[
      'pointer-events-none select-none absolute inset-x-0 z-20',
      props.position === 'top' ? 'top-0' : 'bottom-0',
    ]"
    :style="{ '--dir': props.position === 'top' ? 'to top' : 'to bottom' }"
  >
    <span
      class="absolute inset-0 backdrop-blur-[1.5px]"
      style="mask-image: linear-gradient(var(--dir), transparent 0%, #000 28%, #000 58%, transparent 82%)"
    />
    <span
      class="absolute inset-0 backdrop-blur-[5px]"
      style="mask-image: linear-gradient(var(--dir), transparent 28%, #000 58%, #000 84%, transparent 100%)"
    />
    <span
      class="absolute inset-0 backdrop-blur-[12px]"
      style="mask-image: linear-gradient(var(--dir), transparent 56%, #000 82%, #000 100%)"
    />
    <span
      class="absolute inset-0"
      style="background: linear-gradient(var(--dir), transparent 0%, color-mix(in srgb, currentColor 35%, transparent) 55%, currentColor 100%)"
    />
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [ScrollCard.tsx]
import { ProgressiveBlur } from './ProgressiveBlur';

export function ScrollCard() {
  return (
    <div className="relative h-64 rounded-[16px] bg-zinc-950 overflow-hidden">
      <div className="h-full overflow-y-auto px-4 py-10 space-y-3">
        {Array.from({ length: 12 }, (_, i) => (
          <p key={i} className="text-sm text-zinc-300">Row {i + 1} — scrolling content</p>
        ))}
      </div>
      <ProgressiveBlur position="top" className="h-14 text-zinc-950" />
      <ProgressiveBlur position="bottom" className="h-14 text-zinc-950" />
    </div>
  );
}
```

### Source
```tsx [ProgressiveBlur.tsx]
export function ProgressiveBlur({
  position = 'top',
  className = 'h-16 text-zinc-950',
}: {
  position?: 'top' | 'bottom';
  className?: string;
}) {
  const dir = position === 'top' ? 'to top' : 'to bottom';
  return (
    <div
      aria-hidden="true"
      className={`pointer-events-none select-none absolute inset-x-0 z-20 ${
        position === 'top' ? 'top-0' : 'bottom-0'
      } ${className}`}
    >
      <span
        className="absolute inset-0 backdrop-blur-[1.5px]"
        style={{ maskImage: `linear-gradient(${dir}, transparent 0%, #000 28%, #000 58%, transparent 82%)` }}
      />
      <span
        className="absolute inset-0 backdrop-blur-[5px]"
        style={{ maskImage: `linear-gradient(${dir}, transparent 28%, #000 58%, #000 84%, transparent 100%)` }}
      />
      <span
        className="absolute inset-0 backdrop-blur-[12px]"
        style={{ maskImage: `linear-gradient(${dir}, transparent 56%, #000 82%, #000 100%)` }}
      />
      <span
        className="absolute inset-0"
        style={{ background: `linear-gradient(${dir}, transparent 0%, color-mix(in srgb, currentColor 35%, transparent) 55%, currentColor 100%)` }}
      />
    </div>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [ScrollCard.elm]
viewScrollCard : Html msg
viewScrollCard =
    div [ Attr.class "relative h-64 box-squircle bg-[var(--page-bg)] overflow-hidden" ]
        [ div [ Attr.class "h-full overflow-y-auto px-4 py-10 space-y-2" ] items
        , ProgressiveBlur.view ProgressiveBlur.Top "h-14"
        , ProgressiveBlur.view ProgressiveBlur.Bottom "h-14"
        ]
```

### Source
```elm [ProgressiveBlur.elm]
module ProgressiveBlur exposing (Edge(..), view)

import Html exposing (Html, div, node)
import Html.Attributes as Attr


type Edge
    = Top
    | Bottom


view : Edge -> String -> Html msg
view edge heightClass =
    let
        edgeClass =
            case edge of
                Top ->
                    "top-0 pblur"

                Bottom ->
                    "bottom-0 pblur pblur-bottom"
    in
    div
        [ Attr.attribute "aria-hidden" "true"
        , Attr.class ("pointer-events-none select-none absolute inset-x-0 z-20 " ++ heightClass ++ " " ++ edgeClass)
        ]
        [ node "i" [] [], node "i" [] [] ]
```
::
