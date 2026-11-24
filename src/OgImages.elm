module OgImages exposing (Model, Msg, init, update, view)

import Blog
import Html exposing (Html, a, button, code, div, h1, h2, h3, img, p, pre, section, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Svg exposing (path, rect, svg)
import Svg.Attributes as SvgAttr
import Theme exposing (Theme(..))
import TocWingMorph


type alias Model =
    { selectedSlug : String
    }


type Msg
    = SelectPost String


init : List Blog.Post -> Model
init posts =
    { selectedSlug =
        posts
            |> List.head
            |> Maybe.map .slug
            |> Maybe.withDefault ""
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        SelectPost slug ->
            { model | selectedSlug = slug }


type alias ViewConfig msg =
    { toMsg : Msg -> msg
    , onBackHome : msg
    , onOpenBlogIndex : msg
    , onToggleTheme : msg
    , onToggleMotion : msg
    , theme : Theme
    , motionPlaying : Bool
    , currentYear : String
    , posts : List Blog.Post
    }


focusRing : String
focusRing =
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--page-fg)] focus-visible:ring-offset-4 focus-visible:ring-offset-[var(--page-bg)]"


onInternalLinkClick : msg -> Html.Attribute msg
onInternalLinkClick msg =
    Events.preventDefaultOn "click"
        (Decode.map4
            (\ctrl meta shift alt ->
                if ctrl || meta || shift || alt then
                    Decode.fail "modifier click"

                else
                    Decode.succeed ( msg, True )
            )
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
            (Decode.field "shiftKey" Decode.bool)
            (Decode.field "altKey" Decode.bool)
            |> Decode.andThen identity
        )


view : ViewConfig msg -> Model -> Html msg
view config model =
    let
        selectedPost =
            config.posts
                |> List.filter (\post -> post.slug == model.selectedSlug)
                |> List.head
                |> Maybe.withDefault
                    (config.posts
                        |> List.head
                        |> Maybe.withDefault fallbackPost
                    )
    in
    div [ Attr.class "flex flex-col pointer-events-auto space-y-12" ]
        [ viewPageHeader config
        , viewGroup
            "Home"
            "5 variants for /"
            [ viewCardFrame "og-home-1" "01" "Rising Sheet" (ogHomeRisingSheet config)
            , viewCardFrame "og-home-2" "02" "Framed Dossier" (ogHomeFramedDossier config)
            , viewCardFrame "og-home-3" "03" "Work Bento" (ogHomeWorkBento config)
            , viewCardFrame "og-home-4" "04" "Editorial Monolith" (ogHomeMonolith config)
            , viewCardFrame "og-home-5" "05" "Attached Wing" (ogHomeAttachedWing config)
            ]
        , viewGroup
            "Blog Index"
            "5 variants for /blog"
            [ viewCardFrame "og-blog-1" "01" "Writing Sheet" (ogBlogWritingSheet config)
            , viewCardFrame "og-blog-2" "02" "Magazine Cover" (ogBlogMagazineCover config)
            , viewCardFrame "og-blog-3" "03" "Tag & Count" (ogBlogTagAndCount config)
            , viewCardFrame "og-blog-4" "04" "Split Directory" (ogBlogSplitDirectory config)
            , viewCardFrame "og-blog-5" "05" "Terminal Index" (ogBlogTerminalIndex config)
            ]
        , viewPostGroup config selectedPost
        , viewUtilityBar config
        ]


viewPageHeader : ViewConfig msg -> Html msg
viewPageHeader config =
    section [ Attr.class "space-y-3" ]
        [ div [ Attr.class "flex items-center justify-between gap-x-4" ]
            [ a
                [ Attr.href "/"
                , onInternalLinkClick config.onBackHome
                , Attr.class
                    ("group inline-flex items-center gap-1.5 min-h-11 sm:min-h-8 font-mono text-xs text-[var(--page-muted)] transition-colors duration-150 hover:text-[var(--page-fg)] rounded-xs "
                        ++ focusRing
                    )
                ]
                [ chevronLeftIcon
                , span [] [ text "Portfolio" ]
                ]
            , span [ Attr.class "font-mono text-[11px] text-[var(--page-subtle)] tabular-nums" ]
                [ text "15 cards · 1200×630" ]
            ]
        , h1 [ Attr.class "font-display font-semibold text-2xl sm:text-[2rem] leading-[1.12] tracking-[-0.03em] text-[var(--page-fg)]" ]
            [ text "Open Graph Studio" ]
        , p [ Attr.class "text-[14.5px] leading-relaxed text-[var(--page-muted)] text-pretty" ]
            [ text "Five 1200×630 social card variants for the home page, blog index, and auto-generated blog posts, built with the site's Grainient surfaces, squircles, Bayer dither badges, and Shiki palettes. Toggle Light/Dark below to inspect both themes." ]
        , div
            [ Attr.attribute "role" "separator"
            , Attr.class "pt-4 pb-1 flex items-center justify-center text-[var(--page-subtle)]/65"
            ]
            [ ditherDividerSvg 160 "w-full max-w-[24rem] sm:max-w-[32rem]" ]
        ]


viewGroup : String -> String -> List (Html msg) -> Html msg
viewGroup title subtitle cards =
    section [ Attr.class "space-y-5" ]
        [ div [ Attr.class "flex items-baseline justify-between gap-x-4" ]
            [ div [ Attr.class "flex items-center gap-x-3" ]
                [ span [ Attr.class "inline-flex items-stretch h-[20px] font-mono text-[10px] tracking-[0.14em]" ]
                    [ span
                        [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none"
                        , Attr.style "background-color" "var(--tab-bg)"
                        , Attr.style "color" "var(--tab-fg)"
                        ]
                        [ text title ]
                    , span
                        [ Attr.class "inline-flex items-stretch"
                        , Attr.style "color" "var(--tab-bg)"
                        ]
                        [ ditherTailSvg ]
                    ]
                , h2 [ Attr.class "sr-only" ] [ text title ]
                ]
            , span [ Attr.class "font-mono text-[11px] text-[var(--page-subtle)]" ]
                [ text subtitle ]
            ]
        , div [ Attr.class "space-y-7" ] cards
        ]


