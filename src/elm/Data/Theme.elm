module Data.Theme exposing (Theme(..), isLightFloat, toggle)


type Theme
    = Dark
    | Light


toggle : Theme -> Theme
toggle current =
    case current of
        Dark ->
            Light

        Light ->
            Dark


isLightFloat : Theme -> Float
isLightFloat theme =
    case theme of
        Dark ->
            0.0

        Light ->
            1.0
