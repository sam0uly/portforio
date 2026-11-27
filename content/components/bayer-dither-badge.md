---
title: Bayer Dither Badge
category: Badges
order: 3
preview: bayer-dither-badge
summary: Crisp mono pill with a pixel-accurate 6x6 Bayer dither tail in pastel violet, mint, peach, or neutral.
tags:
  - Badge
  - SVG
  - Dither
---

The signature badge component used across section tabs, blog callouts, project tags, and OG cards. The right edge fades out through a 6×6 ordered Bayer pixel tail rendered with `shape-rendering="crispEdges"` so it stays razor-sharp at any DPI.

::framework{name="vue"}
### Usage
```vue [Card.vue]
<script setup lang="ts">
import BayerBadge from './BayerBadge.vue';
</script>

<template>
  <div class="flex flex-wrap gap-2">
    <BayerBadge tone="violet">Building</BayerBadge>
    <BayerBadge tone="mint">Go · TUI</BayerBadge>
    <BayerBadge tone="peach">NixOS</BayerBadge>
  </div>
</template>
```

### Source
```vue [BayerBadge.vue]
<script setup lang="ts">
const TONES = {
  violet: { bg: '#c2b4ff', fg: '#140f24' },
  mint: { bg: '#8ce6ba', fg: '#0b2117' },
  peach: { bg: '#ffc48a', fg: '#261405' },
  neutral: { bg: '#1e1e24', fg: '#e4e4ea' },
} as const;

const props = withDefaults(defineProps<{ tone?: keyof typeof TONES }>(), {
  tone: 'violet',
});
</script>

<template>
  <span class="inline-flex items-stretch h-[20px] font-mono text-[10px] tracking-[0.06em] shrink-0">
    <span
      class="inline-flex items-center pl-2 pr-1.5 leading-none font-medium"
      :style="{ backgroundColor: TONES[props.tone].bg, color: TONES[props.tone].fg }"
    >
      <slot />
    </span>
    <span class="inline-flex items-stretch" :style="{ color: TONES[props.tone].bg }">
      <svg viewBox="0 0 6 6" preserveAspectRatio="none" class="block w-4 h-full -ml-px" shape-rendering="crispEdges" aria-hidden="true">
        <rect x="0" y="0" width="1" height="6" fill="currentColor" />
        <rect x="1" y="0" width="1" height="2" fill="currentColor" />
        <rect x="1" y="3" width="1" height="2" fill="currentColor" />
        <rect x="2" y="1" width="1" height="1" fill="currentColor" />
        <rect x="2" y="3" width="1" height="1" fill="currentColor" />
        <rect x="2" y="5" width="1" height="1" fill="currentColor" />
        <rect x="3" y="0" width="1" height="1" fill="currentColor" />
        <rect x="3" y="2" width="1" height="1" fill="currentColor" />
        <rect x="3" y="4" width="1" height="1" fill="currentColor" />
        <rect x="4" y="1" width="1" height="1" fill="currentColor" />
        <rect x="4" y="5" width="1" height="1" fill="currentColor" />
        <rect x="5" y="3" width="1" height="1" fill="currentColor" />
      </svg>
    </span>
  </span>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Card.tsx]
import { BayerBadge } from './BayerBadge';

export function Card() {
  return (
    <div className="flex flex-wrap gap-2">
      <BayerBadge tone="violet">Building</BayerBadge>
      <BayerBadge tone="mint">Go · TUI</BayerBadge>
      <BayerBadge tone="peach">NixOS</BayerBadge>
    </div>
  );
}
```

### Source
```tsx [BayerBadge.tsx]
import type { ReactNode } from 'react';

const TONES = {
  violet: { bg: '#c2b4ff', fg: '#140f24' },
  mint: { bg: '#8ce6ba', fg: '#0b2117' },
  peach: { bg: '#ffc48a', fg: '#261405' },
  neutral: { bg: '#1e1e24', fg: '#e4e4ea' },
} as const;

export function BayerBadge({
  tone = 'violet',
  children,
}: {
  tone?: keyof typeof TONES;
  children: ReactNode;
}) {
  const { bg, fg } = TONES[tone];
  return (
    <span className="inline-flex items-stretch h-[20px] font-mono text-[10px] tracking-[0.06em] shrink-0">
      <span
        className="inline-flex items-center pl-2 pr-1.5 leading-none font-medium"
        style={{ backgroundColor: bg, color: fg }}
      >
        {children}
      </span>
      <span className="inline-flex items-stretch" style={{ color: bg }}>
        <svg viewBox="0 0 6 6" preserveAspectRatio="none" className="block w-4 h-full -ml-px" shapeRendering="crispEdges" aria-hidden="true">
          <rect x="0" y="0" width="1" height="6" fill="currentColor" />
          <rect x="1" y="0" width="1" height="2" fill="currentColor" />
          <rect x="1" y="3" width="1" height="2" fill="currentColor" />
          <rect x="2" y="1" width="1" height="1" fill="currentColor" />
          <rect x="2" y="3" width="1" height="1" fill="currentColor" />
          <rect x="2" y="5" width="1" height="1" fill="currentColor" />
          <rect x="3" y="0" width="1" height="1" fill="currentColor" />
          <rect x="3" y="2" width="1" height="1" fill="currentColor" />
          <rect x="3" y="4" width="1" height="1" fill="currentColor" />
          <rect x="4" y="1" width="1" height="1" fill="currentColor" />
          <rect x="4" y="5" width="1" height="1" fill="currentColor" />
          <rect x="5" y="3" width="1" height="1" fill="currentColor" />
        </svg>
      </span>
    </span>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Main.elm]
viewTags : Html msg
viewTags =
    div [ Attr.class "flex flex-wrap gap-2" ]
        [ BayerBadge.view "#c2b4ff" "#140f24" "Building"
        , BayerBadge.view "#8ce6ba" "#0b2117" "Go · TUI"
        , BayerBadge.view "#ffc48a" "#261405" "NixOS"
        ]
```

### Source
```elm [BayerBadge.elm]
module BayerBadge exposing (view)

import Html exposing (Html, span, text)
import Html.Attributes as Attr
import Svg exposing (rect, svg)
import Svg.Attributes as SvgAttr


view : String -> String -> String -> Html msg
view bgColor fgColor label =
    span [ Attr.class "inline-flex items-stretch h-[20px] font-mono text-[10px] tracking-[0.06em] shrink-0" ]
        [ span
            [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none font-medium"
            , Attr.style "background-color" bgColor
            , Attr.style "color" fgColor
            ]
            [ text label ]
        , span [ Attr.class "inline-flex items-stretch", Attr.style "color" bgColor ]
            [ svg
                [ SvgAttr.viewBox "0 0 6 6"
                , SvgAttr.preserveAspectRatio "none"
                , SvgAttr.class "block w-4 h-full -ml-px"
                , Attr.attribute "shape-rendering" "crispEdges"
                ]
                [ rect [ SvgAttr.x "0", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "6", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "1", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "2", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "1", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "2", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "2", SvgAttr.y "1", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "2", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "2", SvgAttr.y "5", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "3", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "3", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "3", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "4", SvgAttr.y "1", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "4", SvgAttr.y "5", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "5", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                ]
            ]
        ]
```
::