viewPostGroup : ViewConfig msg -> Blog.Post -> Html msg
viewPostGroup config post =
    section [ Attr.class "space-y-5" ]
        [ div [ Attr.class "flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3" ]
            [ span [ Attr.class "inline-flex items-stretch self-start h-[20px] font-mono text-[10px] tracking-[0.14em]" ]
                [ span
                    [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none"
                    , Attr.style "background-color" "var(--tab-bg)"
                    , Attr.style "color" "var(--tab-fg)"
                    ]
                    [ text "Auto-Generated Post" ]
                , span
                    [ Attr.class "inline-flex items-stretch"
                    , Attr.style "color" "var(--tab-bg)"
                    ]
                    [ ditherTailSvg ]
                ]
            , div [ Attr.class "flex flex-wrap items-center gap-2" ]
                (List.map
                    (\item ->
                        let
                            active =
                                item.slug == post.slug

                            bgColor =
                                if active then
                                    "var(--page-fg)"

                                else
                                    "var(--tab-bg)"

                            fgColor =
                                if active then
                                    "var(--page-bg)"

                                else
                                    "var(--tab-fg)"
                        in
                        button
                            [ Attr.type_ "button"
                            , Events.onClick (config.toMsg (SelectPost item.slug))
                            , Attr.class ("inline-flex items-stretch h-[22px] font-mono text-[10px] tracking-[0.06em] cursor-pointer rounded-xs " ++ focusRing)
                            ]
                            [ span
                                [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none transition-colors duration-150"
                                , Attr.style "background-color" bgColor
                                , Attr.style "color" fgColor
                                ]
                                [ text item.slug ]
                            , span
                                [ Attr.class "inline-flex items-stretch transition-colors duration-150"
                                , Attr.style "color" bgColor
                                ]
                                [ ditherTailSvg ]
                            ]
                    )
                    config.posts
                )
            ]
        , div [ Attr.class "space-y-7" ]
            [ viewCardFrame "og-post-1" "01" "Article + TOC Wing" (ogPostWithTocWing config post)
            , viewCardFrame "og-post-2" "02" "Framed Editorial" (ogPostFramedEditorial post)
            , viewCardFrame "og-post-3" "03" "Code Snippet" (ogPostCodeSnippet config.theme post)
            , viewCardFrame "og-post-4" "04" "TOC Split" (ogPostTocSplit post)
            , viewCardFrame "og-post-5" "05" "Gradient Poster" (ogPostGradientPoster post)
            ]
        ]


viewCardFrame : String -> String -> String -> Html msg -> Html msg
viewCardFrame cardId number label inner =
    div [ Attr.class "space-y-2" ]
        [ div [ Attr.class "flex items-center justify-between font-mono text-[11px] text-[var(--page-subtle)]" ]
            [ div [ Attr.class "flex items-center gap-x-2" ]
                [ span [ Attr.class "tabular-nums text-[var(--page-fg)]" ] [ text number ]
                , span [ Attr.attribute "aria-hidden" "true" ] [ text "·" ]
                , span [] [ text label ]
                ]
            , span [ Attr.class "text-[10px] opacity-70" ] [ text ("#" ++ cardId) ]
            ]
        , div
            [ Attr.id cardId
            , Attr.class "og-stage relative w-full overflow-hidden box-squircle ring-1 ring-[var(--page-line)] select-none"
            ]
            [ inner ]
        ]



-- ============================================================================
-- HOME OG VARIANTS (5)
-- ============================================================================


ogHomeRisingSheet : ViewConfig msg -> Html msg
ogHomeRisingSheet config =
    div [ Attr.class "og-grainient relative w-full h-full pt-[6.5cqw] px-[6.5cqw] flex flex-col" ]
        [ div [ Attr.class "og-squircle-top relative flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[5cqw] pt-[4.5cqw] pb-[3.5cqw] flex flex-col justify-between overflow-hidden" ]
            [ div [ Attr.class "flex items-start justify-between gap-[3cqw]" ]
                [ div [ Attr.class "space-y-[1.4cqw] min-w-0" ]
                    [ ogBadge "About" "var(--tab-bg)" "var(--tab-fg)"
                    , h3 [ Attr.class "font-display font-semibold text-[5.4cqw] leading-[1.04] tracking-[-0.035em] text-[var(--page-fg)]" ]
                        [ text "Alaa El-Samouly" ]
                    , p [ Attr.class "text-[2.05cqw] leading-[1.48] text-[var(--page-muted)] max-w-[48cqw]" ]
                        [ text "Software engineer at "
                        , span [ Attr.class "text-[var(--page-fg)] font-medium" ] [ text "Charm" ]
                        , text ". Building terminal interfaces & CLI tooling in Go, NixOS setups, and Elm web apps."
                        ]
                    ]
                , img
                    [ Attr.src "/images/sam0-avatar.png"
                    , Attr.alt "Alaa El-Samouly"
                    , Attr.class "size-[11.5cqw] og-squircle-sm object-cover shrink-0 ring-1 ring-[var(--page-line)]"
                    ]
                    []
                ]
            , div [ Attr.class "flex items-center justify-between pt-[2cqw]" ]
                [ div [ Attr.class "flex items-center gap-[1.4cqw]" ]
                    [ ogBadge "Twig" "var(--callout-note-bg)" "var(--callout-note-fg)"
                    , ogBadge "mural" "var(--callout-tip-bg)" "var(--callout-tip-fg)"
                    , ogBadge "Spin" "var(--callout-warn-bg)" "var(--callout-warn-fg)"
                    ]
                , span [ Attr.class "font-mono text-[1.45cqw] text-[var(--page-subtle)]" ]
                    [ text ("portforio.samouly.fun · " ++ config.currentYear) ]
                ]
            , div [ Attr.class "pointer-events-none absolute right-[1.1cqw] top-[5cqw] bottom-0 w-[0.95cqw] rounded-t-full grainient-scroll-track" ] []
            ]
        ]


ogHomeFramedDossier : ViewConfig msg -> Html msg
ogHomeFramedDossier config =
    div [ Attr.class "og-grainient relative w-full h-full p-[3.2cqw] flex" ]
        [ div [ Attr.class "og-squircle flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[5cqw] py-[4.2cqw] grid grid-cols-[1.35fr_0.85fr] gap-[4cqw] items-center" ]
            [ div [ Attr.class "flex flex-col justify-between h-full" ]
                [ div [ Attr.class "flex items-center gap-[1.4cqw]" ]
                    [ ogBadge "Samouly" "var(--callout-note-bg)" "var(--callout-note-fg)"
                    , span [ Attr.class "font-mono text-[1.45cqw] text-[var(--page-subtle)]" ] [ text "Egypt · Charm" ]
                    ]
                , div [ Attr.class "space-y-[1.4cqw]" ]
                    [ h3 [ Attr.class "font-display font-semibold text-[5.1cqw] leading-[1.06] tracking-[-0.035em] text-[var(--page-fg)]" ]
                        [ text "Terminal UIs, CLI tooling & tactile web." ]
                    , p [ Attr.class "font-mono text-[1.5cqw] text-[var(--page-subtle)]" ]
                        [ text "Go · Bubble Tea · Elm · WebGL · NixOS" ]
                    ]
                , span [ Attr.class "font-mono text-[1.4cqw] text-[var(--page-muted)]" ]
                    [ text ("portforio.samouly.fun · " ++ config.currentYear) ]
                ]
            , div [ Attr.class "h-full og-squircle-sm bg-[var(--code-bg)] p-[2.6cqw] flex flex-col justify-between" ]
                [ div [ Attr.class "flex items-center gap-[1.8cqw]" ]
                    [ img
                        [ Attr.src "/images/sam0-avatar.png"
                        , Attr.alt "Samouly"
                        , Attr.class "size-[6.4cqw] og-squircle-sm object-cover shrink-0"
                        ]
                        []
                    , div [ Attr.class "min-w-0" ]
                        [ div [ Attr.class "font-display font-semibold text-[2.1cqw] text-[var(--page-fg)] truncate" ] [ text "Alaa El-Samouly" ]
                        , div [ Attr.class "font-mono text-[1.3cqw] text-[var(--page-subtle)]" ] [ text "@sam0uly" ]
                        ]
                    ]
                , div [ Attr.class "space-y-[1.1cqw] font-mono text-[1.4cqw]" ]
                    [ ogStatRow "Role" "Eng @ Charm"
                    , ogStatRow "Focus" "Go / TUI / Elm"
                    , ogStatRow "OS" "NixOS · Hyprland"
                    , ogStatRow "Depth" "35m freedive"
                    ]
                ]
            ]
        ]


