---
title: GitHub Contribution Graph
category: Data
order: 8
preview: github-contribution-graph
summary: Squircle contribution heatmap with a gliding focus reticle, GPU-positioned tooltip, and interactive intensity legend tray.
tags:
  - GitHub
  - SVG
  - Heatmap
---

The interactive contribution graph from the homepage GitHub section. Renders squircle day cells with a smooth gliding focus reticle, a week-column highlight band, an opaque `translate3d` floating tooltip, and an interactive intensity legend tray (`0–4`) that dims non-matching levels on hover or click while keeping matching cells hoverable.

::framework{name="vue"}
### Usage
```vue [ActivitySection.vue]
<script setup lang="ts">
import ContributionGraph, { type DayCell } from './ContributionGraph.vue';

const weeks: DayCell[][] = Array.from({ length: 24 }, (_, w) =>
  Array.from({ length: 7 }, (_, d) => ({
    date: `2026-0${((w % 6) + 1)}-${String((d * 3 + w) % 28 + 1).padStart(2, '0')}`,
    count: ((w * 7 + d * 3) % 11),
    level: ((w * 5 + d * 2) % 5) as 0 | 1 | 2 | 3 | 4,
  }))
);
</script>

<template>
  <ContributionGraph :weeks="weeks" />
</template>
```

### Source
```vue [ContributionGraph.vue]
<script setup lang="ts">
import { computed, ref } from 'vue';

export interface DayCell {
  date: string;
  count: number;
  level: 0 | 1 | 2 | 3 | 4;
}

const props = defineProps<{ weeks: DayCell[][] }>();

const COLORS = ['#18181f', '#362e63', '#5c4bc4', '#8b75ff', '#d4c9ff'];
const SQUIRCLE = 'M5 0C8.6 0 10 1.4 10 5C10 8.6 8.6 10 5 10C1.4 10 0 8.6 0 5C0 1.4 1.4 0 5 0Z';
const STEP = 13;

const hovered = ref<{ w: number; d: number; day: DayCell } | null>(null);
const lastHovered = ref<{ w: number; d: number; day: DayCell } | null>(null);
const hoverLevel = ref<number | null>(null);
const pinnedLevel = ref<number | null>(null);

const activeLevel = computed(() => hoverLevel.value ?? pinnedLevel.value);
const anchor = computed(() => hovered.value ?? lastHovered.value);
const svgWidth = computed(() => Math.max(1, props.weeks.length * STEP - 3));

function onCellEnter(w: number, d: number, day: DayCell) {
  const hit = { w, d, day };
  hovered.value = hit;
  lastHovered.value = hit;
}
</script>

<template>
  <div class="w-full space-y-3">
    <div class="relative pt-9 overflow-x-auto" @mouseleave="hovered = null">
      <div
        v-if="anchor"
        class="pointer-events-none absolute top-0 left-0 z-20 rounded-[10px] bg-zinc-900 px-2.5 py-1 font-mono text-[11px] text-zinc-100 whitespace-nowrap shadow-lg transition-[transform,opacity] duration-150 ease-out"
        :style="{
          transform: `translate3d(${Math.max(4, Math.min(svgWidth - 130, anchor.w * STEP - 40))}px, 0, 0)`,
          opacity: hovered ? 1 : 0,
        }"
      >
        <span class="font-medium">{{ anchor.day.count }} commits</span>
        <span class="text-zinc-400"> · {{ anchor.day.date }}</span>
      </div>

      <svg
        :viewBox="`0 0 ${svgWidth} ${7 * STEP - 3}`"
        class="block w-full h-auto overflow-visible"
      >
        <rect
          v-if="anchor"
          :x="anchor.w * STEP - 1.5"
          y="-1.5"
          width="13"
          :height="7 * STEP"
          rx="4"
          fill="rgba(255,255,255,0.04)"
          :opacity="hovered ? 1 : 0"
          class="transition-all duration-150"
        />

        <g v-for="(week, w) in weeks" :key="w">
          <g
            v-for="(day, d) in week"
            :key="day.date"
            :transform="`translate(${w * STEP}, ${d * STEP})`"
            :opacity="activeLevel !== null && day.level !== activeLevel ? 0.16 : 1"
            class="cursor-pointer transition-opacity duration-150"
            @mouseenter="onCellEnter(w, d, day)"
          >
            <path :d="SQUIRCLE" :fill="COLORS[day.level]" />
          </g>
        </g>

        <rect
          v-if="anchor"
          :x="anchor.w * STEP - 1"
          :y="anchor.d * STEP - 1"
          width="12"
          height="12"
          rx="3.5"
          fill="none"
          stroke="#f4f4f6"
          stroke-width="1.25"
          :opacity="hovered ? 1 : 0"
          class="pointer-events-none transition-all duration-150"
        />
      </svg>
    </div>

    <div class="flex items-center justify-end gap-2 font-mono text-[10.5px] text-zinc-400" @mouseleave="hoverLevel = null">
      <div class="inline-flex items-center gap-1 rounded-[12px] bg-zinc-800/65 px-2.5 py-1">
        <span class="mr-1">Less</span>
        <button
          v-for="(col, lvl) in COLORS"
          :key="lvl"
          type="button"
          class="p-0.5 cursor-pointer transition-transform duration-150"
          :class="activeLevel === lvl ? 'scale-125' : 'hover:scale-115'"
          :style="{ opacity: activeLevel !== null && activeLevel !== lvl ? 0.35 : 1 }"
          @mouseenter="hoverLevel = lvl"
          @click="pinnedLevel = pinnedLevel === lvl ? null : lvl"
        >
          <svg viewBox="0 0 10 10" class="block size-[11px]"><path :d="SQUIRCLE" :fill="col" /></svg>
        </button>
        <span class="ml-1">More</span>
      </div>
    </div>
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [ActivitySection.tsx]
import { ContributionGraph, type DayCell } from './ContributionGraph';

const weeks: DayCell[][] = Array.from({ length: 24 }, (_, w) =>
  Array.from({ length: 7 }, (_, d) => ({
    date: `2026-0${(w % 6) + 1}-${String(((d * 3 + w) % 28) + 1).padStart(2, '0')}`,
    count: (w * 7 + d * 3) % 11,
    level: ((w * 5 + d * 2) % 5) as 0 | 1 | 2 | 3 | 4,
  }))
);

export function ActivitySection() {
  return <ContributionGraph weeks={weeks} />;
}
```

