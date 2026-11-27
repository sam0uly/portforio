---
title: Bayer Action Button
category: Buttons
order: 5
preview: bayer-button
summary: Interactive Bayer-dithered tag button with neutral, pastel violet, mint, and dual-tone icon/label variants.
tags:
  - Button
  - Dither
  - SVG
---

Turns the site's 6×6 Bayer dither tail into a clickable button component with **Neutral**, **Pastel Violet**, **Pastel Mint**, and **Dual-Tone** variants. Ideal for compact status triggers and filter toggles.

::framework{name="vue"}
### Usage
```vue [Actions.vue]
<script setup lang="ts">
import BayerButton from './BayerButton.vue';
</script>

<template>
  <div class="flex flex-wrap gap-2">
    <BayerButton tone="neutral">Check PRs →</BayerButton>
    <BayerButton tone="violet">Active ×</BayerButton>
    <BayerButton tone="mint">Merged</BayerButton>
  </div>
</template>
```

### Source
```vue [BayerButton.vue]
<script setup lang="ts">
const TONES = {
  neutral: { bg: '#1e1e24', fg: '#e4e4ea' },
  violet: { bg: '#c2b4ff', fg: '#140f24' },
  mint: { bg: '#8ce6ba', fg: '#0b2117' },
} as const;

const props = withDefaults(defineProps<{ tone?: keyof typeof TONES }>(), { tone: 'neutral' });
</script>

<template>
  <button type="button" class="inline-flex items-stretch h-[24px] font-mono text-[11px] tracking-[0.05em] cursor-pointer active:scale-[0.98] transition-transform">
    <span class="inline-flex items-center pl-2.5 pr-1.5 leading-none font-medium" :style="{ backgroundColor: TONES[props.tone].bg, color: TONES[props.tone].fg }">
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
  </button>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Actions.tsx]
import { BayerButton } from './BayerButton';

export function Actions() {
  return (
    <div className="flex flex-wrap gap-2">
      <BayerButton tone="neutral">Check PRs →</BayerButton>
      <BayerButton tone="violet">Active ×</BayerButton>
      <BayerButton tone="mint">Merged</BayerButton>
    </div>
  );
}
```

### Source
```tsx [BayerButton.tsx]
import type { ButtonHTMLAttributes, ReactNode } from 'react';

const TONES = {
  neutral: { bg: '#1e1e24', fg: '#e4e4ea' },
  violet: { bg: '#c2b4ff', fg: '#140f24' },
  mint: { bg: '#8ce6ba', fg: '#0b2117' },
} as const;

export function BayerButton({
  tone = 'neutral',
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { tone?: keyof typeof TONES; children: ReactNode }) {
  const { bg, fg } = TONES[tone];
  return (
    <button
      type="button"
      {...props}
      className="inline-flex items-stretch h-[24px] font-mono text-[11px] tracking-[0.05em] cursor-pointer active:scale-[0.98] transition-transform"
    >
      <span className="inline-flex items-center pl-2.5 pr-1.5 leading-none font-medium" style={{ backgroundColor: bg, color: fg }}>
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
    </button>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Actions.elm]
viewButtons : msg -> Html msg
viewButtons onClick =
    div [ Attr.class "flex flex-wrap gap-2" ]
        [ BayerButton.view "var(--tab-bg)" "var(--tab-fg)" onClick "Check PRs →"
        , BayerButton.view "var(--callout-note-bg)" "var(--callout-note-fg)" onClick "Active ×"
        ]
```

### Source
```elm [BayerButton.elm]
module BayerButton exposing (view)

import Html exposing (Html, button, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Svg exposing (rect, svg)
import Svg.Attributes as SvgAttr


view : String -> String -> msg -> String -> Html msg
view bg fg onClick label =
    button
        [ Attr.type_ "button"
        , Events.onClick onClick
        , Attr.class "inline-flex items-stretch h-[24px] font-mono text-[11px] tracking-[0.05em] cursor-pointer active:scale-[0.98] transition-transform"
        ]
        [ span [ Attr.class "inline-flex items-center pl-2.5 pr-1.5 leading-none font-medium", Attr.style "background-color" bg, Attr.style "color" fg ] [ text label ]
        , span [ Attr.class "inline-flex items-stretch", Attr.style "color" bg ]
            [ svg [ SvgAttr.viewBox "0 0 6 6", SvgAttr.preserveAspectRatio "none", SvgAttr.class "block w-4 h-full -ml-px", Attr.attribute "shape-rendering" "crispEdges" ]
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