ogHomeWorkBento : ViewConfig msg -> Html msg
ogHomeWorkBento _ =
    div [ Attr.class "relative w-full h-full bg-[var(--page-bg)] p-[4cqw] flex flex-col justify-between overflow-hidden" ]
        [ div [ Attr.class "flex items-end justify-between gap-[2cqw]" ]
            [ div [ Attr.class "space-y-[0.8cqw]" ]
                [ ogBadge "Selected Work" "var(--tab-bg)" "var(--tab-fg)"
                , h3 [ Attr.class "font-display font-semibold text-[4.6cqw] leading-[1.06] tracking-[-0.03em] text-[var(--page-fg)]" ]
                    [ text "Alaa El-Samouly" ]
                ]
            , div [ Attr.class "text-right font-mono text-[1.45cqw] text-[var(--page-subtle)]" ]
                [ div [ Attr.class "text-[var(--page-fg)]" ] [ text "Software Engineer @ Charm" ]
                , div [] [ text "portforio.samouly.fun" ]
                ]
            ]
        , div [ Attr.class "grid grid-cols-2 gap-[1.8cqw] my-[2.2cqw] flex-1" ]
            [ ogProjectTile "Twig" "Building" "Live diff viewer for working trees bigger than your screen." "var(--callout-note-bg)" "var(--callout-note-fg)"
            , ogProjectTile "mural" "Go · TUI" "Terminal wallpaper manager with a pure Go Wayland daemon." "var(--callout-tip-bg)" "var(--callout-tip-fg)"
            , ogProjectTile "Spin" "Go CLI" "Language-agnostic project template generator and CLI." "var(--callout-warn-bg)" "var(--callout-warn-fg)"
            , ogProjectTile "Samouly Flake" "NixOS" "Declarative NixOS setup for Hyprland and Niri compositors." "var(--tab-bg)" "var(--tab-fg)"
            ]
        , div [ Attr.class "h-[1.2cqw] w-full rounded-full og-grainient" ] []
        ]


ogHomeMonolith : ViewConfig msg -> Html msg
ogHomeMonolith config =
    div [ Attr.class "relative w-full h-full bg-[var(--page-bg)] px-[6cqw] py-[5cqw] flex flex-col justify-between overflow-hidden" ]
        [ div [ Attr.class "flex items-center justify-between" ]
            [ div [ Attr.class "flex items-center gap-[1.6cqw]" ]
                [ img
                    [ Attr.src "/images/sam0-avatar.png"
                    , Attr.alt "Samouly"
                    , Attr.class "size-[4.8cqw] og-squircle-sm object-cover"
                    ]
                    []
                , span [ Attr.class "font-mono text-[1.55cqw] text-[var(--page-muted)]" ]
                    [ text "sam0uly · Egypt" ]
                ]
            , ogBadge "Charm" "var(--callout-note-bg)" "var(--callout-note-fg)"
            ]
        , div [ Attr.class "space-y-[2.2cqw]" ]
            [ h3 [ Attr.class "font-display font-semibold text-[7.4cqw] leading-[0.98] tracking-[-0.045em] text-[var(--page-fg)]" ]
                [ text "Alaa El-Samouly" ]
            , div [ Attr.class "text-[var(--page-subtle)]/70" ]
                [ ditherDividerSvg 160 "w-[36cqw]" ]
            , p [ Attr.class "text-[2.2cqw] leading-[1.42] text-[var(--page-muted)] max-w-[66cqw]" ]
                [ text "Crafting Go terminal interfaces, developer CLIs, and minimal web apps." ]
            ]
        , div [ Attr.class "flex items-center justify-between font-mono text-[1.45cqw] text-[var(--page-subtle)]" ]
            [ span [] [ text "portforio.samouly.fun" ]
            , span [] [ text ("Go · Elm · NixOS · " ++ config.currentYear) ]
            ]
        , div [ Attr.class "pointer-events-none absolute right-0 top-0 bottom-0 w-[1.8cqw] og-grainient" ] []
        ]


ogHomeAttachedWing : ViewConfig msg -> Html msg
ogHomeAttachedWing _ =
    div [ Attr.class "og-grainient relative w-full h-full pt-[5cqw] pl-[23cqw] pr-[5cqw] flex" ]
        [ div [ Attr.class "relative flex-1 flex" ]
            [ div [ Attr.class "absolute right-full top-1/2 -translate-y-1/2 w-[18.5cqw] h-[64%] text-[var(--page-bg)]" ]
                [ svg
                    [ SvgAttr.viewBox "0 0 216 432"
                    , SvgAttr.preserveAspectRatio "none"
                    , SvgAttr.class "absolute inset-x-0 -top-[5.5%] w-full h-[111%] overflow-visible"
                    ]
                    [ path [ SvgAttr.d (TocWingMorph.wingPath 1.0), SvgAttr.fill "currentColor" ] [] ]
                , div [ Attr.class "relative z-10 h-full px-[1.8cqw] py-[2.2cqw] flex flex-col justify-between text-[var(--page-fg)]" ]
                    [ ogBadge "Index" "var(--tab-bg)" "var(--tab-fg)"
                    , div [ Attr.class "space-y-[1.1cqw] font-mono text-[1.35cqw]" ]
                        [ div [ Attr.class "text-[var(--page-fg)] font-medium" ] [ text "+ About" ]
                        , div [ Attr.class "text-[var(--page-subtle)]" ] [ text "· Work (8)" ]
                        , div [ Attr.class "text-[var(--page-subtle)]" ] [ text "· Writing" ]
                        , div [ Attr.class "text-[var(--page-subtle)]" ] [ text "· Contact" ]
                        ]
                    , span [ Attr.class "font-mono text-[1.15cqw] text-[var(--page-subtle)]" ] [ text "sam0uly" ]
                    ]
                ]
            , div [ Attr.class "og-squircle-top relative z-10 flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[4.8cqw] pt-[4.5cqw] pb-[3.5cqw] flex flex-col justify-between" ]
                [ div [ Attr.class "flex items-center justify-between" ]
                    [ ogBadge "Portfolio" "var(--callout-tip-bg)" "var(--callout-tip-fg)"
                    , span [ Attr.class "font-mono text-[1.4cqw] text-[var(--page-subtle)]" ] [ text "portforio.samouly.fun" ]
                    ]
                , div [ Attr.class "space-y-[1.5cqw]" ]
                    [ h3 [ Attr.class "font-display font-semibold text-[5.4cqw] leading-[1.03] tracking-[-0.035em] text-[var(--page-fg)]" ]
                        [ text "Alaa El-Samouly" ]
                    , p [ Attr.class "text-[2cqw] leading-[1.48] text-[var(--page-muted)]" ]
                        [ text "Software engineer at Charm building Go terminal interfaces, CLI tools, and declarative Linux systems." ]
                    ]
                , div [ Attr.class "text-[var(--page-subtle)]/65" ]
                    [ ditherDividerSvg 160 "w-full" ]
                ]
            ]
        ]



