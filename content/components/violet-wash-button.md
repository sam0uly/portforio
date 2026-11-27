---
title: Violet Wash Button
category: Buttons
order: 2
preview: violet-wash-button
summary: Soft pastel violet wash squircle button used for back-navigation and secondary actions.
tags:
  - Button
  - Navigation
  - Pastel
---

A low-contrast violet-tinted squircle button designed for secondary navigation controls like back links (`← Portfolio`, `← Writing`). No borders, clean hover lift, and accessible contrast in both Dark and Light modes.

::framework{name="vue"}
### Usage
```vue [Header.vue]
<script setup lang="ts">
import VioletWashLink from './VioletWashLink.vue';
</script>

<template>
  <VioletWashLink href="/">Portfolio</VioletWashLink>
</template>
```

### Source
```vue [VioletWashLink.vue]
<script setup lang="ts">
defineProps<{
  href: string;
}>();
</script>

<template>
  <a
    :href="href"
    class="group inline-flex items-center gap-x-1.5 px-3 py-1.5 rounded-[10px] bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[#c2b4ff] dark:text-[#c2b4ff] transition-colors duration-150"
  >
    <svg viewBox="0 0 16 16" fill="none" class="size-3.5 transition-transform duration-150 group-hover:-translate-x-0.5" aria-hidden="true">
      <path d="M10 3.5L5.5 8L10 12.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" />
    </svg>
    <span><slot /></span>
  </a>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Header.tsx]
import { VioletWashLink } from './VioletWashLink';

export function Header() {
  return <VioletWashLink href="/">Portfolio</VioletWashLink>;
}
```

### Source
```tsx [VioletWashLink.tsx]
import type { AnchorHTMLAttributes, ReactNode } from 'react';

interface VioletWashLinkProps extends AnchorHTMLAttributes<HTMLAnchorElement> {
  children: ReactNode;
}

export function VioletWashLink({ children, className = '', ...props }: VioletWashLinkProps) {
  return (
    <a
      {...props}
      className={`group inline-flex items-center gap-x-1.5 px-3 py-1.5 rounded-[10px] bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[#c2b4ff] transition-colors duration-150 ${className}`}
    >
      <svg viewBox="0 0 16 16" fill="none" className="size-3.5 transition-transform duration-150 group-hover:-translate-x-0.5" aria-hidden="true">
        <path d="M10 3.5L5.5 8L10 12.5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <span>{children}</span>
    </a>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Header.elm]
viewBack : msg -> Html msg
viewBack onBack =
    VioletWashLink.view "/" onBack "Portfolio"
```

### Source
```elm [VioletWashLink.elm]
module VioletWashLink exposing (view)

import Html exposing (Html, a, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Svg exposing (path, svg)
import Svg.Attributes as SvgAttr


view : String -> msg -> String -> Html msg
view href onClick label =
    a
        [ Attr.href href
        , Events.onClick onClick
        , Attr.class "group inline-flex items-center gap-x-1.5 px-3 py-1.5 rounded-[10px] bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[#c2b4ff] transition-colors duration-150"
        ]
        [ svg
            [ SvgAttr.viewBox "0 0 16 16"
            , SvgAttr.fill "none"
            , SvgAttr.class "size-3.5 transition-transform duration-150 group-hover:-translate-x-0.5"
            ]
            [ path
                [ SvgAttr.d "M10 3.5L5.5 8L10 12.5"
                , SvgAttr.stroke "currentColor"
                , SvgAttr.strokeWidth "1.4"
                , SvgAttr.strokeLinecap "round"
                , SvgAttr.strokeLinejoin "round"
                ]
                []
            ]
        , span [] [ text label ]
        ]
```
::
