port module Main exposing (main)

import BayerMask
import Browser
import Browser.Events
import DitherFooter
import DitherTop
import GrainientBg
import Html exposing (Html, a, button, div, footer, h1, h2, li, main_, p, section, span, text, ul)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Lazy as Lazy
import Json.Decode as Decode exposing (Decoder)
import Process
import Svg exposing (rect, svg)
import Svg.Attributes as SvgAttr
import Task
import Theme exposing (Theme(..))


port copyToClipboard : String -> Cmd msg


port clipboardResult : (Bool -> msg) -> Sub msg


port reducedMotionChanged : (Bool -> msg) -> Sub msg


port setTheme : String -> Cmd msg


type alias Flags =
    { currentYear : String
    , diveDepthMeters : String
    , prefersReducedMotion : Bool
    }


type alias Project =
    { name : String
    , summary : String
    , tag : String
    , url : String
    }


type CopyState
    = CopyIdle
    | CopySucceeded
    | CopyFailed


type alias Model =
    { flags : Flags
    , theme : Theme
    , motionPlaying : Bool
    , bayerMask : BayerMask.Model
    , ditherTop : DitherTop.Model
    , ditherFooter : DitherFooter.Model
    , copyState : CopyState
    , liveAnnouncement : String
    }


type Msg
    = TopDitherMsg DitherTop.Msg
    | FooterDitherMsg DitherFooter.Msg
    | AnimationTick Float
    | ToggleTheme
    | ToggleMotion
    | ReducedMotionChanged Bool
    | CopyEmail
    | GotClipboardResult Bool
    | ResetCopyState


emailAddress : String
emailAddress =
    "alasamouly@gmail.com"


defaultFlags : Flags
defaultFlags =
    { currentYear = "2026"
    , diveDepthMeters = "35"
    , prefersReducedMotion = False
    }


decodeFlags : Decoder Flags
decodeFlags =
    Decode.map3 Flags
        (Decode.field "currentYear" Decode.string)
        (Decode.field "diveDepthMeters" Decode.string)
        (Decode.field "prefersReducedMotion" Decode.bool)


projects : List Project
projects =
    [ { name = "Twig"
      , summary = "Live diff viewer for working trees bigger than your screen"
      , tag = "Building"
      , url = "https://github.com/sam0uly/twig"
      }
    , { name = "mural"
      , summary = "Terminal wallpaper manager with a pure Go Wayland daemon"
      , tag = "Go · TUI"
      , url = "https://github.com/sam0uly/mural"
      }
    , { name = "Spin"
      , summary = "Language-agnostic project template CLI"
      , tag = "Go"
      , url = "https://spincli.pages.dev"
      }
    , { name = "bubbleMonitor"
      , summary = "Terminal system monitor built with Bubble\u{00A0}Tea"
      , tag = "TUI"
      , url = "https://github.com/sam0uly/bubbleMonitor"
      }
    , { name = "Mditor"
      , summary = "Terminal markdown editor on Charm libraries"
      , tag = "Charm"
      , url = "https://github.com/sam0uly/mditor"
      }
    , { name = "HyprLuna"
      , summary = "Arch\u{00A0}Linux desktop shell for Hyprland and Ags"
      , tag = "Hyprland"
      , url = "https://github.com/Lunaris-Project/HyprLuna"
      }
    , { name = "Samouly\u{00A0}Flake"
      , summary = "Declarative NixOS setup for Hyprland and Niri"
      , tag = "NixOS"
      , url = "https://github.com/sam0uly/samouly-flake"
      }
    , { name = "SamoulyVim"
      , summary = "Personal Neovim configuration written in Lua"
      , tag = "Neovim"
      , url = "https://github.com/sam0uly/SamoulyVim"
      }
    ]