-- ============================================================================
-- BLOG INDEX OG VARIANTS (5)
-- ============================================================================


ogBlogWritingSheet : ViewConfig msg -> Html msg
ogBlogWritingSheet config =
    let
        recent =
            List.take 3 config.posts
    in
    div [ Attr.class "og-grainient relative w-full h-full pt-[5.5cqw] px-[6cqw] flex flex-col" ]
        [ div [ Attr.class "og-squircle-top flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[5cqw] pt-[4cqw] pb-[3cqw] flex flex-col justify-between" ]
            [ div [ Attr.class "flex items-baseline justify-between" ]
                [ div [ Attr.class "flex items-center gap-[1.8cqw]" ]
                    [ ogBadge "Blog" "var(--callout-note-bg)" "var(--callout-note-fg)"
                    , h3 [ Attr.class "font-display font-semibold text-[4.2cqw] tracking-[-0.03em] text-[var(--page-fg)]" ]
                        [ text "Writing" ]
                    ]
                , span [ Attr.class "font-mono text-[1.4cqw] text-[var(--page-subtle)]" ]
                    [ text (String.fromInt (List.length config.posts) ++ " posts · /blog") ]
                ]
            , div [ Attr.class "divide-y divide-[var(--page-line)] my-[1.2cqw]" ]
                (List.map
                    (\post ->
                        div [ Attr.class "py-[1.35cqw] flex items-baseline justify-between gap-[2cqw]" ]
                            [ span [ Attr.class "font-display font-medium text-[2.15cqw] text-[var(--page-fg)] truncate" ]
                                [ text post.title ]
                            , span [ Attr.class "shrink-0 font-mono text-[1.35cqw] text-[var(--page-subtle)] tabular-nums" ]
                                [ text (post.dateLabel ++ " · " ++ post.readTime) ]
                            ]
                    )
                    recent
                )
            , div [ Attr.class "flex items-center justify-between font-mono text-[1.35cqw] text-[var(--page-subtle)]" ]
                [ span [] [ text "Alaa El-Samouly (Samouly)" ]
                , span [] [ text "portforio.samouly.fun/blog" ]
                ]
            ]
        ]


ogBlogMagazineCover : ViewConfig msg -> Html msg
ogBlogMagazineCover config =
    div [ Attr.class "relative w-full h-full bg-[var(--page-bg)] p-[5.2cqw] flex flex-col justify-between overflow-hidden" ]
        [ div [ Attr.class "flex items-center justify-between" ]
            [ ogBadge "Writing" "var(--callout-warn-bg)" "var(--callout-warn-fg)"
            , span [ Attr.class "font-mono text-[1.45cqw] text-[var(--page-subtle)]" ]
                [ text "portforio.samouly.fun/blog" ]
            ]
        , div [ Attr.class "space-y-[1.8cqw]" ]
            [ h3 [ Attr.class "font-display font-semibold text-[6.8cqw] leading-[1.0] tracking-[-0.04em] text-[var(--page-fg)]" ]
                [ text "Notes on Go, Linux & Nix." ]
            , p [ Attr.class "text-[2.15cqw] leading-[1.45] text-[var(--page-muted)] max-w-[68cqw]" ]
                [ text "Practical technical essays with real commands, real code, and zero fluff." ]
            ]
        , div [ Attr.class "space-y-[2cqw]" ]
            [ div [ Attr.class "text-[var(--page-subtle)]/65" ]
                [ ditherDividerSvg 160 "w-full" ]
            , div [ Attr.class "flex items-center justify-between font-mono text-[1.45cqw] text-[var(--page-subtle)]" ]
                [ span [] [ text ("Alaa El-Samouly · " ++ String.fromInt (List.length config.posts) ++ " articles") ]
                , span [] [ text "sam0uly" ]
                ]
            ]
        , div [ Attr.class "pointer-events-none absolute top-0 inset-x-0 h-[1.1cqw] og-grainient" ] []
        ]


ogBlogTagAndCount : ViewConfig msg -> Html msg
ogBlogTagAndCount config =
    let
        allTags =
            config.posts
                |> List.concatMap .tags
                |> uniqueStrings
                |> List.take 6
    in
    div [ Attr.class "og-grainient relative w-full h-full p-[3.2cqw] flex" ]
        [ div [ Attr.class "og-squircle flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[5.2cqw] py-[4.4cqw] flex flex-col justify-between" ]
            [ div [ Attr.class "flex items-center justify-between" ]
                [ span [ Attr.class "font-mono text-[1.5cqw] text-[var(--page-muted)]" ] [ text "Samouly · Blog" ]
                , ogBadge (String.fromInt (List.length config.posts) ++ " Articles") "var(--callout-tip-bg)" "var(--callout-tip-fg)"
                ]
            , div [ Attr.class "space-y-[2.2cqw]" ]
                [ h3 [ Attr.class "font-display font-semibold text-[5.4cqw] leading-[1.04] tracking-[-0.035em] text-[var(--page-fg)]" ]
                    [ text "Field notes from the terminal." ]
                , div [ Attr.class "flex flex-wrap gap-[1.3cqw]" ]
                    (List.indexedMap
                        (\idx tag ->
                            let
                                ( bg, fg ) =
                                    case modBy 4 idx of
                                        0 ->
                                            ( "var(--callout-note-bg)", "var(--callout-note-fg)" )

                                        1 ->
                                            ( "var(--callout-tip-bg)", "var(--callout-tip-fg)" )

                                        2 ->
                                            ( "var(--callout-warn-bg)", "var(--callout-warn-fg)" )

                                        _ ->
                                            ( "var(--tab-bg)", "var(--tab-fg)" )
                            in
                            ogBadge tag bg fg
                        )
                        allTags
                    )
                ]
            , span [ Attr.class "font-mono text-[1.4cqw] text-[var(--page-subtle)]" ]
                [ text "portforio.samouly.fun/blog" ]
            ]
        ]


