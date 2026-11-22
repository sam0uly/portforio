module GrainientBg exposing (view)

import Html exposing (Html, node)
import Html.Attributes as Attr
import Theme exposing (Theme(..))


view : Theme -> Bool -> Html msg
view theme motionPlaying =
    let
        isLight =
            case theme of
                Light ->
                    "true"

                Dark ->
                    "false"

        isPaused =
            if motionPlaying then
                "false"

            else
                "true"
    in
    node "grainient-bg"
        [ Attr.attribute "aria-hidden" "true"
        , Attr.attribute "light-mode" isLight
        , Attr.attribute "paused" isPaused
        , Attr.attribute "colors" "#0c0a14,#2b55b3,#8b75ff,#ff4fbf,#ff985a"
        , Attr.attribute "grain-amount" "0.08"
        , Attr.attribute "silk" "0.38"
        , Attr.attribute "flow" "0.95"
        , Attr.attribute "speed" "1.0"
        , Attr.class "fixed inset-0 z-0 block w-full h-full pointer-events-none select-none"
        ]
        []
