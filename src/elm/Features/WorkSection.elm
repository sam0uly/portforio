module Features.WorkSection exposing (HoverRect, view)

import Html exposing (Html, a, button, div, li, p, span, text, ul)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Svg exposing (rect, svg)
import Svg.Attributes as SvgAttr


type Accent
    = AccentNote
    | AccentTip
    | AccentWarn
    | AccentTab


type alias WorkProject =
    { id : String
    , name : String
    , repo : String
    , summary : String
    , story : String
    , highlights : List String
    , tag : String
    , stack : List String
    , accent : Accent
    , url : String
    }


type alias HoverRect =
    { id : String
    , top : Float
    , height : Float
    , visible : Bool
    , animate : Bool
    }


projects : List WorkProject
projects =
    [ { id = "twig"
      , name = "Twig"
      , repo = "sam0uly/twig"
      , summary = "Live diff viewer for working trees bigger than your screen"
      , story = "Built for reviewing large Git working trees without leaving the terminal or choking on multi-thousand-line diffs."
      , highlights =
            [ "Streams and virtualizes hunks so huge diffs stay instant"
            , "Keyboard-first navigation across files, hunks, and staged changes"
            , "Live working-tree refresh as files change on disk"
            ]
      , tag = "Building"
      , stack = [ "Go", "Bubble Tea", "Git" ]
      , accent = AccentNote
      , url = "https://github.com/sam0uly/twig"
      }
    , { id = "mural"
      , name = "mural"
      , repo = "sam0uly/mural"
      , summary = "Terminal wallpaper manager with a pure Go Wayland daemon"
      , story = "Replaces heavy shell-scripted wallpaper setups with a single Go binary that speaks Wayland layer-shell directly."
      , highlights =
            [ "Built-in pure Go Wayland daemon with zero external compositor wrappers"
            , "Interactive TUI browser for multi-monitor wallpaper management"
            , "Smooth transitions and per-output wallpaper state persistence"
            ]
      , tag = "Go · TUI"
      , stack = [ "Go", "Wayland", "Bubble Tea" ]
      , accent = AccentTip
      , url = "https://github.com/sam0uly/mural"
      }
    , { id = "spin"
      , name = "Spin"
      , repo = "sam0uly/spin"
      , summary = "Language-agnostic project template CLI"
      , story = "Scaffolds new repositories from reusable remote or local templates without locking you into one language ecosystem."
      , highlights =
            [ "Works across Go, Rust, TypeScript, Nix, or any custom starter repo"
            , "Interactive prompts and variable substitution during generation"
            , "Companion spin-templates organization for ready-to-use starters"
            ]
      , tag = "Go"
      , stack = [ "Go", "CLI", "Templates" ]
      , accent = AccentWarn
      , url = "https://spincli.pages.dev"
      }
    , { id = "bubblemonitor"
      , name = "bubbleMonitor"
      , repo = "sam0uly/bubbleMonitor"
      , summary = "Terminal system monitor built with Bubble\u{00A0}Tea"
      , story = "A clean, responsive resource monitor crafted with Charm's TUI stack for real-time CPU, memory, and process inspection."
      , highlights =
            [ "Live CPU, memory, disk, and network telemetry at low overhead"
            , "Sortable process table with quick filtering and inspection"
            , "Adaptive Lip Gloss layout that scales cleanly across terminal sizes"
            ]
      , tag = "TUI"
      , stack = [ "Go", "Bubble Tea", "Lip Gloss" ]
      , accent = AccentNote
      , url = "https://github.com/sam0uly/bubbleMonitor"
      }
    , { id = "mditor"
      , name = "Mditor"
      , repo = "sam0uly/mditor"
      , summary = "Terminal markdown editor on Charm libraries"
      , story = "Distraction-free markdown writing and live terminal rendering built directly on Bubble Tea and Glamour."
      , highlights =
            [ "Instant split editing with styled Glamour markdown preview"
            , "Keyboard-driven workflow designed for notes and documentation"
            , "Lightweight single binary with zero Electron or browser overhead"
            ]
      , tag = "Charm"
      , stack = [ "Go", "Glamour", "Bubble Tea" ]
      , accent = AccentTip
      , url = "https://github.com/sam0uly/mditor"
      }
    , { id = "hyprluna"
      , name = "HyprLuna"
      , repo = "Lunaris-Project/HyprLuna"
      , summary = "Arch\u{00A0}Linux desktop shell for Hyprland and Ags"
      , story = "A full Wayland desktop environment layer for Hyprland with dynamic wallpaper theming, bar, dock, and control center."
      , highlights =
            [ "Cohesive AGS shell with workspaces, notifications, and quick settings"
            , "Automatic palette generation synced to the active wallpaper"
            , "Maintained under Lunaris-Project with community contributors"
            ]
      , tag = "Hyprland"
      , stack = [ "Hyprland", "AGS", "Linux" ]
      , accent = AccentNote
      , url = "https://github.com/Lunaris-Project/HyprLuna"
      }
    , { id = "samouly-flake"
      , name = "Samouly\u{00A0}Flake"
      , repo = "sam0uly/samouly-flake"
      , summary = "Declarative NixOS setup for Hyprland and Niri"
      , story = "My reproducible Linux workstation defined as a single Nix flake, covering system packages, compositors, shells, and dotfiles."
      , highlights =
            [ "Supports both Hyprland and Niri Wayland compositors declaratively"
            , "Unified Home Manager modules for terminal, editors, and dev toolchains"
            , "Atomic rollbacks and identical environments across reinstalls"
            ]
      , tag = "NixOS"
      , stack = [ "Nix", "NixOS", "Niri" ]
      , accent = AccentWarn
      , url = "https://github.com/sam0uly/samouly-flake"
      }
    , { id = "samoulyvim"
      , name = "SamoulyVim"
      , repo = "sam0uly/SamoulyVim"
      , summary = "Personal Neovim configuration written in Lua"
      , story = "A fast, modular Lua Neovim setup tailored for Go, Elm, TypeScript, and Nix development with minimal startup latency."
      , highlights =
            [ "Lazy-loaded plugin architecture tuned for sub-30ms cold starts"
            , "Preconfigured LSP, formatting, and Treesitter across Go, Elm, TS, and Nix"
            , "Consistent keymaps optimized for split diffs and fast symbol navigation"
            ]
      , tag = "Neovim"
      , stack = [ "Lua", "Neovim", "LSP" ]
      , accent = AccentTab
      , url = "https://github.com/sam0uly/SamoulyVim"
      }
    ]