ogBlogSplitDirectory : ViewConfig msg -> Html msg
ogBlogSplitDirectory config =
    div [ Attr.class "relative w-full h-full bg-[var(--page-bg)] grid grid-cols-[0.95fr_1.25fr] overflow-hidden" ]
        [ div [ Attr.class "og-grainient p-[4.5cqw] flex flex-col justify-between text-white" ]
            [ span [ Attr.class "font-mono text-[1.5cqw] tracking-[0.14em] uppercase opacity-90" ] [ text "/blog" ]
            , div [ Attr.class "space-y-[1.2cqw]" ]
                [ h3 [ Attr.class "font-display font-semibold text-[5.4cqw] leading-[1.0] tracking-[-0.035em]" ]
                    [ text "Writing" ]
                , p [ Attr.class "text-[1.85cqw] leading-[1.4] opacity-90" ]
                    [ text "by Alaa El-Samouly" ]
                ]
            , span [ Attr.class "font-mono text-[1.35cqw] opacity-85" ] [ text "portforio.samouly.fun" ]
            ]
        , div [ Attr.class "p-[4.5cqw] flex flex-col justify-between" ]
            [ div [ Attr.class "flex items-center justify-between" ]
                [ ogBadge "Latest" "var(--tab-bg)" "var(--tab-fg)"
                , span [ Attr.class "font-mono text-[1.35cqw] text-[var(--page-subtle)]" ]
                    [ text (String.fromInt (List.length config.posts) ++ " entries") ]
                ]
            , div [ Attr.class "space-y-[2.2cqw]" ]
                (config.posts
                    |> List.take 3
                    |> List.map
                        (\post ->
                            div [ Attr.class "space-y-[0.5cqw]" ]
                                [ div [ Attr.class "font-display font-semibold text-[2.15cqw] leading-snug text-[var(--page-fg)]" ]
                                    [ text post.title ]
                                , div [ Attr.class "font-mono text-[1.3cqw] text-[var(--page-subtle)]" ]
                                    [ text (post.dateLabel ++ " · " ++ post.readTime) ]
                                ]
                        )
                )
            , div [ Attr.class "text-[var(--page-subtle)]/65" ]
                [ ditherDividerSvg 80 "w-[18cqw]" ]
            ]
        ]


ogBlogTerminalIndex : ViewConfig msg -> Html msg
ogBlogTerminalIndex config =
    div [ Attr.class "og-grainient relative w-full h-full p-[3.6cqw] flex" ]
        [ div [ Attr.class "og-squircle flex-1 bg-[var(--code-bg)] shadow-[var(--sheet-outer-shadow)] px-[4.6cqw] py-[4cqw] flex flex-col justify-between font-mono" ]
            [ div [ Attr.class "flex items-center justify-between" ]
                [ ogBadge "ls ~/blog" "var(--callout-note-bg)" "var(--callout-note-fg)"
                , span [ Attr.class "text-[1.4cqw] text-[var(--page-subtle)]" ] [ text "portforio.samouly.fun/blog" ]
                ]
            , div [ Attr.class "space-y-[1.8cqw] my-[1.5cqw]" ]
                (config.posts
                    |> List.take 3
                    |> List.map
                        (\post ->
                            div [ Attr.class "flex items-baseline justify-between gap-[2cqw]" ]
                                [ div [ Attr.class "min-w-0 truncate text-[1.85cqw]" ]
                                    [ span [ Attr.class "text-[var(--callout-tip-bg)] mr-[1.2cqw]" ] [ text "$" ]
                                    , span [ Attr.class "text-[var(--page-fg)]" ] [ text (post.slug ++ ".md") ]
                                    ]
                                , span [ Attr.class "shrink-0 text-[1.35cqw] text-[var(--page-subtle)] tabular-nums" ]
                                    [ text (post.dateIso ++ " · " ++ post.readTime) ]
                                ]
                        )
                )
            , div [ Attr.class "flex items-center justify-between text-[1.35cqw] text-[var(--page-subtle)]" ]
                [ span [] [ text "Alaa El-Samouly (Samouly)" ]
                , span [] [ text "Go · Linux · NixOS" ]
                ]
            ]
        ]



-- ============================================================================
-- AUTO-GENERATED BLOG POST OG VARIANTS (5)
-- ============================================================================


ogPostWithTocWing : ViewConfig msg -> Blog.Post -> Html msg
ogPostWithTocWing _ post =
    div [ Attr.class "og-grainient relative w-full h-full pt-[4.5cqw] pl-[24cqw] pr-[4.5cqw] flex" ]
        [ div [ Attr.class "relative flex-1 flex" ]
            [ div [ Attr.class "absolute right-full top-1/2 -translate-y-1/2 w-[19.5cqw] h-[68%] text-[var(--page-bg)]" ]
                [ svg
                    [ SvgAttr.viewBox "0 0 216 432"
                    , SvgAttr.preserveAspectRatio "none"
                    , SvgAttr.class "absolute inset-x-0 -top-[5.5%] w-full h-[111%] overflow-visible"
                    ]
                    [ path [ SvgAttr.d (TocWingMorph.wingPath 1.0), SvgAttr.fill "currentColor" ] [] ]
                , div [ Attr.class "relative z-10 h-full px-[1.6cqw] py-[2cqw] flex flex-col justify-between text-[var(--page-fg)] overflow-hidden" ]
                    [ div [ Attr.class "flex items-center justify-between" ]
                        [ ogBadge "TOC" "var(--tab-bg)" "var(--tab-fg)"
                        , span [ Attr.class "font-mono text-[1.15cqw] text-[var(--page-subtle)] tabular-nums" ]
                            [ text ("1/" ++ String.fromInt (List.length post.toc)) ]
                        ]
                    , div [ Attr.class "space-y-[0.9cqw] font-sans text-[1.25cqw] leading-snug" ]
                        (post.toc
                            |> List.take 5
                            |> List.indexedMap
                                (\idx item ->
                                    div
                                        [ Attr.class
                                            ("truncate "
                                                ++ (if idx == 0 then
                                                        "text-[var(--page-fg)] font-medium"

                                                    else
                                                        "text-[var(--page-subtle)]"
                                                   )
                                            )
                                        ]
                                        [ text
                                            ((if idx == 0 then
                                                "+ "

                                              else
                                                "· "
                                             )
                                                ++ item.text
                                            )
                                        ]
                                )
                        )
                    , span [ Attr.class "font-mono text-[1.1cqw] text-[var(--page-subtle)]" ] [ text post.readTime ]
                    ]
                ]
            , div [ Attr.class "og-squircle-top relative z-10 flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[4.6cqw] pt-[4cqw] pb-[3.2cqw] flex flex-col justify-between" ]
                [ div [ Attr.class "flex items-center justify-between font-mono text-[1.35cqw] text-[var(--page-subtle)]" ]
                    [ span [] [ text "Writing" ]
                    , span [ Attr.class "tabular-nums" ] [ text (post.dateLabel ++ " · " ++ post.readTime) ]
                    ]
                , div [ Attr.class "space-y-[1.6cqw]" ]
                    [ h3 [ Attr.class "font-display font-semibold text-[4.5cqw] leading-[1.06] tracking-[-0.03em] text-[var(--page-fg)] text-balance" ]
                        [ text post.title ]
                    , p [ Attr.class "text-[1.85cqw] leading-[1.45] text-[var(--page-muted)] line-clamp-2" ]
                        [ text post.summary ]
                    ]
                , div [ Attr.class "flex items-center justify-between gap-[2cqw]" ]
                    [ div [ Attr.class "flex flex-wrap gap-[1cqw]" ]
                        (post.tags |> List.take 3 |> List.map (\t -> ogBadge t "var(--tab-bg)" "var(--tab-fg)"))
                    , span [ Attr.class "font-mono text-[1.25cqw] text-[var(--page-subtle)] shrink-0" ]
                        [ text "samouly.fun" ]
                    ]
                ]
            ]
        ]


