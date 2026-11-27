---
title: Stacked Deck Switcher
category: Layout
order: 12
preview: stacked-deck
summary: Layered 3D squircle card deck where all cards stay mounted and smoothly glide forward on step, click, or pill jump.
tags:
  - Layout
  - Deck
  - Motion
---

Presents a stack of interactive dossier cards where **every card stays mounted in the DOM** at a stable index. Stepping `←` / `→`, clicking a peeking card behind the front one, or jumping via the expanding progress pills smoothly glides each card through depth (`translate3d`, `scale`, and `opacity`) using a spring-like cubic-bezier curve.

::framework{name="vue"}
### Usage
```vue [Showcase.vue]
<script setup lang="ts">
import StackedDeck, { type DeckSlide } from './StackedDeck.vue';

const slides: DeckSlide[] = [
  { name: 'Twig', repo: 'sam0uly/twig', tag: 'Building', summary: 'Live diff viewer for working trees bigger than your screen.', stack: ['Go', 'Bubble Tea', 'Git'] },
  { name: 'mural', repo: 'sam0uly/mural', tag: 'Go · TUI', summary: 'Terminal wallpaper manager with a pure Go Wayland daemon.', stack: ['Go', 'Wayland'] },
  { name: 'Spin', repo: 'sam0uly/spin', tag: 'CLI', summary: 'Language-agnostic project template CLI with interactive prompts.', stack: ['Go', 'CLI'] },
  { name: 'Samouly Flake', repo: 'sam0uly/samouly-flake', tag: 'NixOS', summary: 'Declarative NixOS workstation setup for Hyprland and Niri.', stack: ['Nix', 'NixOS'] },
];
</script>

<template>
  <StackedDeck :slides="slides" />
</template>
```

### Source
```vue [StackedDeck.vue]
<script setup lang="ts">
import { ref } from 'vue';

export interface DeckSlide {
  name: string;
  repo: string;
  tag: string;
  summary: string;
  stack: string[];
}

const props = defineProps<{ slides: DeckSlide[] }>();
const active = ref(0);

const step = (delta: number) => {
  const n = props.slides.length;
  active.value = (active.value + delta + n) % n;
};

function cardStyle(idx: number) {
  const n = props.slides.length;
  const rel = (idx - active.value + n) % n;
  if (rel === 0) return { transform: 'translate3d(0, 0px, 0) scale(1)', opacity: 1, zIndex: 30 };
  if (rel === 1) return { transform: 'translate3d(0, 14px, 0) scale(0.955)', opacity: 0.86, zIndex: 20 };
  if (rel === 2) return { transform: 'translate3d(0, 26px, 0) scale(0.91)', opacity: 0.62, zIndex: 10 };
  return { transform: 'translate3d(0, -14px, 0) scale(0.94)', opacity: 0, zIndex: 0, pointerEvents: 'none' as const };
}
</script>

<template>
  <div class="w-full max-w-md space-y-5">
    <div class="relative h-[186px]">
      <div
        v-for="(slide, idx) in slides"
        :key="slide.name"
        :style="{ ...cardStyle(idx), transformOrigin: '50% 100%' }"
        @click="idx !== active && (active = idx)"
        :class="[
          'absolute inset-x-0 top-0 rounded-[16px] p-5 space-y-3 select-none transition-[transform,opacity,background-color] duration-420 ease-[cubic-bezier(0.22,1,0.36,1)]',
          idx === active ? 'bg-zinc-950 shadow-[0_14px_34px_rgba(0,0,0,0.42)]' : 'bg-zinc-900 cursor-pointer hover:bg-zinc-800',
        ]"
      >
        <div class="flex items-center justify-between gap-3">
          <span class="font-semibold text-base text-zinc-100 truncate">{{ slide.name }}</span>
          <span class="rounded-sm bg-[#b8a8ff] px-2 py-0.5 font-mono text-[10px] font-medium text-[#120d26]">{{ slide.tag }}</span>
        </div>
        <p class="text-[13px] leading-relaxed text-zinc-400 min-h-[40px]">{{ slide.summary }}</p>
        <div class="pt-1 flex items-center justify-between gap-2">
          <div class="flex flex-wrap gap-1.5">
            <span v-for="tech in slide.stack" :key="tech" class="rounded-lg bg-zinc-900 px-2 py-0.5 font-mono text-[10px] text-zinc-400">
              {{ tech }}
            </span>
          </div>
          <span class="font-mono text-[10.5px] text-zinc-500 shrink-0">{{ slide.repo }}</span>
        </div>
      </div>
    </div>

    <div class="flex items-center justify-between gap-3">
      <div class="flex items-center gap-1.5">
        <button
          v-for="(slide, idx) in slides"
          :key="slide.name"
          type="button"
          :aria-label="`Show ${slide.name}`"
          @click="active = idx"
          :style="{ width: idx === active ? '28px' : '8px' }"
          :class="[
            'h-1.5 rounded-full transition-[width,background-color] duration-360 ease-[cubic-bezier(0.22,1,0.36,1)] cursor-pointer',
            idx === active ? 'bg-[#b8a8ff]' : 'bg-zinc-800 hover:bg-zinc-600',
          ]"
        />
      </div>
      <div class="flex items-center gap-2">
        <span class="font-mono text-[11px] text-zinc-500 tabular-nums">0{{ active + 1 }} / 0{{ slides.length }}</span>
        <button type="button" @click="step(-1)" class="size-7 rounded-lg bg-zinc-950 hover:bg-zinc-800 font-mono text-xs text-zinc-100 cursor-pointer">←</button>
        <button type="button" @click="step(1)" class="size-7 rounded-lg bg-zinc-950 hover:bg-zinc-800 font-mono text-xs text-zinc-100 cursor-pointer">→</button>
      </div>
    </div>
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Showcase.tsx]
import { StackedDeck, type DeckSlide } from './StackedDeck';

const SLIDES: DeckSlide[] = [
  { name: 'Twig', repo: 'sam0uly/twig', tag: 'Building', summary: 'Live diff viewer for working trees bigger than your screen.', stack: ['Go', 'Bubble Tea', 'Git'] },
  { name: 'mural', repo: 'sam0uly/mural', tag: 'Go · TUI', summary: 'Terminal wallpaper manager with a pure Go Wayland daemon.', stack: ['Go', 'Wayland'] },
  { name: 'Spin', repo: 'sam0uly/spin', tag: 'CLI', summary: 'Language-agnostic project template CLI with interactive prompts.', stack: ['Go', 'CLI'] },
  { name: 'Samouly Flake', repo: 'sam0uly/samouly-flake', tag: 'NixOS', summary: 'Declarative NixOS workstation setup for Hyprland and Niri.', stack: ['Nix', 'NixOS'] },
];

export function Showcase() {
  return <StackedDeck slides={SLIDES} />;
}
```

