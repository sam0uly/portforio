---
title: Expandable Spec Drawers
category: Layout
order: 5
preview: spec-drawers
summary: Borderless squircle accordion rows with a sliding hover highlight, sibling dim, and smooth grid-row reveal.
tags:
  - Accordion
  - Hover Pill
  - Motion
---

The Work section component from the homepage. Collapsed rows share a single sliding hover pill that tracks `offsetTop` and `offsetHeight`, dims sibling rows and uncolors their tags, and smoothly unfolds inline via CSS `grid-template-rows: 0fr -> 1fr`.

::framework{name="vue"}
### Usage
```vue [WorkSection.vue]
<script setup lang="ts">
import SpecDrawers from './SpecDrawers.vue';

const items = [
  { id: 'twig', name: 'Twig', summary: 'Live diff viewer for working trees', tag: 'Building', story: 'Built for huge Git diffs.' },
  { id: 'mural', name: 'mural', summary: 'Pure Go Wayland wallpaper daemon', tag: 'Go · TUI', story: 'Single binary wallpaper manager.' },
];
</script>

<template>
  <SpecDrawers :items="items" />
</template>
```

### Source
```vue [SpecDrawers.vue]
<script setup lang="ts">
import { ref } from 'vue';

export interface DrawerItem {
  id: string;
  name: string;
  summary: string;
  tag: string;
  story: string;
}

defineProps<{ items: DrawerItem[] }>();

const openId = ref<string | null>(null);
const hover = ref<{ id: string; top: number; height: number; visible: boolean } | null>(null);

function onEnter(item: DrawerItem, e: MouseEvent) {
  const el = e.currentTarget as HTMLElement;
  const isOpen = openId.value === item.id;
  if (isOpen) {
    if (hover.value) hover.value = { ...hover.value, id: item.id, visible: false };
    return;
  }
  hover.value = { id: item.id, top: el.offsetTop, height: el.offsetHeight, visible: true };
}

function toggle(id: string) {
  const next = openId.value === id ? null : id;
  openId.value = next;
  if (hover.value) hover.value = { ...hover.value, id, visible: next === null };
}
</script>

<template>
  <div class="relative space-y-1.5" @mouseleave="hover && (hover = { ...hover, id: '', visible: false })">
    <div
      aria-hidden="true"
      class="pointer-events-none absolute inset-x-0 top-0 z-0 rounded-[14px] bg-zinc-800/60 transition-[transform,height,opacity] duration-200 ease-out"
      :style="{
        transform: `translate3d(0, ${hover?.top ?? 0}px, 0)`,
        height: `${hover?.height ?? 42}px`,
        opacity: hover?.visible ? 1 : 0,
      }"
    />
    <div
      v-for="item in items"
      :key="item.id"
      @mouseenter="onEnter(item, $event)"
      :class="[
        'relative z-10 rounded-[14px] transition-colors duration-200',
        openId === item.id ? 'bg-zinc-800/70' : 'bg-zinc-900/40',
      ]"
    >
      <button type="button" @click="toggle(item.id)" class="w-full px-3.5 py-2.5 flex items-center justify-between gap-3 text-left cursor-pointer">
        <div class="flex items-baseline gap-3 min-w-0">
          <span
            :class="[
              'text-sm font-medium shrink-0 transition-colors duration-200',
              hover?.id && hover.id !== item.id && openId !== item.id ? 'text-zinc-500' : 'text-zinc-100',
            ]"
          >{{ item.name }}</span>
          <span
            :class="[
              'text-xs truncate transition-colors duration-200',
              hover?.id && hover.id !== item.id && openId !== item.id ? 'text-zinc-600' : 'text-zinc-400',
            ]"
          >{{ item.summary }}</span>
        </div>
        <span class="font-mono text-[10px] text-zinc-400">{{ openId === item.id ? '−' : '+' }}</span>
      </button>
      <div
        class="grid transition-[grid-template-rows,opacity] duration-240 ease-out"
        :style="{ gridTemplateRows: openId === item.id ? '1fr' : '0fr', opacity: openId === item.id ? 1 : 0 }"
      >
        <div class="overflow-hidden">
          <p @click="toggle(item.id)" class="px-3.5 pb-3.5 pt-1 text-xs leading-relaxed text-zinc-400 cursor-pointer">
            {{ item.story }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [WorkSection.tsx]
import { SpecDrawers } from './SpecDrawers';

const ITEMS = [
  { id: 'twig', name: 'Twig', summary: 'Live diff viewer for working trees', tag: 'Building', story: 'Built for huge Git diffs.' },
  { id: 'mural', name: 'mural', summary: 'Pure Go Wayland wallpaper daemon', tag: 'Go · TUI', story: 'Single binary wallpaper manager.' },
];

export function WorkSection() {
  return <SpecDrawers items={ITEMS} />;
}
```