### Source
```tsx [ContributionGraph.tsx]
import { useState } from 'react';

export interface DayCell {
  date: string;
  count: number;
  level: 0 | 1 | 2 | 3 | 4;
}

const COLORS = ['#18181f', '#362e63', '#5c4bc4', '#8b75ff', '#d4c9ff'];
const SQUIRCLE = 'M5 0C8.6 0 10 1.4 10 5C10 8.6 8.6 10 5 10C1.4 10 0 8.6 0 5C0 1.4 1.4 0 5 0Z';
const STEP = 13;

export function ContributionGraph({ weeks }: { weeks: DayCell[][] }) {
  const [hovered, setHovered] = useState<{ w: number; d: number; day: DayCell } | null>(null);
  const [lastHovered, setLastHovered] = useState<{ w: number; d: number; day: DayCell } | null>(null);
  const [hoverLevel, setHoverLevel] = useState<number | null>(null);
  const [pinnedLevel, setPinnedLevel] = useState<number | null>(null);

  const activeLevel = hoverLevel ?? pinnedLevel;
  const anchor = hovered ?? lastHovered;
  const svgWidth = Math.max(1, weeks.length * STEP - 3);

  return (
    <div className="w-full space-y-3">
      <div className="relative pt-9 overflow-x-auto" onMouseLeave={() => setHovered(null)}>
        {anchor && (
          <div
            className="pointer-events-none absolute top-0 left-0 z-20 rounded-[10px] bg-zinc-900 px-2.5 py-1 font-mono text-[11px] text-zinc-100 whitespace-nowrap shadow-lg transition-[transform,opacity] duration-150 ease-out"
            style={{
              transform: `translate3d(${Math.max(4, Math.min(svgWidth - 130, anchor.w * STEP - 40))}px, 0, 0)`,
              opacity: hovered ? 1 : 0,
            }}
          >
            <span className="font-medium">{anchor.day.count} commits</span>
            <span className="text-zinc-400"> · {anchor.day.date}</span>
          </div>
        )}

        <svg viewBox={`0 0 ${svgWidth} ${7 * STEP - 3}`} className="block w-full h-auto overflow-visible">
          {anchor && (
            <rect
              x={anchor.w * STEP - 1.5}
              y={-1.5}
              width={13}
              height={7 * STEP}
              rx={4}
              fill="rgba(255,255,255,0.04)"
              opacity={hovered ? 1 : 0}
              className="transition-all duration-150"
            />
          )}

          {weeks.map((week, w) =>
            week.map((day, d) => (
              <g
                key={day.date}
                transform={`translate(${w * STEP}, ${d * STEP})`}
                opacity={activeLevel !== null && day.level !== activeLevel ? 0.16 : 1}
                className="cursor-pointer transition-opacity duration-150"
                onMouseEnter={() => {
                  const hit = { w, d, day };
                  setHovered(hit);
                  setLastHovered(hit);
                }}
              >
                <path d={SQUIRCLE} fill={COLORS[day.level]} />
              </g>
            ))
          )}

          {anchor && (
            <rect
              x={anchor.w * STEP - 1}
              y={anchor.d * STEP - 1}
              width={12}
              height={12}
              rx={3.5}
              fill="none"
              stroke="#f4f4f6"
              strokeWidth={1.25}
              opacity={hovered ? 1 : 0}
              className="pointer-events-none transition-all duration-150"
            />
          )}
        </svg>
      </div>

      <div
        className="flex items-center justify-end gap-2 font-mono text-[10.5px] text-zinc-400"
        onMouseLeave={() => setHoverLevel(null)}
      >
        <div className="inline-flex items-center gap-1 rounded-[12px] bg-zinc-800/65 px-2.5 py-1">
          <span className="mr-1">Less</span>
          {COLORS.map((col, lvl) => (
            <button
              key={lvl}
              type="button"
              onMouseEnter={() => setHoverLevel(lvl)}
              onClick={() => setPinnedLevel((p) => (p === lvl ? null : lvl))}
              className={`p-0.5 cursor-pointer transition-transform duration-150 ${
                activeLevel === lvl ? 'scale-125' : 'hover:scale-115'
              }`}
              style={{ opacity: activeLevel !== null && activeLevel !== lvl ? 0.35 : 1 }}
            >
              <svg viewBox="0 0 10 10" className="block size-[11px]">
                <path d={SQUIRCLE} fill={col} />
              </svg>
            </button>
          ))}
          <span className="ml-1">More</span>
        </div>
      </div>
    </div>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Main.elm]
viewGithub : Model -> Html Msg
viewGithub model =
    ContributionGraph.view
        { onHover = HoverDay
        , onLeave = LeaveGrid
        , onPinLevel = ToggleLevel
        }
        model.hoveredDay
        model.pinnedLevel
        model.weeks
```

