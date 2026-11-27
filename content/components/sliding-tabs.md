---
title: Sliding Segmented Tabs
category: Navigation
order: 4
preview: sliding-tabs
summary: Borderless squircle segmented control with a GPU-accelerated translate3d sliding indicator pill.
tags:
  - Tabs
  - Motion
  - Borderless
---

A zero-border segmented tab bar using CSS Grid equal columns and a single absolutely-positioned pill driven by `translate3d(index * 100%, 0, 0)`. Used for the PR wing filter (`All / Merged / Open`) and bento category switchers.

::framework{name="vue"}
### Usage
```vue [FilterBar.vue]
<script setup lang="ts">
import { ref } from 'vue';
import SlidingTabs from './SlidingTabs.vue';

const active = ref('all');
const options = [
  { id: 'all', label: 'All' },
  { id: 'merged', label: 'Merged' },
  { id: 'open', label: 'Open' },
];
</script>

<template>
  <SlidingTabs v-model="active" :options="options" />
</template>
```

### Source
```vue [SlidingTabs.vue]
<script setup lang="ts">
import { computed } from 'vue';

export interface TabOption {
  id: string;
  label: string;
}

const props = defineProps<{
  modelValue: string;
  options: TabOption[];
}>();

const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

const activeIndex = computed(() =>
  Math.max(0, props.options.findIndex((o) => o.id === props.modelValue))
);
</script>

<template>
  <div
    class="relative inline-grid p-0.5 rounded-[12px] bg-zinc-900/70"
    :style="{ gridTemplateColumns: `repeat(${options.length}, minmax(0, 1fr))` }"
  >
    <div
      aria-hidden="true"
      class="pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 rounded-[10px] bg-zinc-800 transition-transform duration-200 ease-out"
      :style="{
        width: `calc((100% - 4px) / ${options.length})`,
        transform: `translate3d(${activeIndex * 100}%, 0, 0)`,
      }"
    />
    <button
      v-for="opt in options"
      :key="opt.id"
      type="button"
      @click="emit('update:modelValue', opt.id)"
      :class="[
        'relative z-10 px-3 py-1.5 font-mono text-[11px] cursor-pointer transition-colors duration-150',
        modelValue === opt.id ? 'text-zinc-100 font-medium' : 'text-zinc-400 hover:text-zinc-200',
      ]"
    >
      {{ opt.label }}
    </button>
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [FilterBar.tsx]
import { useState } from 'react';
import { SlidingTabs } from './SlidingTabs';

const OPTIONS = [
  { id: 'all', label: 'All' },
  { id: 'merged', label: 'Merged' },
  { id: 'open', label: 'Open' },
] as const;

export function FilterBar() {
  const [active, setActive] = useState('all');
  return <SlidingTabs value={active} onChange={setActive} options={OPTIONS} />;
}
```

### Source
```tsx [SlidingTabs.tsx]
interface TabOption {
  readonly id: string;
  readonly label: string;
}

export function SlidingTabs({
  value,
  onChange,
  options,
}: {
  value: string;
  onChange: (id: string) => void;
  options: readonly TabOption[];
}) {
  const activeIndex = Math.max(0, options.findIndex((o) => o.id === value));

  return (
    <div
      className="relative inline-grid p-0.5 rounded-[12px] bg-zinc-900/70"
      style={{ gridTemplateColumns: `repeat(${options.length}, minmax(0, 1fr))` }}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 rounded-[10px] bg-zinc-800 transition-transform duration-200 ease-out"
        style={{
          width: `calc((100% - 4px) / ${options.length})`,
          transform: `translate3d(${activeIndex * 100}%, 0, 0)`,
        }}
      />
      {options.map((opt) => (
        <button
          key={opt.id}
          type="button"
          onClick={() => onChange(opt.id)}
          className={`relative z-10 px-3 py-1.5 font-mono text-[11px] cursor-pointer transition-colors duration-150 ${
            value === opt.id ? 'text-zinc-100 font-medium' : 'text-zinc-400 hover:text-zinc-200'
          }`}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Main.elm]
viewFilter : Filter -> Html Msg
viewFilter active =
    SlidingTabs.view SetFilter active [ ( All, "All" ), ( Merged, "Merged" ), ( Open, "Open" ) ]
```

### Source
```elm [SlidingTabs.elm]
module SlidingTabs exposing (view)

import Html exposing (Html, button, div, text)
import Html.Attributes as Attr
import Html.Events as Events


view : (a -> msg) -> a -> List ( a, String ) -> Html msg
view onSelect active options =
    let
        count =
            max 1 (List.length options)

        activeIdx =
            options
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, ( val, _ ) ) -> val == active)
                |> List.head
                |> Maybe.map Tuple.first
                |> Maybe.withDefault 0
    in
    div
        [ Attr.class "relative inline-grid p-0.5 rounded-[12px] bg-zinc-900/70"
        , Attr.style "grid-template-columns" ("repeat(" ++ String.fromInt count ++ ", minmax(0, 1fr))")
        ]
        (div
            [ Attr.attribute "aria-hidden" "true"
            , Attr.class "pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 rounded-[10px] bg-zinc-800 transition-transform duration-200 ease-out"
            , Attr.style "width" ("calc((100% - 4px) / " ++ String.fromInt count ++ ")")
            , Attr.style "transform" ("translate3d(" ++ String.fromInt (activeIdx * 100) ++ "%, 0, 0)")
            ]
            []
            :: List.map
                (\( val, label ) ->
                    button
                        [ Attr.type_ "button"
                        , Events.onClick (onSelect val)
                        , Attr.class
                            ("relative z-10 px-3 py-1.5 font-mono text-[11px] cursor-pointer transition-colors duration-150 "
                                ++ (if val == active then
                                        "text-zinc-100 font-medium"

                                    else
                                        "text-zinc-400 hover:text-zinc-200"
                                   )
                            )
                        ]
                        [ text label ]
                )
                options
        )
```
::
