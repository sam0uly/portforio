---
title: Bayer Dither Divider
category: Effects
order: 6
preview: bayer-divider
summary: Hairline horizontal divider that dissolves at both ends through a 4x4 ordered Bayer matrix.
tags:
  - Divider
  - SVG
  - Dither
---

A lightweight crisp-edge SVG rule whose left and right quarters fade out pixel-by-pixel via a 4×4 Bayer threshold matrix. Inherits `currentColor`, so it adapts automatically to Dark and Light themes with zero CSS filters.

::framework{name="vue"}
### Usage
```vue [Section.vue]
<script setup lang="ts">
import BayerDivider from './BayerDivider.vue';
</script>

<template>
  <BayerDivider class="w-full max-w-md text-zinc-500/65" />
</template>
```

### Source
```vue [BayerDivider.vue]
<script setup lang="ts">
import { computed } from 'vue';

const BAYER4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

const props = withDefaults(defineProps<{ cols?: number }>(), { cols: 160 });

const rects = computed(() => {
  const fade = Math.floor(props.cols / 4);
  const out: Array<{ x: number; y: number; w: number }> = [
    { x: fade, y: 0, w: props.cols - fade * 2 },
  ];
  for (let x = 0; x < props.cols; x++) {
    if (x >= fade && x < props.cols - fade) continue;
    const dist = Math.min(x, props.cols - 1 - x);
    const density = (dist + 1) / (fade + 1);
    for (let y = 0; y < 2; y++) {
      const thr = (BAYER4[y % 4]![x % 4]! + 0.5) / 16;
      if (density > thr) out.push({ x, y, w: 1 });
    }
  }
  return out;
});
</script>

<template>
  <svg :viewBox="`0 0 ${cols} 2`" preserveAspectRatio="none" class="block h-[2px]" shape-rendering="crispEdges" aria-hidden="true">
    <rect v-for="(r, i) in rects" :key="i" :x="r.x" :y="r.y" :width="r.w" height="1" fill="currentColor" />
  </svg>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Section.tsx]
import { BayerDivider } from './BayerDivider';

export function Section() {
  return <BayerDivider className="w-full max-w-md text-zinc-500/65" />;
}
```

### Source
```tsx [BayerDivider.tsx]
const BAYER4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

export function BayerDivider({ cols = 160, className = 'w-full' }: { cols?: number; className?: string }) {
  const fade = Math.floor(cols / 4);
  const rects: Array<{ x: number; y: number; w: number }> = [{ x: fade, y: 0, w: cols - fade * 2 }];

  for (let x = 0; x < cols; x++) {
    if (x >= fade && x < cols - fade) continue;
    const dist = Math.min(x, cols - 1 - x);
    const density = (dist + 1) / (fade + 1);
    for (let y = 0; y < 2; y++) {
      const thr = (BAYER4[y % 4]![x % 4]! + 0.5) / 16;
      if (density > thr) rects.push({ x, y, w: 1 });
    }
  }

  return (
    <svg viewBox={`0 0 ${cols} 2`} preserveAspectRatio="none" className={`block h-[2px] ${className}`} shapeRendering="crispEdges" aria-hidden="true">
      {rects.map((r, i) => (
        <rect key={i} x={r.x} y={r.y} width={r.w} height="1" fill="currentColor" />
      ))}
    </svg>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Section.elm]
viewSeparator : Html msg
viewSeparator =
    BayerDivider.view 160 "w-full max-w-md text-zinc-500/65"
```

### Source
```elm [BayerDivider.elm]
module BayerDivider exposing (view)

import Html exposing (Html)
import Html.Attributes as Attr
import Svg exposing (rect, svg)
import Svg.Attributes as SvgAttr


view : Int -> String -> Html msg
view totalCols widthClass =
    let
        fadeCols =
            totalCols // 4

        bayer4 x y =
            case ( modBy 4 x, modBy 4 y ) of
                ( 0, 0 ) -> 0
                ( 2, 0 ) -> 8
                ( 0, 2 ) -> 12
                ( 2, 2 ) -> 4
                ( 1, 1 ) -> 10
                ( 3, 1 ) -> 2
                ( 1, 3 ) -> 6
                ( 3, 3 ) -> 14
                ( 0, 1 ) -> 15
                ( 2, 1 ) -> 7
                ( 0, 3 ) -> 3
                ( 2, 3 ) -> 11
                ( 1, 0 ) -> 13
                ( 3, 0 ) -> 5
                ( 1, 2 ) -> 9
                _ -> 1

        edgeCell x y =
            let
                dist =
                    min x (totalCols - 1 - x)

                density =
                    toFloat (dist + 1) / toFloat (fadeCols + 1)
            in
            if density > (toFloat (bayer4 x y) + 0.5) / 16.0 then
                Just (rect [ SvgAttr.x (String.fromInt x), SvgAttr.y (String.fromInt y), SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] [])

            else
                Nothing

        edges =
            (List.range 0 (fadeCols - 1) ++ List.range (totalCols - fadeCols) (totalCols - 1))
                |> List.concatMap (\x -> List.filterMap (edgeCell x) [ 0, 1 ])

        solid =
            rect [ SvgAttr.x (String.fromInt fadeCols), SvgAttr.y "0", SvgAttr.width (String.fromInt (totalCols - fadeCols * 2)), SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
    in
    svg [ SvgAttr.viewBox ("0 0 " ++ String.fromInt totalCols ++ " 2"), SvgAttr.preserveAspectRatio "none", SvgAttr.class ("block h-[2px] " ++ widthClass), Attr.attribute "shape-rendering" "crispEdges" ]
        (solid :: edges)
```
::