main : Program Decode.Value Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init : Decode.Value -> ( Model, Cmd Msg )
init rawFlags =
    let
        decodedFlags =
            Decode.decodeValue decodeFlags rawFlags |> Result.withDefault defaultFlags

        ( topModel, topCmd ) =
            DitherTop.init decodedFlags.prefersReducedMotion
    in
    ( { flags = decodedFlags
      , theme = Dark
      , motionPlaying = not decodedFlags.prefersReducedMotion
      , bayerMask = BayerMask.init decodedFlags.prefersReducedMotion
      , ditherTop = topModel
      , ditherFooter = DitherFooter.init decodedFlags.prefersReducedMotion
      , copyState = CopyIdle
      , liveAnnouncement = ""
      }
    , Cmd.map TopDitherMsg topCmd
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        needsFrames =
            model.motionPlaying
                || BayerMask.isAnimating model.bayerMask
                || DitherTop.isAnimating model.ditherTop
                || DitherFooter.isAnimating model.ditherFooter
    in
    Sub.batch
        [ clipboardResult GotClipboardResult
        , reducedMotionChanged ReducedMotionChanged
        , if needsFrames then
            Browser.Events.onAnimationFrameDelta AnimationTick

          else
            Sub.none
        ]


themeToString : Theme -> String
themeToString theme =
    case theme of
        Dark ->
            "dark"

        Light ->
            "light"


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TopDitherMsg subMsg ->
            ( { model | ditherTop = DitherTop.update subMsg model.ditherTop }
            , Cmd.none
            )

        FooterDitherMsg subMsg ->
            ( { model | ditherFooter = DitherFooter.update subMsg model.ditherFooter }
            , Cmd.none
            )

        AnimationTick dtMs ->
            let
                ( nextMask, maybeSwappedTheme ) =
                    BayerMask.tick dtMs model.bayerMask

                ( nextTheme, themeCmd ) =
                    case maybeSwappedTheme of
                        Just target ->
                            ( target, setTheme (themeToString target) )

                        Nothing ->
                            ( model.theme, Cmd.none )
            in
            ( { model
                | theme = nextTheme
                , bayerMask = nextMask
                , ditherTop = DitherTop.tick model.motionPlaying dtMs model.ditherTop
                , ditherFooter = DitherFooter.tick model.motionPlaying dtMs model.ditherFooter
              }
            , themeCmd
            )

        ToggleTheme ->
            let
                targetTheme =
                    Theme.toggle model.theme

                announcement =
                    case targetTheme of
                        Light ->
                            "Switched to light theme."

                        Dark ->
                            "Switched to dark theme."

                ( nextMask, immediateSwap ) =
                    BayerMask.startThemeSwitch model.flags.prefersReducedMotion model.theme targetTheme model.bayerMask
            in
            case immediateSwap of
                Just swapped ->
                    ( { model
                        | theme = swapped
                        , bayerMask = nextMask
                        , liveAnnouncement = announcement
                      }
                    , setTheme (themeToString swapped)
                    )

                Nothing ->
                    ( { model
                        | bayerMask = nextMask
                        , liveAnnouncement = announcement
                      }
                    , Cmd.none
                    )

        ToggleMotion ->
            let
                nextPlaying =
                    not model.motionPlaying
            in
            ( { model
                | motionPlaying = nextPlaying
                , liveAnnouncement =
                    if nextPlaying then
                        "Motion resumed."

                    else
                        "Motion paused."
              }
            , Cmd.none
            )

        ReducedMotionChanged prefersReduced ->
            let
                currentFlags =
                    model.flags
            in
            ( { model
                | flags = { currentFlags | prefersReducedMotion = prefersReduced }
                , motionPlaying = not prefersReduced
              }
            , Cmd.none
            )

        CopyEmail ->
            ( { model | liveAnnouncement = "Copying email…" }
            , copyToClipboard emailAddress
            )

        GotClipboardResult succeeded ->
            if succeeded then
                ( { model
                    | copyState = CopySucceeded
                    , liveAnnouncement = "Email copied to clipboard."
                  }
                , Process.sleep 2200 |> Task.perform (\_ -> ResetCopyState)
                )

            else
                ( { model
                    | copyState = CopyFailed
                    , liveAnnouncement = "Clipboard unavailable. Open the email link directly."
                  }
                , Process.sleep 2800 |> Task.perform (\_ -> ResetCopyState)
                )

        ResetCopyState ->
            ( { model | copyState = CopyIdle }, Cmd.none )


focusRing : String
focusRing =
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--page-fg)] focus-visible:ring-offset-4 focus-visible:ring-offset-[var(--page-bg)]"


