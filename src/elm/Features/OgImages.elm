module Features.OgImages exposing (Model, Msg, init, update, view)

import Data.Slug as Slug exposing (Slug)
import Data.Theme as Theme exposing (Theme(..))
import Features.Blog as Blog
import Html exposing (Html, a, button, div, h1, h2, h3, img, p, section, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Svg exposing (path, rect, svg)
import Svg.Attributes as SvgAttr


type alias Model =
    { selectedSlug : Maybe Slug
    }


type Msg
    = SelectPost Slug


init : List Blog.Post -> Model
init posts =
    { selectedSlug =
        posts
            |> List.head
            |> Maybe.map .slug
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        SelectPost slug ->
            { model | selectedSlug = Just slug }


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
            model.selectedSlug
                |> Maybe.andThen
                    (\target ->
                        config.posts
                            |> List.filter (\post -> post.slug == target)
                            |> List.head
                    )
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
            "selected for /"
            [ viewCardFrame "og-home-1" "01" "Rising Sheet" (ogHomeRisingSheet ())
            ]
        , viewGroup
            "Blog Index"
            "selected for /blog"
            [ viewCardFrame "og-blog-1" "01" "Writing Sheet" (ogBlogWritingSheet config)
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
                    ("group inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] transition-colors duration-150 "
                        ++ focusRing
                    )
                ]
                [ chevronLeftIcon
                , span [] [ text "Portfolio" ]
                ]
            , span [ Attr.class "font-mono text-[11px] text-[var(--page-subtle)] tabular-nums" ]
                [ text "3 cards · 1200×630" ]
            ]
        , h1 [ Attr.class "font-display font-semibold text-2xl sm:text-[2rem] leading-[1.12] tracking-[-0.03em] text-[var(--page-fg)]" ]
            [ text "Open Graph Studio" ]
        , p [ Attr.class "text-[14.5px] leading-relaxed text-[var(--page-muted)] text-pretty" ]
            [ text "1200×630 social cards for the home page, blog index, and auto-generated blog posts, built with the site's Grainient surfaces, squircles, Bayer dither badges, and Shiki palettes. Toggle Light/Dark below to inspect both themes." ]
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
                            , Attr.attribute "data-og-slug" (Slug.toString item.slug)
                            , Events.onClick (config.toMsg (SelectPost item.slug))
                            , Attr.class ("inline-flex items-stretch h-[22px] font-mono text-[10px] tracking-[0.06em] cursor-pointer rounded-xs " ++ focusRing)
                            ]
                            [ span
                                [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none transition-colors duration-150"
                                , Attr.style "background-color" bgColor
                                , Attr.style "color" fgColor
                                ]
                                [ text (Slug.toString item.slug) ]
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
            [ viewCardFrame "og-post-2" "01" "Framed Editorial" (ogPostFramedEditorial post)
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
-- HOME OG CARD (SELECTED)
-- ============================================================================


ogHomeRisingSheet : () -> Html msg
ogHomeRisingSheet _ =
    div [ Attr.class "og-grainient relative w-full h-full pt-[6.5cqw] px-[6.5cqw] flex flex-col" ]
        [ div [ Attr.class "og-squircle-top relative flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[5cqw] pt-[4.5cqw] pb-[3.5cqw] flex flex-col justify-between overflow-hidden" ]
            [ div [ Attr.class "flex items-start justify-between gap-[3cqw]" ]
                [ div [ Attr.class "space-y-[1.4cqw] min-w-0" ]
                    [ ogBadge "About" "var(--tab-bg)" "var(--tab-fg)"
                    , h3 [ Attr.class "font-display font-semibold text-[5.4cqw] leading-[1.04] tracking-[-0.035em] text-[var(--page-fg)]" ]
                        [ text "Alaa El-Samouly" ]
                    , p [ Attr.class "text-[2.05cqw] leading-[1.48] text-[var(--page-muted)] max-w-[52cqw]" ]
                        [ text "Software engineer at "
                        , span [ Attr.class "text-[var(--page-fg)] font-medium" ] [ text "Charm" ]
                        , text ", playing with terminal interfaces and CLI tooling in "
                        , span [ Attr.class "text-[var(--page-fg)] font-medium" ] [ text "Go" ]
                        , text ", plus web applications in "
                        , span [ Attr.class "text-[var(--page-fg)] font-medium" ] [ text "Nuxt" ]
                        , text ", "
                        , span [ Attr.class "text-[var(--page-fg)] font-medium" ] [ text "Vue" ]
                        , text " and "
                        , span [ Attr.class "text-[var(--page-fg)] font-medium" ] [ text "Elm" ]
                        , text "."
                        ]
                    ]
                , img
                    [ Attr.src "/images/sam0-avatar.png"
                    , Attr.alt "Alaa El-Samouly"
                    , Attr.class "size-[11.5cqw] og-squircle-sm object-cover shrink-0 ring-1 ring-[var(--page-line)]"
                    ]
                    []
                ]
            , div [ Attr.class "flex items-center justify-between gap-[2cqw] pt-[2cqw]" ]
                [ div [ Attr.class "flex items-center gap-[1.1cqw]" ]
                    [ ogBadge "Twig" "var(--callout-note-bg)" "var(--callout-note-fg)"
                    , ogBadge "mural" "var(--callout-tip-bg)" "var(--callout-tip-fg)"
                    , ogBadge "Spin" "var(--callout-warn-bg)" "var(--callout-warn-fg)"
                    , ogBadge "bubbleMonitor" "var(--tab-bg)" "var(--tab-fg)"
                    ]
                , span [ Attr.class "font-mono text-[1.4cqw] text-[var(--page-subtle)] shrink-0" ]
                    [ text "portforio.samouly.fun" ]
                ]
            , div [ Attr.class "pointer-events-none absolute right-[1.1cqw] top-[5cqw] bottom-0 w-[0.95cqw] rounded-t-full grainient-scroll-track" ] []
            ]
        ]



-- ============================================================================
-- BLOG INDEX OG CARD (SELECTED)
-- ============================================================================


ogBlogWritingSheet : ViewConfig msg -> Html msg
ogBlogWritingSheet config =
    let
        recent =
            List.take 3 config.posts

        totalPosts =
            List.length config.posts

        countLabel =
            if totalPosts == 1 then
                "1 post"

            else
                String.fromInt totalPosts ++ " posts"
    in
    div [ Attr.class "og-grainient relative w-full h-full pt-[6.5cqw] px-[6.5cqw] flex flex-col" ]
        [ div [ Attr.class "og-squircle-top relative flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[5cqw] pt-[4cqw] pb-[3.2cqw] flex flex-col justify-between overflow-hidden" ]
            [ div [ Attr.class "space-y-[2cqw]" ]
                [ div [ Attr.class "flex items-end justify-between gap-[2cqw]" ]
                    [ div [ Attr.class "space-y-[0.9cqw]" ]
                        [ ogBadge "Blog" "var(--callout-note-bg)" "var(--callout-note-fg)"
                        , h3 [ Attr.class "font-display font-semibold text-[4.4cqw] leading-[1.02] tracking-[-0.035em] text-[var(--page-fg)]" ]
                            [ text "Writing" ]
                        ]
                    , span [ Attr.class "font-mono text-[1.4cqw] text-[var(--page-subtle)] tabular-nums pb-[0.4cqw]" ]
                        [ text countLabel ]
                    ]
                , div [ Attr.class "text-[var(--page-subtle)]/55" ]
                    [ ditherDividerSvg 160 "w-full" ]
                ]
            , div [ Attr.class "flex flex-col divide-y divide-[var(--page-line)]" ]
                (List.indexedMap
                    (\idx post ->
                        let
                            num =
                                "0" ++ String.fromInt (idx + 1)

                            accentColor =
                                case idx of
                                    0 ->
                                        "var(--callout-note-bg)"

                                    1 ->
                                        "var(--callout-tip-bg)"

                                    _ ->
                                        "var(--callout-warn-bg)"
                        in
                        div [ Attr.class "py-[1.55cqw] first:pt-0 last:pb-0 flex items-start gap-[1.8cqw]" ]
                            [ span
                                [ Attr.class "font-mono text-[1.3cqw] font-medium tabular-nums pt-[0.38cqw] shrink-0"
                                , Attr.style "color" accentColor
                                ]
                                [ text num ]
                            , div [ Attr.class "flex-1 min-w-0 space-y-[0.45cqw]" ]
                                [ div [ Attr.class "flex items-baseline justify-between gap-[2cqw]" ]
                                    [ span [ Attr.class "font-display font-medium text-[1.95cqw] leading-[1.2] tracking-[-0.015em] text-[var(--page-fg)] truncate" ]
                                        [ text post.title ]
                                    , span [ Attr.class "shrink-0 font-mono text-[1.25cqw] text-[var(--page-subtle)] tabular-nums" ]
                                        [ text (post.dateLabel ++ " · " ++ post.readTime) ]
                                    ]
                                , p [ Attr.class "text-[1.4cqw] leading-[1.35] text-[var(--page-muted)] truncate" ]
                                    [ text post.summary ]
                                ]
                            ]
                    )
                    recent
                )
            , div [ Attr.class "flex items-center justify-between pt-[0.6cqw]" ]
                [ div [ Attr.class "flex items-center gap-[1.2cqw]" ]
                    [ img
                        [ Attr.src "/images/sam0-avatar.png"
                        , Attr.alt "Alaa El-Samouly"
                        , Attr.class "size-[2.8cqw] og-squircle-sm object-cover shrink-0 ring-1 ring-[var(--page-line)]"
                        ]
                        []
                    , span [ Attr.class "font-mono text-[1.35cqw] text-[var(--page-muted)]" ]
                        [ text "Alaa El-Samouly" ]
                    ]
                , span [ Attr.class "font-mono text-[1.35cqw] text-[var(--page-subtle)]" ]
                    [ text "portforio.samouly.fun/blog" ]
                ]
            , div [ Attr.class "pointer-events-none absolute right-[1.1cqw] top-[5cqw] bottom-0 w-[0.95cqw] rounded-t-full grainient-scroll-track" ] []
            ]
        ]



-- ============================================================================
-- AUTO-GENERATED BLOG POST OG CARD (SELECTED)
-- ============================================================================


ogPostFramedEditorial : Blog.Post -> Html msg
ogPostFramedEditorial post =
    let
        tags =
            if List.isEmpty post.tags then
                [ "Article" ]

            else
                List.take 4 post.tags

        tagBadge idx tag =
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
    in
    div [ Attr.class "og-grainient relative w-full h-full p-[3.2cqw] flex" ]
        [ div [ Attr.class "og-squircle flex-1 bg-[var(--page-bg)] shadow-[var(--sheet-outer-shadow)] px-[5.4cqw] py-[4.4cqw] flex flex-col justify-between" ]
            [ div [ Attr.class "flex items-center justify-between gap-[2cqw]" ]
                [ div [ Attr.class "flex flex-wrap gap-[1cqw]" ]
                    (List.indexedMap tagBadge tags)
                , span [ Attr.class "font-mono text-[1.45cqw] text-[var(--page-subtle)] tabular-nums shrink-0" ]
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
                , div [ Attr.class "flex items-center gap-[1.4cqw] font-mono text-[1.4cqw]" ]
                    [ img [ Attr.src "/images/sam0-avatar.png", Attr.alt "Samouly", Attr.class "size-[3.6cqw] rounded-full object-cover" ] []
                    , span [ Attr.class "text-[var(--page-fg)]" ] [ text "Alaa El-Samouly" ]
                    ]
                ]
            ]
        ]


-- ============================================================================
-- SHARED PRIMITIVES & HELPERS
-- ============================================================================


ogBadge : String -> String -> String -> Html msg
ogBadge label bgColor fgColor =
    span [ Attr.class "inline-flex items-stretch h-[2.5cqw] font-mono text-[1.25cqw] font-medium tracking-[0.06em] shrink-0" ]
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


fallbackPost : Blog.Post
fallbackPost =
    { slug = Slug.fromString "getting-started-with-go" |> Maybe.withDefault Slug.default
    , title = "Start Being a Gopher"
    , summary = "A practical, no-BS guide to starting with Go with real commands, real code and zero tutorial hell."
    , dateIso = "2026-03-24"
    , dateLabel = "Mar 24, 2026"
    , readTime = "10\u{00A0}min"
    , tags = [ "golang", "programming", "beginners" ]
    , toc = []
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
