---
title: Stack Matrix Filter
category: Layout
order: 13
preview: stack-matrix
summary: Interactive technology pill bar that spotlights matching project tiles while dimming non-matches.
tags:
  - Layout
  - Filter
  - Matrix
---

Click any stack pill (`Go`, `Bubble Tea`, `Wayland`, `NixOS`, `Lua`) to spotlight every matching project in place without layout reflow.

::framework{name="vue"}
### Usage
```vue [Projects.vue]
<script setup lang="ts">
import StackMatrix from './StackMatrix.vue';
</script>

<template>
  <StackMatrix />
</template>
```

### Source
```vue [StackMatrix.vue]
<script setup lang="ts">
import { ref } from 'vue';

const active = ref<string | null>(null);
const techs = ['Go', 'Bubble Tea', 'Wayland', 'NixOS'];
const items = [
  { name: 'Twig', stack: ['Go', 'Bubble Tea'] },
  { name: 'mural', stack: ['Go', 'Wayland'] },
  { name: 'Samouly Flake', stack: ['NixOS'] },
];
</script>

<template>
  <div class="space-y-3">
    <div class="flex flex-wrap gap-1.5">
      <button
        v-for="t in techs"
        :key="t"
        type="button"
        @click="active = active === t ? null : t"
        :class="['px-2.5 py-1 rounded-[10px] font-mono text-[11px] cursor-pointer', active === t ? 'bg-[#c2b4ff] text-[#140f24]' : 'bg-zinc-900 text-zinc-400']"
      >
        {{ t }}
      </button>
    </div>
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
      <div
        v-for="item in items"
        :key="item.name"
        class="p-3 rounded-[12px] bg-zinc-900/70 transition-opacity duration-200"
        :style="{ opacity: !active || item.stack.includes(active) ? 1 : 0.24 }"
      >
        <div class="text-sm font-medium text-zinc-100">{{ item.name }}</div>
        <div class="mt-1 font-mono text-[10px] text-zinc-500">{{ item.stack.join(' · ') }}</div>
      </div>
    </div>
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Projects.tsx]
import { StackMatrix } from './StackMatrix';

export function Projects() {
  return <StackMatrix />;
}
```

### Source
```tsx [StackMatrix.tsx]
import { useState } from 'react';

const TECHS = ['Go', 'Bubble Tea', 'Wayland', 'NixOS'];
const ITEMS = [
  { name: 'Twig', stack: ['Go', 'Bubble Tea'] },
  { name: 'mural', stack: ['Go', 'Wayland'] },
  { name: 'Samouly Flake', stack: ['NixOS'] },
];

export function StackMatrix() {
  const [active, setActive] = useState<string | null>(null);

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-1.5">
        {TECHS.map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setActive((cur) => (cur === t ? null : t))}
            className={`px-2.5 py-1 rounded-[10px] font-mono text-[11px] cursor-pointer ${
              active === t ? 'bg-[#c2b4ff] text-[#140f24]' : 'bg-zinc-900 text-zinc-400'
            }`}
          >
            {t}
          </button>
        ))}
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
        {ITEMS.map((item) => (
          <div
            key={item.name}
            className="p-3 rounded-[12px] bg-zinc-900/70 transition-opacity duration-200"
            style={{ opacity: !active || item.stack.includes(active) ? 1 : 0.24 }}
          >
            <div className="text-sm font-medium text-zinc-100">{item.name}</div>
            <div className="mt-1 font-mono text-[10px] text-zinc-500">{item.stack.join(' · ')}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Projects.elm]
viewMatrix : Maybe String -> Html Msg
viewMatrix activeTech =
    StackMatrix.view ToggleTech activeTech
```

### Source
```elm [StackMatrix.elm]
module StackMatrix exposing (view)

import Html exposing (Html, button, div, text)
import Html.Attributes as Attr
import Html.Events as Events


view : (String -> msg) -> Maybe String -> List { name : String, stack : List String } -> Html msg
view onToggle active items =
    div [ Attr.class "grid grid-cols-1 sm:grid-cols-3 gap-2" ]
        (List.map
            (\item ->
                let
                    matches =
                        case active of
                            Nothing ->
                                True

                            Just t ->
                                List.member t item.stack
                in
                div
                    [ Attr.class "p-3 box-squircle bg-[var(--tab-bg)]/60 transition-opacity duration-200"
                    , Attr.style "opacity" (if matches then "1" else "0.24")
                    ]
                    [ div [ Attr.class "text-sm font-medium text-[var(--page-fg)]" ] [ text item.name ]
                    , div [ Attr.class "mt-1 font-mono text-[10px] text-[var(--page-subtle)]" ] [ text (String.join " · " item.stack) ]
                    ]
            )
            items
        )
```
::