view : Model -> Browser.Document Msg
view model =
    { title = "Alaa El-Samouly (Samouly) | Software Engineer at Charm"
    , body =
        [ div
            [ Attr.class "fixed inset-0 h-dvh bg-transparent text-[var(--page-fg)] flex flex-col items-center overflow-hidden px-3 sm:px-6 select-none" ]
            [ Lazy.lazy2 GrainientBg.view model.theme model.motionPlaying
            , a
                [ Attr.href "#main-content"
                , Attr.class
                    ("sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:inline-flex focus:items-center focus:min-h-11 focus:px-4 focus:rounded-sm focus:bg-[var(--page-fg)] focus:text-[var(--page-bg)] focus:text-sm focus:font-medium "
                        ++ focusRing
                    )
                ]
                [ text "Skip to Content" ]
            , div
                ([ Attr.id "content-sheet"
                 , Attr.attribute "data-grainient-shield" "true"
                 , Attr.class "sheet-squircle select-text relative z-10 mt-14 sm:mt-16 w-full max-w-[50rem] flex-1 min-h-0 flex flex-col bg-[var(--page-bg)] shadow-[var(--sheet-shadow)] overflow-hidden"
                 ]
                    ++ BayerMask.sheetBackgroundStyle model.theme model.bayerMask
                )
                [ div
                    [ Attr.id "dither-stage"
                    , Attr.class "scroll-clean flex-1 min-h-0 overflow-x-hidden overflow-y-auto flex flex-col justify-between"
                    ]
                    [ main_
                        [ Attr.id "main-content"
                        , Attr.tabindex -1
                        , Attr.class ("relative z-20 pointer-events-none w-full pl-5 pr-7 sm:px-10 pt-5 sm:pt-7 pb-3 flex-1 flex flex-col justify-start " ++ focusRing)
                        ]
                        [ div [ Attr.class "flex flex-col pointer-events-auto" ]
                            [ Lazy.lazy3 viewAbout model.flags.diveDepthMeters model.theme model.ditherTop
                            , Lazy.lazy viewWork ()
                            , Lazy.lazy4 viewContact model.flags.currentYear model.theme model.motionPlaying model.copyState
                            ]
                        ]
                    , Lazy.lazy2 viewFooter model.theme model.ditherFooter
                    ]
                , Lazy.lazy2 BayerMask.viewOverlay model.theme model.bayerMask
                , Lazy.lazy viewScrollTrack ()
                ]
            , div
                [ Attr.attribute "aria-live" "polite"
                , Attr.attribute "aria-atomic" "true"
                , Attr.class "sr-only"
                ]
                [ text model.liveAnnouncement ]
            ]
        ]
    }


viewScrollTrack : () -> Html Msg
viewScrollTrack _ =
    div
        [ Attr.id "mobile-scroll-track"
        , Attr.attribute "aria-hidden" "true"
        , Attr.style "opacity" "0"
        , Attr.style "pointer-events" "none"
        , Attr.class "cursor-pointer touch-none select-none absolute right-2 top-11 bottom-0 z-30 w-[11px] rounded-t-full rounded-b-none pt-[2.5px] px-[2.5px] pb-0 grainient-scroll-track transition-opacity duration-200 before:content-[''] before:absolute before:-inset-x-3 before:inset-y-0"
        ]
        [ div
            [ Attr.id "mobile-scroll-thumb"
            , Attr.class "w-full h-[40%] rounded-full grainient-scroll-thumb pointer-events-none"
            ]
            []
        ]



-- VERTICAL ROTATED SECTION HEADING WITH SOLID-BOTTOM TO TOP-DITHER CAP


viewVerticalLabel : String -> Html msg
viewVerticalLabel labelText =
    div [ Attr.class "flex flex-col items-start shrink-0" ]
        [ div
            [ Attr.class "inline-flex flex-col items-stretch w-6 sm:w-7"
            , Attr.style "color" "var(--tab-bg)"
            ]
            [ ditherCapSvg
            , span
                [ Attr.class "font-mono text-[9px] sm:text-[10px] uppercase tracking-[0.18em] py-2 sm:py-2.5 flex items-center justify-center leading-none"
                , Attr.style "background-color" "var(--tab-bg)"
                , Attr.style "color" "var(--tab-fg)"
                ]
                [ span [ Attr.class "vertical-heading" ] [ text labelText ] ]
            ]
        ]


viewVerticalHeading : String -> String -> Html msg
viewVerticalHeading headingId labelText =
    div [ Attr.class "flex flex-col items-start shrink-0" ]
        [ div
            [ Attr.class "inline-flex flex-col items-stretch w-6 sm:w-7"
            , Attr.style "color" "var(--tab-bg)"
            ]
            [ ditherCapSvg
            , h2
                [ Attr.id headingId
                , Attr.class "font-mono text-[9px] sm:text-[10px] uppercase tracking-[0.18em] py-2 sm:py-2.5 flex items-center justify-center leading-none"
                , Attr.style "background-color" "var(--tab-bg)"
                , Attr.style "color" "var(--tab-fg)"
                ]
                [ span [ Attr.class "vertical-heading" ] [ text labelText ] ]
            ]
        ]


