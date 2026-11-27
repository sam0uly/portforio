---
title: Blog Card Group
category: Blog
order: 10
preview: card-group
summary: Responsive 2-column borderless squircle comparison cards used for structured blog pros/cons and takeaways.
tags:
  - Blog
  - Cards
  - Grid
---

Used inside Markdown blog posts via `::card-group` and `::card{title="..."}` directives to present side-by-side comparisons, tradeoffs, or grouped notes in clean borderless squircle cards.

::framework{name="vue"}
### Usage
```vue [Article.vue]
<script setup lang="ts">
import CardGroup from './CardGroup.vue';

const cards = [
  { title: 'Declarative', body: 'Your entire system is version-controlled in one flake.' },
  { title: 'Reproducible', body: 'Identical builds across laptops, CI, and servers.' },
];
</script>

<template>
  <CardGroup :cards="cards" />
</template>
```

### Source
```vue [CardGroup.vue]
<script setup lang="ts">
defineProps<{ cards: Array<{ title: string; body: string }> }>();
</script>

<template>
  <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
    <div v-for="card in cards" :key="card.title" class="p-4 rounded-[14px] bg-zinc-900/60 space-y-2">
      <p class="font-mono text-[11px] uppercase tracking-[0.14em] text-zinc-100">{{ card.title }}</p>
      <p class="text-[13.5px] leading-relaxed text-zinc-400">{{ card.body }}</p>
    </div>
  </div>
</template>
```
::

::framework{name="react"}
### Usage
```tsx [Article.tsx]
import { CardGroup } from './CardGroup';

export function Article() {
  return (
    <CardGroup
      cards={[
        { title: 'Declarative', body: 'Your entire system is version-controlled in one flake.' },
        { title: 'Reproducible', body: 'Identical builds across laptops, CI, and servers.' },
      ]}
    />
  );
}
```

### Source
```tsx [CardGroup.tsx]
export function CardGroup({ cards }: { cards: readonly { title: string; body: string }[] }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
      {cards.map((card) => (
        <div key={card.title} className="p-4 rounded-[14px] bg-zinc-900/60 space-y-2">
          <p className="font-mono text-[11px] uppercase tracking-[0.14em] text-zinc-100">{card.title}</p>
          <p className="text-[13.5px] leading-relaxed text-zinc-400">{card.body}</p>
        </div>
      ))}
    </div>
  );
}
```
::

::framework{name="elm"}
### Usage
```elm [Article.elm]
viewComparison : Html msg
viewComparison =
    CardGroup.view
        [ { title = "Declarative", body = "Your entire system is version-controlled in one flake." }
        , { title = "Reproducible", body = "Identical builds across laptops, CI, and servers." }
        ]
```

### Source
```elm [CardGroup.elm]
module CardGroup exposing (view)

import Html exposing (Html, div, p, text)
import Html.Attributes as Attr


view : List { title : String, body : String } -> Html msg
view cards =
    div [ Attr.class "grid grid-cols-1 sm:grid-cols-2 gap-3" ]
        (List.map
            (\c ->
                div [ Attr.class "p-4 box-squircle bg-[var(--tab-bg)]/55 space-y-2" ]
                    [ p [ Attr.class "font-mono text-[11px] uppercase tracking-[0.14em] text-[var(--page-fg)]" ] [ text c.title ]
                    , p [ Attr.class "text-[13.5px] leading-relaxed text-[var(--page-muted)]" ] [ text c.body ]
                    ]
            )
            cards
        )
```
::