accentVars : Accent -> ( String, String )
accentVars accent =
    case accent of
        AccentNote ->
            ( "var(--callout-note-bg)", "var(--callout-note-fg)" )

        AccentTip ->
            ( "var(--callout-tip-bg)", "var(--callout-tip-fg)" )

        AccentWarn ->
            ( "var(--callout-warn-bg)", "var(--callout-warn-fg)" )

        AccentTab ->
            ( "var(--tab-bg)", "var(--tab-fg)" )


focusRing : String
focusRing =
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--page-fg)] focus-visible:ring-offset-4 focus-visible:ring-offset-[var(--page-bg)]"


hoverRectDecoder : String -> Bool -> (Maybe HoverRect -> msg) -> Decode.Decoder msg
hoverRectDecoder itemId isOpen onHover =
    Decode.map2
        (\top height -> onHover (Just { id = itemId, top = top, height = height, visible = not isOpen, animate = False }))
        (Decode.at [ "currentTarget", "offsetTop" ] Decode.float)
        (Decode.at [ "currentTarget", "offsetHeight" ] Decode.float)


view :
    { onToggle : String -> msg
    , onHover : Maybe HoverRect -> msg
    }
    -> Maybe String
    -> Maybe HoverRect
    -> Html msg
view handlers openId hoveredRect =
    let
        activeHoverId =
            hoveredRect |> Maybe.map .id

        hasHover =
            case hoveredRect of
                Just r ->
                    r.visible || openId == Just r.id

                Nothing ->
                    False

        ( pillAnimClass, pillStyle ) =
            case hoveredRect of
                Just r ->
                    let
                        isShown =
                            r.visible && openId /= Just r.id
                    in
                    ( if r.animate then
                        "work-slide-bg"

                      else
                        "work-slide-bg-snap"
                    , [ Attr.style "transform" ("translate3d(0, " ++ String.fromFloat r.top ++ "px, 0)")
                      , Attr.style "height" (String.fromFloat r.height ++ "px")
                      , Attr.style "opacity"
                            (if isShown then
                                "1"

                             else
                                "0"
                            )
                      ]
                    )

                Nothing ->
                    ( "work-slide-bg-snap"
                    , [ Attr.style "transform" "translate3d(0, 0px, 0)"
                      , Attr.style "height" "0px"
                      , Attr.style "opacity" "0"
                      ]
                    )
    in
    div
        [ Attr.class "relative min-w-0 space-y-1.5"
        , Events.onMouseLeave (handlers.onHover Nothing)
        ]
        (div
            ([ Attr.attribute "aria-hidden" "true"
             , Attr.class (pillAnimClass ++ " pointer-events-none absolute inset-x-0 top-0 z-0 box-squircle bg-[var(--tab-bg)]/55")
             ]
                ++ pillStyle
            )
            []
            :: List.map
                (\item ->
                    let
                        isOpen =
                            openId == Just item.id

                        isHovered =
                            activeHoverId == Just item.id

                        isDimmed =
                            hasHover && not isHovered && not isOpen

                        ( bg, fg ) =
                            if isDimmed then
                                ( "var(--tab-bg)", "var(--tab-fg)" )

                            else
                                accentVars item.accent
                    in
                    div
                        [ Events.on "mouseenter" (hoverRectDecoder item.id isOpen handlers.onHover)
                        , Attr.class
                            ("relative z-10 box-squircle transition-[background-color,opacity] duration-200 "
                                ++ (if isOpen then
                                        "bg-[var(--tab-bg)]/65"

                                    else
                                        "bg-[var(--tab-bg)]/20"
                                   )
                            )
                        , Attr.style "opacity"
                            (if isDimmed then
                                "0.45"

                             else
                                "1"
                            )
                        ]
                        [ button
                            [ Attr.type_ "button"
                            , Events.onClick (handlers.onToggle item.id)
                            , Attr.attribute "aria-expanded"
                                (if isOpen then
                                    "true"

                                 else
                                    "false"
                                )
                            , Attr.class ("w-full px-3.5 py-2.5 flex items-center justify-between gap-3 text-left cursor-pointer rounded-xs " ++ focusRing)
                            ]
                            [ div [ Attr.class "flex items-baseline gap-3 min-w-0" ]
                                [ span
                                    [ Attr.attribute "translate" "no"
                                    , Attr.class "text-[14px] font-medium text-[var(--page-fg)] shrink-0 transition-colors duration-200"
                                    ]
                                    [ text item.name ]
                                , span [ Attr.class "hidden sm:inline text-[13px] text-[var(--page-muted)] truncate transition-colors duration-200" ]
                                    [ text item.summary ]
                                ]
                            , div [ Attr.class "flex items-center gap-2.5 shrink-0" ]
                                [ bayerBadge item.tag bg fg
                                , span [ Attr.class "font-mono text-xs text-[var(--page-subtle)] w-3 text-center" ]
                                    [ text
                                        (if isOpen then
                                            "−"

                                         else
                                            "+"
                                        )
                                    ]
                                ]
                            ]
                        , div
                            [ Attr.class "work-drawer-body"
                            , Attr.attribute "data-open"
                                (if isOpen then
                                    "true"

                                 else
                                    "false"
                                )
                            ]
                            [ div []
                                [ div
                                    [ Attr.class "px-3.5 pb-4 pt-1 space-y-3 cursor-pointer"
                                    , Events.on "click"
                                        (Decode.at [ "target", "tagName" ] Decode.string
                                            |> Decode.andThen
                                                (\tag ->
                                                    if String.toUpper tag == "A" then
                                                        Decode.fail "link click"

                                                    else
                                                        Decode.succeed (handlers.onToggle item.id)
                                                )
                                        )
                                    ]
                                    [ p [ Attr.class "text-[13px] leading-relaxed text-[var(--page-muted)] text-pretty" ]
                                        [ text item.story ]
                                    , ul [ Attr.class "space-y-1.5 text-[12.5px] leading-relaxed text-[var(--page-muted)]" ]
                                        (List.map
                                            (\line ->
                                                li [ Attr.class "flex items-start gap-2" ]
                                                    [ span [ Attr.class "font-mono text-[var(--page-subtle)] shrink-0 mt-px", Attr.attribute "aria-hidden" "true" ] [ text "·" ]
                                                    , span [ Attr.class "text-pretty" ] [ text line ]
                                                    ]
                                            )
                                            item.highlights
                                        )
                                    , div [ Attr.class "pt-1 flex flex-wrap items-center justify-between gap-2" ]
                                        [ div [ Attr.class "flex flex-wrap items-center gap-1.5" ]
                                            (List.map
                                                (\tech ->
                                                    span [ Attr.class "box-squircle px-2 py-0.5 bg-[var(--page-bg)]/60 font-mono text-[10px] text-[var(--page-muted)]" ]
                                                        [ text tech ]
                                                )
                                                item.stack
                                            )
                                        , a
                                            [ Attr.href item.url
                                            , Attr.target "_blank"
                                            , Attr.rel "noopener noreferrer"
                                            , Attr.tabindex
                                                (if isOpen then
                                                    0

                                                 else
                                                    -1
                                                )
                                            , Attr.class ("font-mono text-[11px] text-[var(--page-fg)] hover:underline underline-offset-4 shrink-0 rounded-xs " ++ focusRing)
                                            ]
                                            [ text (item.repo ++ " ↗") ]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                )
                projects
        )


bayerBadge : String -> String -> String -> Html msg
bayerBadge label bgColor fgColor =
    span [ Attr.class "inline-flex items-stretch h-[20px] font-mono text-[10px] tracking-[0.06em] shrink-0" ]
        [ span
            [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none font-medium transition-colors duration-200"
            , Attr.style "background-color" bgColor
            , Attr.style "color" fgColor
            ]
            [ text label ]
        , span
            [ Attr.class "inline-flex items-stretch transition-colors duration-200"
            , Attr.style "color" bgColor
            ]
            [ svg
                [ SvgAttr.viewBox "0 0 6 6"
                , SvgAttr.preserveAspectRatio "none"
                , SvgAttr.class "block w-4 h-full -ml-px shrink-0"
                , Attr.attribute "shape-rendering" "crispEdges"
                , Attr.attribute "aria-hidden" "true"
                ]
                [ rect [ SvgAttr.x "0", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "6", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "1", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "2", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "1", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "2", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "2", SvgAttr.y "1", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "2", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "2", SvgAttr.y "5", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "3", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "3", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "3", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "4", SvgAttr.y "1", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "4", SvgAttr.y "5", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                , rect [ SvgAttr.x "5", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
                ]
            ]
        ]