ogPostFramedEditorial : Blog.Post -> Html msg
ogPostFramedEditorial post =
    div [ Attr.class "og-grainient relative w-full h-full p-[3.2cqw] flex" ]
        [ div [ Attr.class "og-squircle flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[5.4cqw] py-[4.4cqw] flex flex-col justify-between" ]
            [ div [ Attr.class "flex items-center justify-between" ]
                [ ogBadge (post.tags |> List.head |> Maybe.withDefault "Article") "var(--callout-note-bg)" "var(--callout-note-fg)"
                , span [ Attr.class "font-mono text-[1.45cqw] text-[var(--page-subtle)] tabular-nums" ]
                    [ text (post.dateLabel ++ " · " ++ post.readTime) ]
                ]
            , div [ Attr.class "space-y-[1.8cqw]" ]
                [ h3 [ Attr.class "font-display font-semibold text-[5.2cqw] leading-[1.04] tracking-[-0.035em] text-[var(--page-fg)] text-balance" ]
                    [ text post.title ]
                , p [ Attr.class "text-[2cqw] leading-[1.48] text-[var(--page-muted)] max-w-[74cqw] line-clamp-2" ]
                    [ text post.summary ]
                ]
            , div [ Attr.class "space-y-[1.8cqw]" ]
                [ div [ Attr.class "text-[var(--page-subtle)]/65" ]
                    [ ditherDividerSvg 160 "w-full" ]
                , div [ Attr.class "flex items-center justify-between font-mono text-[1.4cqw]" ]
                    [ div [ Attr.class "flex items-center gap-[1.4cqw]" ]
                        [ img [ Attr.src "/images/sam0-avatar.png", Attr.alt "Samouly", Attr.class "size-[3.6cqw] rounded-full object-cover" ] []
                        , span [ Attr.class "text-[var(--page-fg)]" ] [ text "Alaa El-Samouly" ]
                        ]
                    , span [ Attr.class "text-[var(--page-subtle)]" ] [ text ("/blog/" ++ post.slug) ]
                    ]
                ]
            ]
        ]


ogPostCodeSnippet : Theme -> Blog.Post -> Html msg
ogPostCodeSnippet theme post =
    let
        ( codeTitle, snippetLines ) =
            firstCodeSnippet post.blocks
    in
    div [ Attr.class "relative w-full h-full bg-[var(--page-bg)] p-[4.4cqw] grid grid-cols-[1.1fr_0.95fr] gap-[3.5cqw] overflow-hidden" ]
        [ div [ Attr.class "flex flex-col justify-between min-w-0" ]
            [ div [ Attr.class "flex items-center gap-[1.4cqw]" ]
                [ ogBadge "Blog" "var(--callout-tip-bg)" "var(--callout-tip-fg)"
                , span [ Attr.class "font-mono text-[1.35cqw] text-[var(--page-subtle)] tabular-nums" ]
                    [ text (post.dateLabel ++ " · " ++ post.readTime) ]
                ]
            , div [ Attr.class "space-y-[1.5cqw]" ]
                [ h3 [ Attr.class "font-display font-semibold text-[4.3cqw] leading-[1.06] tracking-[-0.03em] text-[var(--page-fg)] text-balance" ]
                    [ text post.title ]
                , p [ Attr.class "text-[1.75cqw] leading-[1.46] text-[var(--page-muted)] line-clamp-3" ]
                    [ text post.summary ]
                ]
            , div [ Attr.class "flex items-center gap-[1.2cqw] font-mono text-[1.35cqw] text-[var(--page-subtle)]" ]
                [ span [ Attr.class "text-[var(--page-fg)]" ] [ text "Samouly" ]
                , span [] [ text "·" ]
                , span [ Attr.class "truncate" ] [ text ("/blog/" ++ post.slug) ]
                ]
            ]
        , div [ Attr.class "og-squircle-sm bg-[var(--code-bg)] p-[2.6cqw] flex flex-col justify-between overflow-hidden" ]
            [ div [ Attr.class "flex items-center justify-between mb-[1.6cqw]" ]
                [ ogBadge codeTitle "var(--tab-bg)" "var(--tab-fg)"
                , span [ Attr.class "font-mono text-[1.2cqw] text-[var(--page-subtle)]" ] [ text "shiki" ]
                ]
            , pre [ Attr.class "flex-1 overflow-hidden font-mono text-[1.45cqw] leading-[1.65] text-[var(--page-fg)]" ]
                [ code [ Attr.class "block" ]
                    (List.indexedMap
                        (\idx lineTokens ->
                            div [ Attr.class "flex items-baseline whitespace-pre overflow-hidden" ]
                                [ span [ Attr.class "w-[2.4cqw] shrink-0 text-[1.15cqw] text-[var(--page-subtle)]/50 tabular-nums" ]
                                    [ text (String.fromInt (idx + 1)) ]
                                , span [ Attr.class "truncate" ]
                                    (if List.isEmpty lineTokens then
                                        [ text " " ]

                                     else
                                        List.map
                                            (\tok ->
                                                let
                                                    clr =
                                                        case theme of
                                                            Dark ->
                                                                tok.dark

                                                            Light ->
                                                                tok.light
                                                in
                                                if String.isEmpty clr then
                                                    text tok.text

                                                else
                                                    span [ Attr.style "color" clr ] [ text tok.text ]
                                            )
                                            lineTokens
                                    )
                                ]
                        )
                        snippetLines
                    )
                ]
            , div [ Attr.class "h-[0.7cqw] w-full rounded-full og-grainient mt-[1.4cqw]" ] []
            ]
        ]