### Source
```tsx [SpecDrawers.tsx]
import { useState, type MouseEvent } from 'react';

interface DrawerItem {
  id: string;
  name: string;
  summary: string;
  tag: string;
  story: string;
}

export function SpecDrawers({ items }: { items: readonly DrawerItem[] }) {
  const [openId, setOpenId] = useState<string | null>(null);
  const [hover, setHover] = useState<{ id: string; top: number; height: number; visible: boolean } | null>(null);

  const onEnter = (item: DrawerItem, e: MouseEvent<HTMLDivElement>) => {
    const el = e.currentTarget;
    if (openId === item.id) {
      setHover((prev) => (prev ? { ...prev, id: item.id, visible: false } : null));
      return;
    }
    setHover({ id: item.id, top: el.offsetTop, height: el.offsetHeight, visible: true });
  };

  const toggle = (id: string) => {
    const next = openId === id ? null : id;
    setOpenId(next);
    setHover((prev) => (prev ? { ...prev, id, visible: next === null } : prev));
  };

  return (
    <div className="relative space-y-1.5" onMouseLeave={() => setHover((p) => (p ? { ...p, id: '', visible: false } : p))}>
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 top-0 z-0 rounded-[14px] bg-zinc-800/60 transition-[transform,height,opacity] duration-200 ease-out"
        style={{
          transform: `translate3d(0, ${hover?.top ?? 0}px, 0)`,
          height: `${hover?.height ?? 42}px`,
          opacity: hover?.visible ? 1 : 0,
        }}
      />
      {items.map((item) => {
        const isOpen = openId === item.id;
        const dimmed = Boolean(hover?.id) && hover?.id !== item.id && !isOpen;
        return (
          <div
            key={item.id}
            onMouseEnter={(e) => onEnter(item, e)}
            className={`relative z-10 rounded-[14px] transition-colors duration-200 ${
              isOpen ? 'bg-zinc-800/70' : 'bg-zinc-900/40'
            }`}
          >
            <button type="button" onClick={() => toggle(item.id)} className="w-full px-3.5 py-2.5 flex items-center justify-between gap-3 text-left cursor-pointer">
              <div className="flex items-baseline gap-3 min-w-0">
                <span className={`text-sm font-medium shrink-0 transition-colors duration-200 ${dimmed ? 'text-zinc-500' : 'text-zinc-100'}`}>{item.name}</span>
                <span className={`text-xs truncate transition-colors duration-200 ${dimmed ? 'text-zinc-600' : 'text-zinc-400'}`}>{item.summary}</span>
              </div>
              <span className="font-mono text-[10px] text-zinc-400">{isOpen ? '−' : '+'}</span>
            </button>
            <div
              className="grid transition-[grid-template-rows,opacity] duration-240 ease-out"
              style={{ gridTemplateRows: isOpen ? '1fr' : '0fr', opacity: isOpen ? 1 : 0 }}
            >
              <div className="overflow-hidden">
                <p onClick={() => toggle(item.id)} className="px-3.5 pb-3.5 pt-1 text-xs leading-relaxed text-zinc-400 cursor-pointer">
                  {item.story}
                </p>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Main.elm]
viewWork : Model -> Html Msg
viewWork model =
    SpecDrawers.view
        { onToggle = ToggleWorkDrawer
        , onHover = HoverWorkDrawer
        }
        model.openWorkId
        model.hoveredWork
        projects
```

### Source
```elm [SpecDrawers.elm]
module SpecDrawers exposing (HoverRect, Item, view)

import Html exposing (Html, button, div, p, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode


type alias HoverRect =
    { id : String, top : Float, height : Float, visible : Bool }


type alias Item =
    { id : String, name : String, summary : String, story : String }


hoverDecoder : String -> Bool -> (Maybe HoverRect -> msg) -> Decode.Decoder msg
hoverDecoder id isOpen onHover =
    Decode.map2
        (\top h -> onHover (Just { id = id, top = top, height = h, visible = not isOpen }))
        (Decode.at [ "currentTarget", "offsetTop" ] Decode.float)
        (Decode.at [ "currentTarget", "offsetHeight" ] Decode.float)


view : { onToggle : String -> msg, onHover : Maybe HoverRect -> msg } -> Maybe String -> Maybe HoverRect -> List Item -> Html msg
view cfg openId hovered items =
    div [ Attr.class "relative space-y-1.5", Events.onMouseLeave (cfg.onHover Nothing) ]
        (div
            [ Attr.class "pointer-events-none absolute inset-x-0 top-0 z-0 rounded-[14px] bg-zinc-800/60 transition-[transform,height,opacity] duration-200 ease-out"
            , Attr.style "transform" ("translate3d(0, " ++ String.fromFloat (Maybe.map .top hovered |> Maybe.withDefault 0) ++ "px, 0)")
            , Attr.style "height" (String.fromFloat (Maybe.map .height hovered |> Maybe.withDefault 42) ++ "px")
            , Attr.style "opacity" (if Maybe.map .visible hovered == Just True then "1" else "0")
            ]
            []
            :: List.map
                (\item ->
                    let
                        isOpen =
                            openId == Just item.id
                    in
                    div [ Events.on "mouseenter" (hoverDecoder item.id isOpen cfg.onHover), Attr.class "relative z-10 rounded-[14px] bg-zinc-900/40" ]
                        [ button [ Attr.type_ "button", Events.onClick (cfg.onToggle item.id), Attr.class "w-full px-3.5 py-2.5 flex justify-between text-left" ]
                            [ span [ Attr.class "text-sm font-medium text-zinc-100" ] [ text item.name ]
                            , span [ Attr.class "font-mono text-xs text-zinc-400" ] [ text (if isOpen then "−" else "+") ]
                            ]
                        ]
                )
                items
        )
```
::