### Source
```tsx [StackedDeck.tsx]
import { useState, type CSSProperties } from 'react';

export interface DeckSlide {
  name: string;
  repo: string;
  tag: string;
  summary: string;
  stack: string[];
}

export function StackedDeck({ slides }: { slides: DeckSlide[] }) {
  const [active, setActive] = useState(0);
  const n = slides.length;
  const step = (d: number) => setActive((i) => (i + d + n) % n);

  const cardStyle = (idx: number): CSSProperties => {
    const rel = (idx - active + n) % n;
    if (rel === 0) return { transform: 'translate3d(0, 0px, 0) scale(1)', opacity: 1, zIndex: 30, transformOrigin: '50% 100%' };
    if (rel === 1) return { transform: 'translate3d(0, 14px, 0) scale(0.955)', opacity: 0.86, zIndex: 20, transformOrigin: '50% 100%' };
    if (rel === 2) return { transform: 'translate3d(0, 26px, 0) scale(0.91)', opacity: 0.62, zIndex: 10, transformOrigin: '50% 100%' };
    return { transform: 'translate3d(0, -14px, 0) scale(0.94)', opacity: 0, zIndex: 0, pointerEvents: 'none', transformOrigin: '50% 100%' };
  };

  return (
    <div className="w-full max-w-md space-y-5">
      <div className="relative h-[186px]">
        {slides.map((slide, idx) => (
          <div
            key={slide.name}
            style={cardStyle(idx)}
            onClick={() => idx !== active && setActive(idx)}
            className={`absolute inset-x-0 top-0 rounded-[16px] p-5 space-y-3 select-none transition-[transform,opacity,background-color] duration-420 ease-[cubic-bezier(0.22,1,0.36,1)] ${
              idx === active ? 'bg-zinc-950 shadow-[0_14px_34px_rgba(0,0,0,0.42)]' : 'bg-zinc-900 cursor-pointer hover:bg-zinc-800'
            }`}
          >
            <div className="flex items-center justify-between gap-3">
              <span className="font-semibold text-base text-zinc-100 truncate">{slide.name}</span>
              <span className="rounded-sm bg-[#b8a8ff] px-2 py-0.5 font-mono text-[10px] font-medium text-[#120d26]">{slide.tag}</span>
            </div>
            <p className="text-[13px] leading-relaxed text-zinc-400 min-h-[40px]">{slide.summary}</p>
            <div className="pt-1 flex items-center justify-between gap-2">
              <div className="flex flex-wrap gap-1.5">
                {slide.stack.map((tech) => (
                  <span key={tech} className="rounded-lg bg-zinc-900 px-2 py-0.5 font-mono text-[10px] text-zinc-400">
                    {tech}
                  </span>
                ))}
              </div>
              <span className="font-mono text-[10.5px] text-zinc-500 shrink-0">{slide.repo}</span>
            </div>
          </div>
        ))}
      </div>

      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-1.5">
          {slides.map((slide, idx) => (
            <button
              key={slide.name}
              type="button"
              aria-label={`Show ${slide.name}`}
              onClick={() => setActive(idx)}
              style={{ width: idx === active ? 28 : 8 }}
              className={`h-1.5 rounded-full transition-[width,background-color] duration-360 ease-[cubic-bezier(0.22,1,0.36,1)] cursor-pointer ${
                idx === active ? 'bg-[#b8a8ff]' : 'bg-zinc-800 hover:bg-zinc-600'
              }`}
            />
          ))}
        </div>
        <div className="flex items-center gap-2">
          <span className="font-mono text-[11px] text-zinc-500 tabular-nums">0{active + 1} / 0{n}</span>
          <button type="button" onClick={() => step(-1)} className="size-7 rounded-lg bg-zinc-950 hover:bg-zinc-800 font-mono text-xs text-zinc-100 cursor-pointer">←</button>
          <button type="button" onClick={() => step(1)} className="size-7 rounded-lg bg-zinc-950 hover:bg-zinc-800 font-mono text-xs text-zinc-100 cursor-pointer">→</button>
        </div>
      </div>
    </div>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Showcase.elm]
viewDeck : Int -> Html Msg
viewDeck activeIdx =
    StackedDeck.view
        { onStep = StepDeck
        , onSelect = SelectDeck
        }
        activeIdx
        slides
```