### Source
```elm [ContributionGraph.elm]
module ContributionGraph exposing (DayCell, HoveredCell, view)

import Html exposing (Html, button, div, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Svg exposing (g, path, rect, svg)
import Svg.Attributes as SvgAttr


type alias DayCell =
    { date : String
    , count : Int
    , level : Int
    }


type alias HoveredCell =
    { week : Int
    , day : Int
    , cell : DayCell
    }


squircle : String
squircle =
    "M5 0C8.6 0 10 1.4 10 5C10 8.6 8.6 10 5 10C1.4 10 0 8.6 0 5C0 1.4 1.4 0 5 0Z"


levelColor : Int -> String
levelColor lvl =
    case lvl of
        1 -> "#362e63"
        2 -> "#5c4bc4"
        3 -> "#8b75ff"
        4 -> "#d4c9ff"
        _ -> "#18181f"


view :
    { onHover : HoveredCell -> msg
    , onLeave : msg
    , onPinLevel : Int -> msg
    }
    -> Maybe HoveredCell
    -> Maybe Int
    -> List (List DayCell)
    -> Html msg
view cfg hovered activeLevel weeks =
    let
        step = 13
        wCount = List.length weeks
        svgW = max 1 (wCount * step - 3)
    in
    div [ Attr.class "w-full space-y-3" ]
        [ div [ Attr.class "relative pt-9 overflow-x-auto", Events.onMouseLeave cfg.onLeave ]
            [ case hovered of
                Just h ->
                    div
                        [ Attr.class "pointer-events-none absolute top-0 left-0 z-20 rounded-[10px] bg-zinc-900 px-2.5 py-1 font-mono text-[11px] text-zinc-100 whitespace-nowrap"
                        , Attr.style "transform" ("translate3d(" ++ String.fromInt (max 4 (h.week * step - 40)) ++ "px, 0, 0)")
                        ]
                        [ text (String.fromInt h.cell.count ++ " commits · " ++ h.cell.date) ]

                Nothing ->
                    text ""
            , svg
                [ SvgAttr.viewBox ("0 0 " ++ String.fromInt svgW ++ " 88")
                , SvgAttr.class "block w-full h-auto overflow-visible"
                ]
                (List.indexedMap
                    (\w week ->
                        g []
                            (List.indexedMap
                                (\d cell ->
                                    g
                                        [ SvgAttr.transform ("translate(" ++ String.fromInt (w * step) ++ "," ++ String.fromInt (d * step) ++ ")")
                                        , SvgAttr.opacity
                                            (if activeLevel /= Nothing && activeLevel /= Just cell.level then
                                                "0.16"
                                             else
                                                "1"
                                            )
                                        , Events.onMouseEnter (cfg.onHover { week = w, day = d, cell = cell })
                                        ]
                                        [ path [ SvgAttr.d squircle, SvgAttr.fill (levelColor cell.level) ] [] ]
                                )
                                week
                            )
                    )
                    weeks
                )
            ]
        , div [ Attr.class "flex justify-end font-mono text-[10.5px] text-zinc-400" ]
            [ div [ Attr.class "inline-flex items-center gap-1 rounded-[12px] bg-zinc-800/65 px-2.5 py-1" ]
                (span [ Attr.class "mr-1" ] [ text "Less" ]
                    :: List.map
                        (\lvl ->
                            button [ Attr.type_ "button", Events.onClick (cfg.onPinLevel lvl), Attr.class "p-0.5 cursor-pointer" ]
                                [ svg [ SvgAttr.viewBox "0 0 10 10", SvgAttr.class "block size-[11px]" ]
                                    [ path [ SvgAttr.d squircle, SvgAttr.fill (levelColor lvl) ] [] ]
                                ]
                        )
                        [ 0, 1, 2, 3, 4 ]
                    ++ [ span [ Attr.class "ml-1" ] [ text "More" ] ]
                )
            ]
        ]
```
::
