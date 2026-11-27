module Effects.GrainientBg exposing (view)

import Data.Theme exposing (Theme(..))
import Html exposing (Html, node)
import Html.Attributes as Attr


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
        , Attr.class "fixed inset-0 z-0 block w-full h-full pointer-events-none select-none"
        ]
        []
