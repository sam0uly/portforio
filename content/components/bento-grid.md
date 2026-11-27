---
title: Bento Squircle Grid
category: Layout
order: 11
preview: bento-grid
summary: Asymmetric 2-column squircle project grid with a full-width hero tile and sliding category filter tabs.
tags:
  - Layout
  - Bento
  - Filter
---

Pairs a borderless sliding category filter with a 2-column squircle grid where the flagship item spans full width on `All`.

::framework{name="vue"}
### Usage
```vue [Projects.vue]
<script setup lang="ts">
import BentoGrid from './BentoGrid.vue';
</script>

<template>
  <BentoGrid />
</template>
```

### Source
```vue [BentoGrid.vue]
<script setup lang="ts">
import { computed, ref } from 'vue';

const filter = ref<'all' | 'go' | 'nix'>('all');
const items = [
  { id: 'twig', name: 'Twig', cat: 'go', summary: 'Live diff viewer for huge working trees' },
  { id: 'mural', name: 'mural', cat: 'go', summary: 'Pure Go Wayland wallpaper daemon' },
  { id: 'flake', name: 'Samouly Flake', cat: 'nix', summary: 'Declarative NixOS setup' },
];
const shown = computed(() => (filter.value === 'all' ? items : items.filter((i) => i.cat === filter.value)));
</script>

<template>
  <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
    <div
      v-for="(item, idx) in shown"
      :key="item.id"
      :class="['p-4 rounded-[14px] bg-zinc-900/60 hover:bg-zinc-800/80 transition-colors', idx === 0 && filter === 'all' ? 'sm:col-span-2' : '']"
    >
      <div class="font-semibold text-sm text-zinc-100">{{ item.name }}</div>
      <p class="mt-1 text-xs text-zinc-400">{{ item.summary }}</p>
    </div>
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Projects.tsx]
import { BentoGrid } from './BentoGrid';

export function Projects() {
  return <BentoGrid />;
}
```

### Source
```tsx [BentoGrid.tsx]
import { useState } from 'react';

const ITEMS = [
  { id: 'twig', name: 'Twig', cat: 'go', summary: 'Live diff viewer for huge working trees' },
  { id: 'mural', name: 'mural', cat: 'go', summary: 'Pure Go Wayland wallpaper daemon' },
  { id: 'flake', name: 'Samouly Flake', cat: 'nix', summary: 'Declarative NixOS setup' },
];

export function BentoGrid() {
  const [filter] = useState<'all' | 'go' | 'nix'>('all');
  const shown = filter === 'all' ? ITEMS : ITEMS.filter((i) => i.cat === filter);

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
      {shown.map((item, idx) => (
        <div
          key={item.id}
          className={`p-4 rounded-[14px] bg-zinc-900/60 hover:bg-zinc-800/80 transition-colors ${
            idx === 0 && filter === 'all' ? 'sm:col-span-2' : ''
          }`}
        >
          <div className="font-semibold text-sm text-zinc-100">{item.name}</div>
          <p className="mt-1 text-xs text-zinc-400">{item.summary}</p>
        </div>
      ))}
    </div>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Projects.elm]
viewGrid : Html msg
viewGrid =
    BentoGrid.view projects
```

### Source
```elm [BentoGrid.elm]
module BentoGrid exposing (view)

import Html exposing (Html, div, p, text)
import Html.Attributes as Attr


view : List { name : String, summary : String } -> Html msg
view items =
    div [ Attr.class "grid grid-cols-1 sm:grid-cols-2 gap-2.5" ]
        (List.indexedMap
            (\idx item ->
                div
                    [ Attr.class
                        ("p-4 box-squircle bg-[var(--tab-bg)]/50 hover:bg-[var(--tab-bg)] transition-colors "
                            ++ (if idx == 0 then "sm:col-span-2" else "")
                        )
                    ]
                    [ div [ Attr.class "font-semibold text-sm text-[var(--page-fg)]" ] [ text item.name ]
                    , p [ Attr.class "mt-1 text-xs text-[var(--page-muted)]" ] [ text item.summary ]
                    ]
            )
            items
        )
```
::