ogPostTocSplit : Blog.Post -> Html msg
ogPostTocSplit post =
    div [ Attr.class "relative w-full h-full bg-[var(--page-bg)] p-[4.5cqw] grid grid-cols-[1.25fr_0.85fr] gap-[3.6cqw] overflow-hidden" ]
        [ div [ Attr.class "flex flex-col justify-between min-w-0" ]
            [ div [ Attr.class "flex flex-wrap gap-[1cqw]" ]
                (post.tags
                    |> List.take 3
                    |> List.indexedMap
                        (\idx tag ->
                            let
                                ( bg, fg ) =
                                    case modBy 3 idx of
                                        0 ->
                                            ( "var(--callout-note-bg)", "var(--callout-note-fg)" )

                                        1 ->
                                            ( "var(--callout-tip-bg)", "var(--callout-tip-fg)" )

                                        _ ->
                                            ( "var(--callout-warn-bg)", "var(--callout-warn-fg)" )
                            in
                            ogBadge tag bg fg
                        )
                )
            , div [ Attr.class "space-y-[1.4cqw]" ]
                [ h3 [ Attr.class "font-display font-semibold text-[4.6cqw] leading-[1.05] tracking-[-0.03em] text-[var(--page-fg)] text-balance" ]
                    [ text post.title ]
                , p [ Attr.class "text-[1.8cqw] leading-[1.46] text-[var(--page-muted)] line-clamp-2" ]
                    [ text post.summary ]
                ]
            , div [ Attr.class "font-mono text-[1.35cqw] text-[var(--page-subtle)]" ]
                [ text ("Alaa El-Samouly · " ++ post.dateLabel ++ " · " ++ post.readTime) ]
            ]
        , div [ Attr.class "og-squircle-sm bg-[var(--tab-bg)]/45 p-[2.6cqw] flex flex-col justify-between overflow-hidden" ]
            [ div [ Attr.class "flex items-center justify-between" ]
                [ ogBadge "Contents" "var(--tab-bg)" "var(--tab-fg)"
                , span [ Attr.class "font-mono text-[1.25cqw] text-[var(--page-subtle)] tabular-nums" ]
                    [ text (String.fromInt (List.length post.toc) ++ " sections") ]
                ]
            , div [ Attr.class "space-y-[1.1cqw] font-sans text-[1.45cqw] my-[1.2cqw]" ]
                (post.toc
                    |> List.take 6
                    |> List.indexedMap
                        (\idx item ->
                            div
                                [ Attr.class
                                    ("truncate "
                                        ++ (if idx == 0 then
                                                "text-[var(--page-fg)] font-medium"

                                            else
                                                "text-[var(--page-muted)]"
                                           )
                                    )
                                ]
                                [ text
                                    ((if idx == 0 then
                                        "+ "

                                      else
                                        "· "
                                     )
                                        ++ item.text
                                    )
                                ]
                        )
                )
            , span [ Attr.class "font-mono text-[1.2cqw] text-[var(--page-subtle)]" ]
                [ text ("portforio.samouly.fun/blog/" ++ post.slug) ]
            ]
        ]


ogPostGradientPoster : Blog.Post -> Html msg
ogPostGradientPoster post =
    div [ Attr.class "og-grainient relative w-full h-full p-[4.8cqw] flex flex-col justify-between" ]
        [ div [ Attr.class "flex items-center justify-between" ]
            [ div [ Attr.class "og-squircle-sm bg-[var(--page-bg)] px-[2cqw] py-[0.9cqw] font-mono text-[1.45cqw] text-[var(--page-fg)]" ]
                [ text "portforio.samouly.fun/blog" ]
            , div [ Attr.class "og-squircle-sm bg-[var(--page-bg)] px-[2cqw] py-[0.9cqw] font-mono text-[1.4cqw] text-[var(--page-muted)] tabular-nums" ]
                [ text (post.dateLabel ++ " · " ++ post.readTime) ]
            ]
        , div [ Attr.class "og-squircle bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[4.8cqw] py-[4cqw] space-y-[1.8cqw]" ]
            [ div [ Attr.class "flex flex-wrap gap-[1cqw]" ]
                (post.tags |> List.take 3 |> List.map (\t -> ogBadge t "var(--callout-note-bg)" "var(--callout-note-fg)"))
            , h3 [ Attr.class "font-display font-semibold text-[4.8cqw] leading-[1.05] tracking-[-0.035em] text-[var(--page-fg)] text-balance" ]
                [ text post.title ]
            , div [ Attr.class "flex items-center justify-between pt-[0.6cqw] font-mono text-[1.4cqw] text-[var(--page-subtle)]" ]
                [ span [ Attr.class "text-[var(--page-fg)]" ] [ text "Alaa El-Samouly (Samouly)" ]
                , span [] [ text (String.fromInt (List.length post.toc) ++ " sections") ]
                ]
            ]
        ]



-- ============================================================================
-- SHARED PRIMITIVES & HELPERS
-- ============================================================================


ogBadge : String -> String -> String -> Html msg
ogBadge label bgColor fgColor =
    span [ Attr.class "inline-flex items-stretch h-[2.5cqw] font-mono text-[1.25cqw] font-medium uppercase tracking-[0.12em] shrink-0" ]
        [ span
            [ Attr.class "inline-flex items-center pl-[1.1cqw] pr-[0.8cqw] leading-none"
            , Attr.style "background-color" bgColor
            , Attr.style "color" fgColor
            ]
            [ text label ]
        , span
            [ Attr.class "inline-flex items-stretch"
            , Attr.style "color" bgColor
            ]
            [ svg
                [ SvgAttr.viewBox "0 0 6 6"
                , SvgAttr.preserveAspectRatio "none"
                , SvgAttr.class "block w-[2cqw] h-full -ml-px shrink-0"
                , Attr.attribute "shape-rendering" "crispEdges"
                ]
                ditherTailRects
            ]
        ]


ogStatRow : String -> String -> Html msg
ogStatRow k v =
    div [ Attr.class "flex items-center justify-between gap-[1cqw] border-b border-[var(--page-line)] pb-[0.7cqw] last:border-b-0 last:pb-0" ]
        [ span [ Attr.class "text-[var(--page-subtle)]" ] [ text k ]
        , span [ Attr.class "text-[var(--page-fg)]" ] [ text v ]
        ]


ogProjectTile : String -> String -> String -> String -> String -> Html msg
ogProjectTile name badge summary bg fg =
    div [ Attr.class "og-squircle-sm bg-[var(--code-bg)] px-[2.4cqw] py-[2cqw] flex flex-col justify-between" ]
        [ div [ Attr.class "flex items-center justify-between gap-[1cqw]" ]
            [ span [ Attr.class "font-display font-semibold text-[2.2cqw] text-[var(--page-fg)]" ] [ text name ]
            , ogBadge badge bg fg
            ]
        , p [ Attr.class "text-[1.45cqw] leading-[1.4] text-[var(--page-muted)] line-clamp-2" ]
            [ text summary ]
        ]


