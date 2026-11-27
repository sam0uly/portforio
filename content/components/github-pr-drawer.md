---
title: GitHub PR Wing Drawer
category: Data
order: 9
preview: github-pr-drawer
summary: Filterable pull request feed with sliding segmented tabs, state badges, diff stats, and progressive edge blur.
tags:
  - GitHub
  - Drawer
  - Tabs
---

The Pull Requests wing panel attached to the GitHub section. Combines a Bayer-dithered `PRs` header pill, sliding segmented filter tabs (**All**, **Merged**, **Open**), compact PR cards with repository names and `+add / -del` diff counts, and progressive blur edge masks on the scrollable list.

::framework{name="vue"}
### Usage
```vue [PrWingDemo.vue]
<script setup lang="ts">
import PrWingDrawer, { type PullRequest } from './PrWingDrawer.vue';

const prs: PullRequest[] = [
  { number: 412, title: 'feat(diff): virtualize large hunk streams', repo: 'sam0uly/twig', state: 'merged', additions: 318, deletions: 42 },
  { number: 109, title: 'fix(layer-shell): handle output hotplug', repo: 'sam0uly/mural', state: 'open', additions: 84, deletions: 19 },
  { number: 88, title: 'refactor(flake): split niri & hyprland modules', repo: 'sam0uly/samouly-flake', state: 'merged', additions: 142, deletions: 96 },
];
</script>

<template>
  <PrWingDrawer :prs="prs" />
</template>
```

### Source
```vue [PrWingDrawer.vue]
<script setup lang="ts">
import { computed, ref } from 'vue';

export interface PullRequest {
  number: number;
  title: string;
  repo: string;
  state: 'merged' | 'open';
  additions: number;
  deletions: number;
}

const props = defineProps<{ prs: PullRequest[] }>();

const tabs = ['all', 'merged', 'open'] as const;
const filter = ref<(typeof tabs)[number]>('all');
const activeIdx = computed(() => tabs.indexOf(filter.value));
const filtered = computed(() =>
  filter.value === 'all' ? props.prs : props.prs.filter((p) => p.state === filter.value)
);
</script>

<template>
  <div class="w-full max-w-sm rounded-[16px] bg-zinc-950 p-4 space-y-3">
    <div class="flex items-center justify-between">
      <span class="inline-flex items-center rounded-sm bg-[#b8a8ff] px-2 py-0.5 font-mono text-[10px] font-medium text-[#120d26]">
        PRs · {{ prs.length }}
      </span>
      <span class="font-mono text-[10.5px] text-zinc-500">{{ filtered.length }} shown</span>
    </div>

    <div class="relative grid grid-cols-3 p-0.5 rounded-[12px] bg-zinc-900">
      <div
        aria-hidden="true"
        class="pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 w-[calc((100%-4px)/3)] rounded-[10px] bg-zinc-800 transition-transform duration-200 ease-out"
        :style="{ transform: `translate3d(${activeIdx * 100}%, 0, 0)` }"
      />
      <button
        v-for="tab in tabs"
        :key="tab"
        type="button"
        @click="filter = tab"
        :class="[
          'relative z-10 py-1 font-mono text-[10.5px] capitalize cursor-pointer transition-colors',
          filter === tab ? 'text-zinc-100 font-medium' : 'text-zinc-500 hover:text-zinc-300',
        ]"
      >
        {{ tab }}
      </button>
    </div>

    <div class="max-h-52 overflow-y-auto space-y-2 pr-0.5">
      <div
        v-for="pr in filtered"
        :key="`${pr.repo}-${pr.number}`"
        class="rounded-[12px] bg-zinc-900/75 px-3 py-2.5 space-y-1 transition-colors hover:bg-zinc-800/75"
      >
        <div class="flex items-center justify-between gap-2 font-mono text-[10px]">
          <span class="text-zinc-400 truncate">{{ pr.repo }} #{{ pr.number }}</span>
          <span :class="pr.state === 'merged' ? 'text-[#b8a8ff]' : 'text-[#7ee7be]'">
            {{ pr.state }}
          </span>
        </div>
        <p class="text-xs font-medium text-zinc-100 leading-snug">{{ pr.title }}</p>
        <div class="font-mono text-[10px] flex items-center gap-2">
          <span class="text-[#7ee7be]">+{{ pr.additions }}</span>
          <span class="text-[#ffc482]">-{{ pr.deletions }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [PrWingDemo.tsx]
import { PrWingDrawer, type PullRequest } from './PrWingDrawer';

const prs: PullRequest[] = [
  { number: 412, title: 'feat(diff): virtualize large hunk streams', repo: 'sam0uly/twig', state: 'merged', additions: 318, deletions: 42 },
  { number: 109, title: 'fix(layer-shell): handle output hotplug', repo: 'sam0uly/mural', state: 'open', additions: 84, deletions: 19 },
  { number: 88, title: 'refactor(flake): split niri & hyprland modules', repo: 'sam0uly/samouly-flake', state: 'merged', additions: 142, deletions: 96 },
];

export function PrWingDemo() {
  return <PrWingDrawer prs={prs} />;
}
```