### Source
```elm [StackedDeck.elm]
module StackedDeck exposing (Slide, view)

import Html exposing (Html, button, div, p, span, text)
import Html.Attributes as Attr
import Html.Events as Events


type alias Slide =
    { name : String
    , repo : String
    , tag : String
    , summary : String
    , stack : List String
    }


view : { onStep : Int -> msg, onSelect : Int -> msg } -> Int -> List Slide -> Html msg
view cfg activeIdx slides =
    let
        total =
            max 1 (List.length slides)

        renderCard idx slide =
            let
                rel =
                    modBy total (idx - activeIdx + total)

                ( tf, op, zCls ) =
                    case rel of
                        0 -> ( "translate3d(0, 0px, 0) scale(1)", "1", "z-30 bg-zinc-950 shadow-xl" )
                        1 -> ( "translate3d(0, 14px, 0) scale(0.955)", "0.86", "z-20 bg-zinc-900 cursor-pointer" )
                        2 -> ( "translate3d(0, 26px, 0) scale(0.91)", "0.62", "z-10 bg-zinc-900 cursor-pointer" )
                        _ -> ( "translate3d(0, -14px, 0) scale(0.94)", "0", "z-0 pointer-events-none bg-zinc-900" )
            in
            div
                ([ Attr.class ("absolute inset-x-0 top-0 rounded-[16px] p-5 space-y-3 select-none transition-[transform,opacity] duration-420 ease-[cubic-bezier(0.22,1,0.36,1)] " ++ zCls)
                 , Attr.style "transform" tf
                 , Attr.style "opacity" op
                 , Attr.style "transform-origin" "50% 100%"
                 ]
                    ++ (if rel == 0 then [] else [ Events.onClick (cfg.onSelect idx) ])
                )
                [ div [ Attr.class "flex items-center justify-between" ]
                    [ span [ Attr.class "font-semibold text-base text-zinc-100" ] [ text slide.name ]
                    , span [ Attr.class "rounded-sm bg-[#b8a8ff] px-2 py-0.5 font-mono text-[10px] text-[#120d26]" ] [ text slide.tag ]
                    ]
                , p [ Attr.class "text-[13px] text-zinc-400" ] [ text slide.summary ]
                ]
    in
    div [ Attr.class "w-full max-w-md space-y-5" ]
        [ div [ Attr.class "relative h-[186px]" ] (List.indexedMap renderCard slides)
        , div [ Attr.class "flex items-center justify-between" ]
            [ div [ Attr.class "flex items-center gap-1.5" ]
                (List.indexedMap
                    (\idx _ ->
                        button
                            [ Attr.type_ "button"
                            , Events.onClick (cfg.onSelect idx)
                            , Attr.class ("h-1.5 rounded-full transition-all duration-300 cursor-pointer " ++ if idx == activeIdx then "w-7 bg-[#b8a8ff]" else "w-2 bg-zinc-800")
                            ]
                            []
                    )
                    slides
                )
            , div [ Attr.class "flex items-center gap-1" ]
                [ button [ Attr.type_ "button", Events.onClick (cfg.onStep -1), Attr.class "size-7 rounded-lg bg-zinc-950 font-mono text-xs text-zinc-100 cursor-pointer" ] [ text "←" ]
                , button [ Attr.type_ "button", Events.onClick (cfg.onStep 1), Attr.class "size-7 rounded-lg bg-zinc-950 font-mono text-xs text-zinc-100 cursor-pointer" ] [ text "→" ]
                ]
            ]
        ]
```
::