firstCodeSnippet : List Blog.Block -> ( String, List (List { text : String, dark : String, light : String }) )
firstCodeSnippet blocks =
    let
        findCode list =
            case list of
                [] ->
                    Nothing

                (Blog.CodeBlock lang filename _ lines) :: rest ->
                    if List.length lines >= 3 then
                        let
                            label =
                                if not (String.isEmpty filename) then
                                    filename

                                else if not (String.isEmpty lang) then
                                    lang

                                else
                                    "code"
                        in
                        Just ( label, List.take 7 lines )

                    else
                        case findCode rest of
                            Just better ->
                                Just better

                            Nothing ->
                                let
                                    label =
                                        if not (String.isEmpty filename) then
                                            filename

                                        else if not (String.isEmpty lang) then
                                            lang

                                        else
                                            "code"
                                in
                                Just ( label, List.take 7 lines )

                (Blog.Callout _ inner) :: rest ->
                    case findCode inner of
                        Just found ->
                            Just found

                        Nothing ->
                            findCode rest

                _ :: rest ->
                    findCode rest
    in
    findCode blocks
        |> Maybe.withDefault
            ( "go"
            , [ [ { text = "package ", dark = "#cba6f7", light = "#8839ef" }
                , { text = "main", dark = "#f9e2af", light = "#df8e1d" }
                ]
              , []
              , [ { text = "func ", dark = "#cba6f7", light = "#8839ef" }
                , { text = "main", dark = "#89b4fa", light = "#1e66f5" }
                , { text = "() {", dark = "#cdd6f4", light = "#4c4f69" }
                ]
              , [ { text = "    fmt.Println(", dark = "#89b4fa", light = "#1e66f5" }
                , { text = "\"hello from Samouly\"", dark = "#a6e3a1", light = "#40a02b" }
                , { text = ")", dark = "#cdd6f4", light = "#4c4f69" }
                ]
              , [ { text = "}", dark = "#cdd6f4", light = "#4c4f69" } ]
              ]
            )


uniqueStrings : List String -> List String
uniqueStrings list =
    List.foldr
        (\item acc ->
            if List.member item acc then
                acc

            else
                item :: acc
        )
        []
        list


fallbackPost : Blog.Post
fallbackPost =
    { slug = "getting-started-with-go"
    , title = "Start Being a Gopher"
    , summary = "A practical, no-BS guide to starting with Go with real commands, real code and zero tutorial hell."
    , dateIso = "2026-03-24"
    , dateLabel = "Mar 24, 2026"
    , readTime = "10\u{00A0}min"
    , tags = [ "golang", "programming", "beginners" ]
    , toc =
        [ { id = "intro", text = "Introduction", level = 2 }
        , { id = "good-at", text = "What Go Is Actually Good At", level = 2 }
        , { id = "install", text = "Install Go", level = 2 }
        ]
    , blocks = []
    }


viewUtilityBar : ViewConfig msg -> Html msg
viewUtilityBar config =
    div [ Attr.class "pt-4 space-y-3" ]
        [ div
            [ Attr.attribute "role" "separator"
            , Attr.class "flex items-center justify-center text-[var(--page-subtle)]/65"
            ]
            [ ditherDividerSvg 160 "w-full max-w-[24rem] sm:max-w-[32rem]" ]
        , div [ Attr.class "flex flex-wrap items-center justify-between gap-x-4 gap-y-1 font-mono text-[11px] text-[var(--page-subtle)]" ]
            [ div [ Attr.class "flex items-center gap-x-4" ]
                [ a
                    [ Attr.href "/"
                    , onInternalLinkClick config.onBackHome
                    , Attr.class ("group inline-flex items-center gap-1.5 min-h-11 sm:min-h-7 text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 rounded-xs " ++ focusRing)
                    ]
                    [ chevronLeftIcon
                    , span [] [ text "Portfolio" ]
                    ]
                , a
                    [ Attr.href "/blog"
                    , onInternalLinkClick config.onOpenBlogIndex
                    , Attr.class ("inline-flex items-center min-h-11 sm:min-h-7 text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 rounded-xs " ++ focusRing)
                    ]
                    [ text "Blog" ]
                ]
            , div [ Attr.class "flex items-center gap-x-4" ]
                [ button
                    [ Attr.type_ "button"
                    , Events.onClick config.onToggleTheme
                    , Attr.class ("inline-flex items-center min-h-11 sm:min-h-7 text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 rounded-xs " ++ focusRing)
                    ]
                    [ text
                        (case config.theme of
                            Dark ->
                                "Light"

                            Light ->
                                "Dark"
                        )
                    ]
                , button
                    [ Attr.type_ "button"
                    , Events.onClick config.onToggleMotion
                    , Attr.class ("inline-flex items-center min-h-11 sm:min-h-7 text-[var(--page-subtle)] hover:text-[var(--page-fg)] transition-colors duration-150 rounded-xs " ++ focusRing)
                    ]
                    [ text
                        (if config.motionPlaying then
                            "Pause"

                         else
                            "Play"
                        )
                    ]
                , span [ Attr.class "tabular-nums" ] [ text config.currentYear ]
                ]
            ]
        ]


ditherTailRects : List (Html msg)
ditherTailRects =
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


ditherTailSvg : Html msg
ditherTailSvg =
    svg
        [ SvgAttr.viewBox "0 0 6 6"
        , SvgAttr.preserveAspectRatio "none"
        , SvgAttr.class "block w-4 h-full -ml-px shrink-0"
        , Attr.attribute "shape-rendering" "crispEdges"
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        ditherTailRects


ditherDividerSvg : Int -> String -> Html msg
ditherDividerSvg totalCols widthClass =
    let
        fadeCols =
            totalCols // 4

        solidWidth =
            totalCols - (fadeCols * 2)

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

                threshold =
                    (toFloat (bayer4 x y) + 0.5) / 16.0
            in
            if density > threshold then
                Just (rect [ SvgAttr.x (String.fromInt x), SvgAttr.y (String.fromInt y), SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] [])

            else
                Nothing

        leftEdge =
            List.range 1 2
                |> List.concatMap (\y -> List.range 0 (fadeCols - 1) |> List.filterMap (\x -> edgeCell x y))

        rightEdge =
            List.range 1 2
                |> List.concatMap (\y -> List.range (totalCols - fadeCols) (totalCols - 1) |> List.filterMap (\x -> edgeCell x y))

        solidMid =
            [ rect [ SvgAttr.x (String.fromInt fadeCols), SvgAttr.y "1", SvgAttr.width (String.fromInt solidWidth), SvgAttr.height "2", SvgAttr.fill "currentColor" ] [] ]
    in
    svg
        [ SvgAttr.viewBox ("0 0 " ++ String.fromInt totalCols ++ " 4")
        , SvgAttr.preserveAspectRatio "none"
        , SvgAttr.class ("block h-[3px] " ++ widthClass)
        , Attr.attribute "shape-rendering" "crispEdges"
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        (leftEdge ++ solidMid ++ rightEdge)


chevronLeftIcon : Html msg
chevronLeftIcon =
    svg
        [ SvgAttr.viewBox "0 0 16 16"
        , SvgAttr.fill "none"
        , SvgAttr.class "size-3.5 shrink-0 transition-transform duration-200 ease-out group-hover:-translate-x-0.5"
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        [ path
            [ SvgAttr.d "M9.75 3.75L5.5 8L9.75 12.25"
            , SvgAttr.stroke "currentColor"
            , SvgAttr.strokeWidth "1.5"
            , SvgAttr.strokeLinecap "round"
            , SvgAttr.strokeLinejoin "round"
            ]
            []
        ]
