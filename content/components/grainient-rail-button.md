---
title: Grainient Rail Button
category: Buttons
order: 1
preview: grainient-rail-button
summary: Squircle surface with a 2px Grainient bottom rail that expands to fill the entire button on hover.
tags:
  - Button
  - Squircle
  - Tailwind
---

A borderless squircle action button anchored by a 2px Grainient rail along the bottom edge. On hover (or while active), the rail expands upward across the full surface while text contrast flips cleanly.

::framework{name="vue"}
### Usage
```vue [App.vue]
<script setup lang="ts">
import { ref } from 'vue';
import GrainientButton from './GrainientButton.vue';

const open = ref(false);
</script>

<template>
  <GrainientButton :active="open" @click="open = !open">
    {{ open ? 'Close PRs ×' : 'Check PRs →' }}
  </GrainientButton>
</template>
```

### Source
```vue [GrainientButton.vue]
<script setup lang="ts">
defineProps<{
  active?: boolean;
}>();
</script>

<template>
  <button
    type="button"
    :class="[
      'group relative overflow-hidden inline-flex items-center gap-x-1.5 px-3 py-1.5 rounded-[10px] bg-zinc-900 font-mono text-xs font-medium transition-colors duration-200 cursor-pointer',
      active ? 'text-white' : 'text-zinc-100 hover:text-white',
    ]"
  >
    <span
      aria-hidden="true"
      :class="[
        'pointer-events-none absolute inset-x-0 bottom-0 bg-gradient-to-r from-[#2b55b3] via-[#8b75ff] via-[#ff4fbf] to-[#ff985a] transition-[height,opacity] duration-250 ease-out',
        active ? 'h-full opacity-100' : 'h-[2px] opacity-75 group-hover:h-full group-hover:opacity-100',
      ]"
    />
    <span class="relative z-10 inline-flex items-center gap-x-1.5 leading-none">
      <slot />
    </span>
  </button>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [App.tsx]
import { useState } from 'react';
import { GrainientButton } from './GrainientButton';

export function App() {
  const [open, setOpen] = useState(false);

  return (
    <GrainientButton active={open} onClick={() => setOpen((v) => !v)}>
      {open ? 'Close PRs ×' : 'Check PRs →'}
    </GrainientButton>
  );
}
```

### Source
```tsx [GrainientButton.tsx]
import type { ButtonHTMLAttributes, ReactNode } from 'react';

interface GrainientButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  active?: boolean;
  children: ReactNode;
}

export function GrainientButton({ active = false, children, className = '', ...props }: GrainientButtonProps) {
  return (
    <button
      type="button"
      {...props}
      className={`group relative overflow-hidden inline-flex items-center gap-x-1.5 px-3 py-1.5 rounded-[10px] bg-zinc-900 font-mono text-xs font-medium transition-colors duration-200 cursor-pointer ${
        active ? 'text-white' : 'text-zinc-100 hover:text-white'
      } ${className}`}
    >
      <span
        aria-hidden="true"
        className={`pointer-events-none absolute inset-x-0 bottom-0 bg-gradient-to-r from-[#2b55b3] via-[#8b75ff] via-[#ff4fbf] to-[#ff985a] transition-[height,opacity] duration-250 ease-out ${
          active ? 'h-full opacity-100' : 'h-[2px] opacity-75 group-hover:h-full group-hover:opacity-100'
        }`}
      />
      <span className="relative z-10 inline-flex items-center gap-x-1.5 leading-none">
        {children}
      </span>
    </button>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Main.elm]
view : Model -> Html Msg
view model =
    GrainientButton.view
        { onClick = TogglePrWing
        , active = model.prWingOpen
        , label =
            if model.prWingOpen then
                "Close PRs ×"

            else
                "Check PRs →"
        }
```

### Source
```elm [GrainientButton.elm]
module GrainientButton exposing (view)

import Html exposing (Html, button, span, text)
import Html.Attributes as Attr
import Html.Events as Events


view : { onClick : msg, active : Bool, label : String } -> Html msg
view config =
    let
        railClass =
            if config.active then
                "pointer-events-none absolute inset-x-0 bottom-0 h-full opacity-100 bg-gradient-to-r from-[#2b55b3] via-[#8b75ff] via-[#ff4fbf] to-[#ff985a] transition-[height,opacity] duration-250 ease-out"

            else
                "pointer-events-none absolute inset-x-0 bottom-0 h-[2px] group-hover:h-full opacity-75 group-hover:opacity-100 bg-gradient-to-r from-[#2b55b3] via-[#8b75ff] via-[#ff4fbf] to-[#ff985a] transition-[height,opacity] duration-250 ease-out"
    in
    button
        [ Attr.type_ "button"
        , Events.onClick config.onClick
        , Attr.class "group relative overflow-hidden inline-flex items-center gap-x-1.5 px-3 py-1.5 rounded-[10px] bg-zinc-900 font-mono text-xs font-medium text-zinc-100 hover:text-white transition-colors duration-200 cursor-pointer"
        ]
        [ span [ Attr.class railClass, Attr.attribute "aria-hidden" "true" ] []
        , span [ Attr.class "relative z-10 inline-flex items-center gap-x-1.5 leading-none" ]
            [ text config.label ]
        ]
```
::