ditherCapSvg : Html msg
ditherCapSvg =
    svg
        [ SvgAttr.viewBox "0 0 12 8"
        , SvgAttr.preserveAspectRatio "none"
        , SvgAttr.class "block w-full h-3.5 -mb-px"
        , Attr.attribute "shape-rendering" "crispEdges"
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        [ rect [ SvgAttr.x "1", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "5", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "9", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "3", SvgAttr.y "1", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "7", SvgAttr.y "1", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "11", SvgAttr.y "1", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "0", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "2", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "4", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "6", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "8", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "10", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "1", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "3", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "5", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "7", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "9", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "11", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "0", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "2", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "4", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "6", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "8", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "10", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "0", SvgAttr.y "5", SvgAttr.width "2", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "3", SvgAttr.y "5", SvgAttr.width "3", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "7", SvgAttr.y "5", SvgAttr.width "3", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "11", SvgAttr.y "5", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "0", SvgAttr.y "6", SvgAttr.width "4", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "5", SvgAttr.y "6", SvgAttr.width "4", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "10", SvgAttr.y "6", SvgAttr.width "2", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "0", SvgAttr.y "7", SvgAttr.width "12", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        ]



-- 1. ABOUT


viewAbout : String -> Theme -> DitherTop.Model -> Html Msg
viewAbout diveDepthMeters theme ditherTopModel =
    section
        [ Attr.id "about"
        , Attr.attribute "aria-labelledby" "about-heading"
        , Attr.class "scroll-mt-8 grid grid-cols-[1.5rem_1fr] sm:grid-cols-[2.75rem_1fr] gap-x-4 sm:gap-x-6 items-start"
        ]
        [ Lazy.lazy viewVerticalLabel "About"
        , div [ Attr.class "min-w-0 grid grid-cols-[1fr_auto] gap-x-4 sm:gap-x-5 items-center sm:items-start" ]
            [ Lazy.lazy viewAboutHeader ()
            , div [ Attr.class "col-start-2 row-start-1 sm:row-span-2 shrink-0" ]
                [ Lazy.lazy2 DitherTop.view theme ditherTopModel |> Html.map TopDitherMsg ]
            , Lazy.lazy viewAboutBio diveDepthMeters
            ]
        ]


viewAboutHeader : () -> Html Msg
viewAboutHeader _ =
    div [ Attr.class "flex flex-col sm:flex-row sm:flex-wrap sm:items-baseline gap-x-3 gap-y-0.5 min-w-0 sm:pt-1" ]
        [ h1
            [ Attr.id "about-heading"
            , Attr.attribute "translate" "no"
            , Attr.class "font-display font-semibold text-2xl sm:text-[2.125rem] leading-[1.08] tracking-[-0.03em] text-balance text-[var(--page-fg)]"
            ]
            [ text "Alaa\u{00A0}El-Samouly" ]
        , p [ Attr.class "font-mono text-xs text-[var(--page-subtle)]" ]
            [ text "Egypt" ]
        ]


viewAboutBio : String -> Html Msg
viewAboutBio diveDepthMeters =
    p [ Attr.class "col-span-2 sm:col-span-1 sm:col-start-1 mt-3 sm:mt-2.5 text-[14.5px] sm:text-[15px] leading-[1.62] text-pretty text-[var(--page-muted)]" ]
        [ text "Software engineer at "
        , a
            [ Attr.href "https://charm.land"
            , Attr.target "_blank"
            , Attr.rel "noopener noreferrer"
            , Attr.attribute "translate" "no"
            , Attr.class
                ("text-[var(--page-fg)] font-medium underline decoration-current/30 underline-offset-4 transition-[color,text-decoration-color] duration-150 hover:decoration-current rounded-xs "
                    ++ focusRing
                )
            ]
            [ text "Charm" ]
        , text ", building terminal interfaces and CLI tooling in "
        , span [ Attr.attribute "translate" "no", Attr.class "text-[var(--page-fg)] font-medium" ] [ text "Go" ]
        , text ", plus web applications in "
        , span [ Attr.attribute "translate" "no", Attr.class "text-[var(--page-fg)] font-medium" ] [ text "Nuxt" ]
        , text " and "
        , span [ Attr.attribute "translate" "no", Attr.class "text-[var(--page-fg)] font-medium" ] [ text "Vue" ]
        , text ". Outside work: tennis, freediving to "
        , span [ Attr.class "tabular-nums text-[var(--page-fg)]" ] [ text (diveDepthMeters ++ "\u{00A0}m") ]
        , text ", bird hunting, and riding a "
        , span [ Attr.attribute "translate" "no", Attr.class "text-[var(--page-fg)]" ] [ text "Lifan\u{00A0}KPV150" ]
        , text "."
        ]



-- 2. WORK


viewWork : () -> Html Msg
viewWork _ =
    section
        [ Attr.id "work"
        , Attr.attribute "aria-labelledby" "work-heading"
        , Attr.class "scroll-mt-8 mt-24 sm:mt-24 grid grid-cols-[1.5rem_1fr] sm:grid-cols-[2.75rem_1fr] gap-x-4 sm:gap-x-6 items-start"
        ]
        [ viewVerticalHeading "work-heading" "Work"
        , ul [ Attr.class "group/work min-w-0 divide-y divide-[var(--page-line)]" ]
            (List.map viewProjectRow projects)
        ]


viewProjectRow : Project -> Html Msg
viewProjectRow project =
    li [ Attr.class "min-w-0 transition-opacity duration-150 group-hover/work:opacity-40 hover:!opacity-100 focus-within:!opacity-100" ]
        [ a
            [ Attr.href project.url
            , Attr.target "_blank"
            , Attr.rel "noopener noreferrer"
            , Attr.class
                ("group block sm:flex sm:items-baseline sm:justify-between gap-x-4 py-2 sm:py-1.5 min-h-11 sm:min-h-0 rounded-xs "
                    ++ focusRing
                )
            ]
            [ div [ Attr.class "flex items-baseline justify-between sm:justify-start gap-x-3 min-w-0 sm:flex-1" ]
                [ span
                    [ Attr.attribute "translate" "no"
                    , Attr.class "shrink-0 text-sm font-medium text-[var(--page-fg)] transition-colors duration-150"
                    ]
                    [ text project.name ]
                , span [ Attr.class "hidden sm:inline text-[13.5px] text-[var(--page-muted)] group-hover:text-[var(--page-fg)] transition-colors duration-150 truncate" ]
                    [ text project.summary ]
                , span
                    [ Attr.attribute "translate" "no"
                    , Attr.class "sm:hidden shrink-0 font-mono text-[11px] text-[var(--page-subtle)]"
                    ]
                    [ text project.tag ]
                ]
            , p [ Attr.class "sm:hidden mt-0.5 text-[13.5px] leading-snug text-[var(--page-muted)] text-pretty break-words" ]
                [ text project.summary ]
            , span
                [ Attr.attribute "translate" "no"
                , Attr.class "hidden sm:inline shrink-0 font-mono text-[11px] text-[var(--page-subtle)] group-hover:text-[var(--page-fg)] transition-colors duration-150"
                ]
                [ text project.tag ]
            ]
        ]



-- 3. CONTACT


viewContact : String -> Theme -> Bool -> CopyState -> Html Msg
viewContact currentYear theme motionPlaying copyState =
    section
        [ Attr.id "contact"
        , Attr.attribute "aria-labelledby" "contact-heading"
        , Attr.class "scroll-mt-8 mt-6 sm:mt-8 grid grid-cols-[1.5rem_1fr] sm:grid-cols-[2.75rem_1fr] gap-x-4 sm:gap-x-6 items-start"
        ]
        [ viewVerticalHeading "contact-heading" "Contact"
        , div [ Attr.class "min-w-0 pt-0.5 space-y-3" ]
            [ p [ Attr.class "text-[14px] leading-relaxed text-pretty text-[var(--page-muted)]" ]
                [ text "I'm here to talk about "
                , span [ Attr.attribute "translate" "no", Attr.class "text-[var(--page-fg)]" ] [ text "Go" ]
                , text " tooling, terminal interfaces, "
                , span [ Attr.attribute "translate" "no", Attr.class "text-[var(--page-fg)]" ] [ text "NixOS" ]
                , text ", and web engineering (all parts of it)."
                ]
            , div [ Attr.class "flex flex-col sm:flex-row sm:flex-wrap sm:items-baseline sm:justify-between gap-x-5 gap-y-1 text-sm" ]
                [ div [ Attr.class "flex items-center justify-between sm:justify-start gap-x-3.5" ]
                    [ a
                        [ Attr.href ("mailto:" ++ emailAddress)
                        , Attr.attribute "translate" "no"
                        , Attr.class
                            ("inline-flex items-center min-h-11 sm:min-h-8 font-medium text-[var(--page-fg)] underline decoration-current/30 underline-offset-4 transition-[color,text-decoration-color] duration-150 hover:decoration-current break-all rounded-xs "
                                ++ focusRing
                            )
                        ]
                        [ text emailAddress ]
                    , button
                        [ Attr.type_ "button"
                        , Events.onClick CopyEmail
                        , Attr.class
                            ("inline-flex items-center min-h-11 sm:min-h-8 font-mono text-xs text-[var(--page-subtle)] transition-colors duration-150 hover:text-[var(--page-fg)] rounded-xs "
                                ++ focusRing
                            )
                        ]
                        [ text
                            (case copyState of
                                CopySucceeded ->
                                    "Copied"

                                CopyFailed ->
                                    "Unavailable"

                                CopyIdle ->
                                    "Copy"
                            )
                        ]
                    ]
                , div [ Attr.class "flex flex-wrap items-center gap-x-4 font-mono text-xs" ]
                    [ viewSocialLink "GitHub" "https://github.com/sam0uly"
                    , viewSocialLink "X" "https://x.com/sam0uly"
                    , viewSocialLink "Blog" "https://samouly.fun/blog"
                    , viewSocialLink "Charm" "https://charm.land"
                    ]
                ]
            , div [ Attr.class "pt-2.5 border-t border-[var(--page-line)] flex flex-wrap items-center justify-between gap-x-4 gap-y-1 font-mono text-[11px] text-[var(--page-subtle)]" ]
                [ span [ Attr.class "tabular-nums" ]
                    [ text "Egypt · Replies within 24\u{00A0}hours" ]
                , div [ Attr.class "flex items-center gap-x-4" ]
                    [ button
                        [ Attr.type_ "button"
                        , Events.onClick ToggleTheme
                        , Attr.attribute "aria-label"
                            (case theme of
                                Dark ->
                                    "Switch to Light Theme"

                                Light ->
                                    "Switch to Dark Theme"
                            )
                        , Attr.class
                            ("inline-flex items-center min-h-11 sm:min-h-7 text-[var(--page-muted)] transition-colors duration-150 hover:text-[var(--page-fg)] rounded-xs "
                                ++ focusRing
                            )
                        ]
                        [ text
                            (case theme of
                                Dark ->
                                    "Light"

                                Light ->
                                    "Dark"
                            )
                        ]
                    , button
                        [ Attr.type_ "button"
                        , Events.onClick ToggleMotion
                        , Attr.attribute "aria-pressed"
                            (if motionPlaying then
                                "false"

                             else
                                "true"
                            )
                        , Attr.class
                            ("inline-flex items-center min-h-11 sm:min-h-7 text-[var(--page-subtle)] transition-colors duration-150 hover:text-[var(--page-fg)] rounded-xs "
                                ++ focusRing
                            )
                        ]
                        [ text
                            (if motionPlaying then
                                "Pause"

                             else
                                "Play"
                            )
                        ]
                    , span [ Attr.class "tabular-nums" ]
                        [ text currentYear ]
                    ]
                ]
            ]
        ]


viewSocialLink : String -> String -> Html Msg
viewSocialLink labelText hrefUrl =
    a
        [ Attr.href hrefUrl
        , Attr.target "_blank"
        , Attr.rel "noopener noreferrer"
        , Attr.attribute "translate" "no"
        , Attr.class
            ("inline-flex items-center min-h-11 sm:min-h-8 text-[var(--page-muted)] transition-colors duration-150 hover:text-[var(--page-fg)] rounded-xs "
                ++ focusRing
            )
        ]
        [ text labelText ]


viewFooter : Theme -> DitherFooter.Model -> Html Msg
viewFooter theme ditherFooterModel =
    footer [ Attr.class "relative z-10 w-full -mt-4 sm:-mt-20 pointer-events-none" ]
        [ div [ Attr.class "pointer-events-auto" ]
            [ DitherFooter.view theme ditherFooterModel |> Html.map FooterDitherMsg ]
        ]
