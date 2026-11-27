---
title: Squircle Button
category: Buttons
order: 3
preview: squircle-button
summary: Multi-variant squircle button family — ghost, surface, outline, invert, shimmer, and soft elevation.
tags:
  - Button
  - Variants
  - Squircle
---

Six cohesive squircle button variants sharing identical mono typography, hit area, and focus rings: **Ghost**, **Surface**, **Outline**, **Invert**, **Shimmer**, and **Elevation**. Switch variants live in the preview below.

::framework{name="vue"}
### Usage
```vue [Actions.vue]
<script setup lang="ts">
import SquircleButton from './SquircleButton.vue';
</script>

<template>
  <div class="flex flex-wrap gap-2">
    <SquircleButton variant="ghost">Ghost</SquircleButton>
    <SquircleButton variant="surface">Surface</SquircleButton>
    <SquircleButton variant="outline">Outline</SquircleButton>
    <SquircleButton variant="invert">Invert</SquircleButton>
    <SquircleButton variant="shimmer">Shimmer</SquircleButton>
    <SquircleButton variant="elevation">Elevation</SquircleButton>
  </div>
</template>
```

### Source
```vue [SquircleButton.vue]
<script setup lang="ts">
export type SquircleVariant = 'ghost' | 'surface' | 'outline' | 'invert' | 'shimmer' | 'elevation';

const VARIANTS: Record<SquircleVariant, string> = {
  ghost: 'text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800',
  surface: 'bg-zinc-900 hover:bg-zinc-800 text-zinc-100',
  outline: 'border border-zinc-800 hover:border-zinc-600 text-zinc-100',
  invert: 'bg-zinc-100 text-zinc-950 hover:opacity-85 font-medium',
  shimmer: 'bg-zinc-900 ring-1 ring-[#8b75ff]/40 hover:ring-[#8b75ff] text-zinc-100',
  elevation: 'bg-zinc-900 hover:bg-zinc-800 shadow-[inset_0_1px_0_rgba(255,255,255,0.1)] active:translate-y-px text-zinc-100',
};

const props = withDefaults(defineProps<{ variant?: SquircleVariant }>(), { variant: 'surface' });
</script>

<template>
  <button
    type="button"
    :class="['inline-flex items-center gap-x-1.5 px-3 py-1.5 rounded-[10px] font-mono text-xs transition-all duration-150 cursor-pointer', VARIANTS[props.variant]]"
  >
    <slot />
  </button>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Actions.tsx]
import { SquircleButton } from './SquircleButton';

export function Actions() {
  return (
    <div className="flex flex-wrap gap-2">
      <SquircleButton variant="ghost">Ghost</SquircleButton>
      <SquircleButton variant="surface">Surface</SquircleButton>
      <SquircleButton variant="outline">Outline</SquircleButton>
      <SquircleButton variant="invert">Invert</SquircleButton>
      <SquircleButton variant="shimmer">Shimmer</SquircleButton>
      <SquircleButton variant="elevation">Elevation</SquircleButton>
    </div>
  );
}
```

### Source
```tsx [SquircleButton.tsx]
import type { ButtonHTMLAttributes, ReactNode } from 'react';

export type SquircleVariant = 'ghost' | 'surface' | 'outline' | 'invert' | 'shimmer' | 'elevation';

const VARIANTS: Record<SquircleVariant, string> = {
  ghost: 'text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800',
  surface: 'bg-zinc-900 hover:bg-zinc-800 text-zinc-100',
  outline: 'border border-zinc-800 hover:border-zinc-600 text-zinc-100',
  invert: 'bg-zinc-100 text-zinc-950 hover:opacity-85 font-medium',
  shimmer: 'bg-zinc-900 ring-1 ring-[#8b75ff]/40 hover:ring-[#8b75ff] text-zinc-100',
  elevation: 'bg-zinc-900 hover:bg-zinc-800 shadow-[inset_0_1px_0_rgba(255,255,255,0.1)] active:translate-y-px text-zinc-100',
};

export function SquircleButton({
  variant = 'surface',
  children,
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: SquircleVariant; children: ReactNode }) {
  return (
    <button
      type="button"
      {...props}
      className={`inline-flex items-center gap-x-1.5 px-3 py-1.5 rounded-[10px] font-mono text-xs transition-all duration-150 cursor-pointer ${VARIANTS[variant]} ${className}`}
    >
      {children}
    </button>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Actions.elm]
viewActions : msg -> Html msg
viewActions onClick =
    div [ Attr.class "flex flex-wrap gap-2" ]
        [ SquircleButton.view SquircleButton.Ghost onClick "Ghost"
        , SquircleButton.view SquircleButton.Surface onClick "Surface"
        , SquircleButton.view SquircleButton.Invert onClick "Invert"
        , SquircleButton.view SquircleButton.Elevation onClick "Elevation"
        ]
```

### Source
```elm [SquircleButton.elm]
module SquircleButton exposing (Variant(..), view)

import Html exposing (Html, button, text)
import Html.Attributes as Attr
import Html.Events as Events


type Variant
    = Ghost
    | Surface
    | Outline
    | Invert
    | Shimmer
    | Elevation


view : Variant -> msg -> String -> Html msg
view variant onClick label =
    let
        cls =
            case variant of
                Ghost ->
                    "text-[var(--page-muted)] hover:text-[var(--page-fg)] hover:bg-[var(--tab-bg)]"

                Surface ->
                    "bg-[var(--code-bg)] hover:bg-[var(--tab-bg)] text-[var(--page-fg)]"

                Outline ->
                    "border border-[var(--page-line)] hover:border-[var(--page-subtle)] text-[var(--page-fg)]"

                Invert ->
                    "bg-[var(--page-fg)] text-[var(--page-bg)] hover:opacity-85 font-medium"

                Shimmer ->
                    "bg-[var(--code-bg)] ring-1 ring-[#8b75ff]/40 hover:ring-[#8b75ff] text-[var(--page-fg)]"

                Elevation ->
                    "bg-[var(--code-bg)] hover:bg-[var(--tab-bg)] shadow-[inset_0_1px_0_rgba(255,255,255,0.1)] active:translate-y-px text-[var(--page-fg)]"
    in
    button
        [ Attr.type_ "button"
        , Events.onClick onClick
        , Attr.class ("inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle font-mono text-xs transition-all duration-150 cursor-pointer " ++ cls)
        ]
        [ text label ]
```
::