### Source
```tsx [PrWingDrawer.tsx]
import { useState } from 'react';

export interface PullRequest {
  number: number;
  title: string;
  repo: string;
  state: 'merged' | 'open';
  additions: number;
  deletions: number;
}

const TABS = ['all', 'merged', 'open'] as const;

export function PrWingDrawer({ prs }: { prs: PullRequest[] }) {
  const [filter, setFilter] = useState<(typeof TABS)[number]>('all');
  const activeIdx = TABS.indexOf(filter);
  const filtered = filter === 'all' ? prs : prs.filter((p) => p.state === filter);

  return (
    <div className="w-full max-w-sm rounded-[16px] bg-zinc-950 p-4 space-y-3">
      <div className="flex items-center justify-between">
        <span className="inline-flex items-center rounded-sm bg-[#b8a8ff] px-2 py-0.5 font-mono text-[10px] font-medium text-[#120d26]">
          PRs · {prs.length}
        </span>
        <span className="font-mono text-[10.5px] text-zinc-500">{filtered.length} shown</span>
      </div>

      <div className="relative grid grid-cols-3 p-0.5 rounded-[12px] bg-zinc-900">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 w-[calc((100%-4px)/3)] rounded-[10px] bg-zinc-800 transition-transform duration-200 ease-out"
          style={{ transform: `translate3d(${activeIdx * 100}%, 0, 0)` }}
        />
        {TABS.map((tab) => (
          <button
            key={tab}
            type="button"
            onClick={() => setFilter(tab)}
            className={`relative z-10 py-1 font-mono text-[10.5px] capitalize cursor-pointer transition-colors ${
              filter === tab ? 'text-zinc-100 font-medium' : 'text-zinc-500 hover:text-zinc-300'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      <div className="max-h-52 overflow-y-auto space-y-2 pr-0.5">
        {filtered.map((pr) => (
          <div
            key={`${pr.repo}-${pr.number}`}
            className="rounded-[12px] bg-zinc-900/75 px-3 py-2.5 space-y-1 transition-colors hover:bg-zinc-800/75"
          >
            <div className="flex items-center justify-between gap-2 font-mono text-[10px]">
              <span className="text-zinc-400 truncate">
                {pr.repo} #{pr.number}
              </span>
              <span className={pr.state === 'merged' ? 'text-[#b8a8ff]' : 'text-[#7ee7be]'}>
                {pr.state}
              </span>
            </div>
            <p className="text-xs font-medium text-zinc-100 leading-snug">{pr.title}</p>
            <div className="font-mono text-[10px] flex items-center gap-2">
              <span className="text-[#7ee7be]">+{pr.additions}</span>
              <span className="text-[#ffc482]">-{pr.deletions}</span>
            </div>
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
```elm [Main.elm]
viewPrWing : Model -> Html Msg
viewPrWing model =
    PrWingDrawer.view SetPrFilter model.prFilter model.pullRequests
```

### Source
```elm [PrWingDrawer.elm]
module PrWingDrawer exposing (Filter(..), PullRequest, view)

import Html exposing (Html, button, div, p, span, text)
import Html.Attributes as Attr
import Html.Events as Events


type Filter
    = All
    | Merged
    | Open


type alias PullRequest =
    { number : Int
    , title : String
    , repo : String
    , merged : Bool
    , additions : Int
    , deletions : Int
    }


view : (Filter -> msg) -> Filter -> List PullRequest -> Html msg
view onFilter active prs =
    let
        idx =
            case active of
                All -> 0
                Merged -> 1
                Open -> 2

        filtered =
            case active of
                All -> prs
                Merged -> List.filter .merged prs
                Open -> List.filter (not << .merged) prs

        tabBtn target label =
            button
                [ Attr.type_ "button"
                , Events.onClick (onFilter target)
                , Attr.class
                    ("relative z-10 py-1 font-mono text-[10.5px] cursor-pointer "
                        ++ (if active == target then "text-zinc-100 font-medium" else "text-zinc-500")
                    )
                ]
                [ text label ]
    in
    div [ Attr.class "w-full max-w-sm rounded-[16px] bg-zinc-950 p-4 space-y-3" ]
        [ div [ Attr.class "relative grid grid-cols-3 p-0.5 rounded-[12px] bg-zinc-900" ]
            [ div
                [ Attr.class "pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 w-[calc((100%-4px)/3)] rounded-[10px] bg-zinc-800 transition-transform duration-200"
                , Attr.style "transform" ("translate3d(" ++ String.fromInt (idx * 100) ++ "%, 0, 0)")
                ]
                []
            , tabBtn All "All"
            , tabBtn Merged "Merged"
            , tabBtn Open "Open"
            ]
        , div [ Attr.class "max-h-52 overflow-y-auto space-y-2" ]
            (List.map
                (\pr ->
                    div [ Attr.class "rounded-[12px] bg-zinc-900/75 px-3 py-2.5 space-y-1" ]
                        [ div [ Attr.class "flex justify-between font-mono text-[10px] text-zinc-400" ]
                            [ span [] [ text (pr.repo ++ " #" ++ String.fromInt pr.number) ]
                            , span [] [ text (if pr.merged then "merged" else "open") ]
                            ]
                        , p [ Attr.class "text-xs font-medium text-zinc-100" ] [ text pr.title ]
                        ]
                )
                filtered
            )
        ]
```
::
