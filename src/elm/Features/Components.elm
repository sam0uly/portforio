module Features.Components exposing
    ( ComponentEntry
    , FrameworkId(..)
    , Model
    , Msg
    , ViewConfig
    , clearCopied
    , decodeList
    , ensureLoaded
    , findBySlug
    , init
    , isPreviewFooterAnimating
    , tickPreviewFooter
    , update
    , viewDetail
    , viewIndex
    )

import Data.Slug as Slug exposing (Slug)
import Data.Theme exposing (Theme(..))
import Effects.DitherFooter as DitherFooter
import Features.Blog as Blog
import Features.GithubGraph as GithubGraph
import Html exposing (Html, a, aside, button, code, div, h1, h2, p, pre, section, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Json.Decode as Decode exposing (Decoder)
import Svg exposing (path, rect, svg)
import Svg.Attributes as SvgAttr


type FrameworkId
    = Vue
    | React
    | Elm


type alias CodeToken =
    { text : String
    , dark : String
    , light : String
    }


type alias CodeSnippet =
    { lang : String
    , filename : String
    , code : String
    , lines : List (List CodeToken)
    }


type alias FrameworkCode =
    { id : FrameworkId
    , usage : Maybe CodeSnippet
    , source : Maybe CodeSnippet
    }


type alias ComponentEntry =
    { slug : Slug
    , title : String
    , category : String
    , order : Int
    , preview : String
    , summary : String
    , tags : List String
    , description : String
    , descriptionBlocks : List Blog.Block
    , frameworks : List FrameworkCode
    }


type alias BoxRect =
    { left : Float
    , top : Float
    , width : Float
    , height : Float
    , visible : Bool
    , animate : Bool
    }


type FooterHeight
    = FooterCompact
    | FooterStandard
    | FooterTall


type FooterThemeOverride
    = ThemeFollow
    | ThemeDark
    | ThemeLight


type alias Model =
    { items : List ComponentEntry
    , activeCategory : Maybe String
    , hoveredCard : Maybe BoxRect
    , hoveredCat : Maybe BoxRect
    , activeFramework : FrameworkId
    , copiedCode : Maybe String
    , previewBtnOpen : Bool
    , previewTab : Int
    , previewDrawerOpen : Maybe String
    , previewDrawerHover : Maybe BoxRect
    , previewCallout : Int
    , previewCodeCopied : Bool
    , previewBentoFilter : Int
    , previewDeckIdx : Int
    , previewDeckPrev : Maybe Int
    , previewDeckDir : Int
    , previewMatrixTech : Maybe String
    , previewFooter : DitherFooter.Model
    , previewFooterPlaying : Bool
    , previewFooterSpeed : Float
    , previewFooterHeight : FooterHeight
    , previewFooterTheme : FooterThemeOverride
    , previewFooterRippleSeq : Int
    }


type Msg
    = SelectCategory (Maybe String)
    | HoverCard (Maybe BoxRect)
    | HoverCategory (Maybe BoxRect)
    | SelectFramework FrameworkId
    | CopyCode String
    | GotDetail Slug (Result Http.Error { description : String, descriptionBlocks : List Blog.Block, frameworks : List FrameworkCode })
    | TogglePreviewBtn
    | SetPreviewTab Int
    | TogglePreviewDrawer String
    | HoverPreviewDrawer (Maybe BoxRect)
    | SetPreviewCallout Int
    | TogglePreviewCodeCopy
    | SetPreviewBento Int
    | StepPreviewDeck Int
    | SetPreviewDeck Int
    | TogglePreviewMatrix String
    | PreviewFooterMsg DitherFooter.Msg
    | TogglePreviewFooterMotion
    | SetPreviewFooterSpeed Float
    | SetPreviewFooterHeight FooterHeight
    | SetPreviewFooterTheme FooterThemeOverride
    | TriggerPreviewFooterRipple
    | ReplayPreviewFooterIntro


type alias ViewConfig msg =
    { toMsg : Msg -> msg
    , onBackHome : msg
    , onOpenComponentsIndex : msg
    , onOpenComponent : Slug -> msg
    , onOpenBlogIndex : msg
    , onToggleTheme : msg
    , onToggleMotion : msg
    , onGithubGraphMsg : GithubGraph.Msg -> msg
    , onTogglePrWing : msg
    , githubGraph : GithubGraph.Model
    , prOpen : Bool
    , prCoverage : Float
    , theme : Theme
    , motionPlaying : Bool
    , currentYear : String
    }


init : Bool -> List ComponentEntry -> Model
init prefersReduced items =
    { items = items
    , activeCategory = Nothing
    , hoveredCard = Nothing
    , hoveredCat = Nothing
    , activeFramework = Vue
    , copiedCode = Nothing
    , previewBtnOpen = False
    , previewTab = 0
    , previewDrawerOpen = Just "twig"
    , previewDrawerHover = Nothing
    , previewCallout = 0
    , previewCodeCopied = False
    , previewBentoFilter = 0
    , previewDeckIdx = 0
    , previewDeckPrev = Nothing
    , previewDeckDir = 1
    , previewMatrixTech = Nothing
    , previewFooter = DitherFooter.init prefersReduced
    , previewFooterPlaying = not prefersReduced
    , previewFooterSpeed = 1.0
    , previewFooterHeight = FooterStandard
    , previewFooterTheme = ThemeFollow
    , previewFooterRippleSeq = 0
    }


isPreviewFooterAnimating : Model -> Bool
isPreviewFooterAnimating model =
    model.previewFooterPlaying || DitherFooter.isAnimating model.previewFooter


tickPreviewFooter : Float -> Model -> Model
tickPreviewFooter dtMs model =
    { model | previewFooter = DitherFooter.tick model.previewFooterPlaying (dtMs * model.previewFooterSpeed) model.previewFooter }


findBySlug : Slug -> Model -> Maybe ComponentEntry
findBySlug slug model =
    model.items
        |> List.filter (\item -> item.slug == slug)
        |> List.head


clearCopied : Model -> Model
clearCopied model =
    { model | copiedCode = Nothing }


ensureLoaded : Slug -> Model -> Cmd Msg
ensureLoaded slug model =
    case findBySlug slug model of
        Just item ->
            if List.isEmpty item.frameworks then
                Http.get
                    { url = "/component-data/" ++ Slug.toString slug ++ ".json"
                    , expect = Http.expectJson (GotDetail slug) decodeDetailPayload
                    }

            else
                Cmd.none

        Nothing ->
            Cmd.none


update : Msg -> Model -> ( Model, Maybe String )
update msg model =
    case msg of
        SelectCategory maybeCat ->
            let
                nextCat =
                    if model.activeCategory == maybeCat then
                        Nothing

                    else
                        maybeCat
            in
            ( { model
                | activeCategory = nextCat
                , hoveredCard = Maybe.map (\r -> { r | visible = False, animate = False }) model.hoveredCard
              }
            , Nothing
            )

        HoverCard maybeRect ->
            let
                wasVisible =
                    Maybe.map .visible model.hoveredCard == Just True

                nextHover =
                    case maybeRect of
                        Just r ->
                            Just { r | animate = wasVisible }

                        Nothing ->
                            Maybe.map (\r -> { r | visible = False, animate = False }) model.hoveredCard
            in
            ( { model | hoveredCard = nextHover }, Nothing )

        HoverCategory maybeRect ->
            let
                wasVisible =
                    Maybe.map .visible model.hoveredCat == Just True

                nextHover =
                    case maybeRect of
                        Just r ->
                            Just { r | animate = wasVisible }

                        Nothing ->
                            Maybe.map (\r -> { r | visible = False, animate = False }) model.hoveredCat
            in
            ( { model | hoveredCat = nextHover }, Nothing )

        SelectFramework fw ->
            ( { model | activeFramework = fw }, Nothing )

        CopyCode snippet ->
            ( { model | copiedCode = Just snippet }, Just snippet )

        GotDetail slug (Ok payload) ->
            let
                nextItems =
                    List.map
                        (\item ->
                            if item.slug == slug then
                                { item
                                    | description = payload.description
                                    , descriptionBlocks = payload.descriptionBlocks
                                    , frameworks = payload.frameworks
                                }

                            else
                                item
                        )
                        model.items
            in
            ( { model | items = nextItems }, Nothing )

        GotDetail _ (Err _) ->
            ( model, Nothing )

        TogglePreviewBtn ->
            ( { model | previewBtnOpen = not model.previewBtnOpen }, Nothing )

        SetPreviewTab idx ->
            ( { model | previewTab = idx }, Nothing )

        TogglePreviewDrawer id ->
            let
                next =
                    if model.previewDrawerOpen == Just id then
                        Nothing

                    else
                        Just id
            in
            ( { model
                | previewDrawerOpen = next
                , previewDrawerHover = Maybe.map (\r -> { r | visible = False, animate = False }) model.previewDrawerHover
              }
            , Nothing
            )

        HoverPreviewDrawer maybeRect ->
            let
                wasVisible =
                    Maybe.map .visible model.previewDrawerHover == Just True

                nextHover =
                    case maybeRect of
                        Just r ->
                            if r.visible then
                                Just { r | animate = wasVisible }

                            else
                                Maybe.map (\prev -> { prev | visible = False, animate = False }) model.previewDrawerHover

                        Nothing ->
                            Maybe.map (\r -> { r | visible = False, animate = False }) model.previewDrawerHover
            in
            ( { model | previewDrawerHover = nextHover }, Nothing )

        SetPreviewCallout idx ->
            ( { model | previewCallout = idx }, Nothing )

        TogglePreviewCodeCopy ->
            ( { model | previewCodeCopied = not model.previewCodeCopied }, Nothing )

        SetPreviewBento idx ->
            ( { model | previewBentoFilter = idx }, Nothing )

        StepPreviewDeck delta ->
            let
                nextIdx =
                    modBy 4 (model.previewDeckIdx + delta + 4)
            in
            ( { model
                | previewDeckIdx = nextIdx
                , previewDeckPrev = Just model.previewDeckIdx
                , previewDeckDir =
                    if delta < 0 then
                        -1

                    else
                        1
              }
            , Nothing
            )

        SetPreviewDeck idx ->
            let
                nextIdx =
                    modBy 4 idx
            in
            if nextIdx == model.previewDeckIdx then
                ( model, Nothing )

            else
                ( { model
                    | previewDeckIdx = nextIdx
                    , previewDeckPrev = Just model.previewDeckIdx
                    , previewDeckDir =
                        if nextIdx < model.previewDeckIdx then
                            -1

                        else
                            1
                  }
                , Nothing
                )

        TogglePreviewMatrix tech ->
            let
                next =
                    if model.previewMatrixTech == Just tech then
                        Nothing

                    else
                        Just tech
            in
            ( { model | previewMatrixTech = next }, Nothing )

        PreviewFooterMsg subMsg ->
            ( { model | previewFooter = DitherFooter.update subMsg model.previewFooter }, Nothing )

        TogglePreviewFooterMotion ->
            ( { model | previewFooterPlaying = not model.previewFooterPlaying }, Nothing )

        SetPreviewFooterSpeed spd ->
            ( { model | previewFooterSpeed = spd }, Nothing )

        SetPreviewFooterHeight h ->
            ( { model | previewFooterHeight = h }, Nothing )

        SetPreviewFooterTheme th ->
            ( { model | previewFooterTheme = th }, Nothing )

        TriggerPreviewFooterRipple ->
            let
                seq =
                    model.previewFooterRippleSeq

                ( rx, ry ) =
                    case modBy 4 seq of
                        0 ->
                            ( 0.5, 0.34 )

                        1 ->
                            ( 0.28, 0.38 )

                        2 ->
                            ( 0.72, 0.32 )

                        _ ->
                            ( 0.42, 0.28 )
            in
            ( { model
                | previewFooter = DitherFooter.spawnRipple rx ry model.previewFooter
                , previewFooterRippleSeq = seq + 1
              }
            , Nothing
            )

        ReplayPreviewFooterIntro ->
            ( { model | previewFooter = DitherFooter.replayIntro model.previewFooter }, Nothing )



-- DECODERS


decodeList : Decoder (List ComponentEntry)
decodeList =
    Decode.list decodeEntry


decodeEntry : Decoder ComponentEntry
decodeEntry =
    Decode.map8
        (\slug title category order preview summary tags description ->
            ComponentEntry slug title category order preview summary tags description
        )
        (Decode.field "slug" Slug.decoder)
        (Decode.field "title" Decode.string)
        (Decode.field "category" Decode.string)
        (Decode.field "order" Decode.int)
        (Decode.field "preview" Decode.string)
        (Decode.field "summary" Decode.string)
        (Decode.field "tags" (Decode.list Decode.string))
        (Decode.field "description" Decode.string)
        |> Decode.andThen
            (\build ->
                Decode.map2 build
                    (Decode.oneOf
                        [ Decode.field "descriptionBlocks" (Decode.list Blog.decodeBlock)
                        , Decode.succeed []
                        ]
                    )
                    (Decode.oneOf
                        [ Decode.field "frameworks" (Decode.list decodeFramework)
                        , Decode.succeed []
                        ]
                    )
            )


decodeDetailPayload : Decoder { description : String, descriptionBlocks : List Blog.Block, frameworks : List FrameworkCode }
decodeDetailPayload =
    Decode.map3 (\d b f -> { description = d, descriptionBlocks = b, frameworks = f })
        (Decode.field "description" Decode.string)
        (Decode.oneOf
            [ Decode.field "descriptionBlocks" (Decode.list Blog.decodeBlock)
            , Decode.succeed []
            ]
        )
        (Decode.field "frameworks" (Decode.list decodeFramework))


decodeFramework : Decoder FrameworkCode
decodeFramework =
    Decode.map3 FrameworkCode
        (Decode.field "id" decodeFrameworkId)
        (Decode.field "usage" (Decode.nullable decodeSnippet))
        (Decode.field "source" (Decode.nullable decodeSnippet))


decodeFrameworkId : Decoder FrameworkId
decodeFrameworkId =
    Decode.string
        |> Decode.andThen
            (\raw ->
                case String.toLower raw of
                    "vue" ->
                        Decode.succeed Vue

                    "react" ->
                        Decode.succeed React

                    "elm" ->
                        Decode.succeed Elm

                    _ ->
                        Decode.fail ("Unknown framework: " ++ raw)
            )


decodeSnippet : Decoder CodeSnippet
decodeSnippet =
    Decode.map4 CodeSnippet
        (Decode.field "lang" Decode.string)
        (Decode.field "filename" Decode.string)
        (Decode.field "code" Decode.string)
        (Decode.field "lines" (Decode.list (Decode.list decodeToken)))


decodeToken : Decoder CodeToken
decodeToken =
    Decode.map3 CodeToken
        (Decode.field "t" Decode.string)
        (Decode.field "d" Decode.string)
        (Decode.field "l" Decode.string)



-- SHARED HELPERS


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


uniqueCategories : List ComponentEntry -> List String
uniqueCategories items =
    List.foldr
        (\item acc ->
            if List.member item.category acc then
                acc

            else
                item.category :: acc
        )
        []
        items


boxRectDecoder : Bool -> (Maybe BoxRect -> msg) -> Decoder msg
boxRectDecoder isVisible toMsg =
    Decode.map4
        (\l t w h -> toMsg (Just { left = l, top = t, width = w, height = h, visible = isVisible, animate = False }))
        (Decode.at [ "currentTarget", "offsetLeft" ] Decode.float)
        (Decode.at [ "currentTarget", "offsetTop" ] Decode.float)
        (Decode.at [ "currentTarget", "offsetWidth" ] Decode.float)
        (Decode.at [ "currentTarget", "offsetHeight" ] Decode.float)


slideBgOverlay : String -> Maybe BoxRect -> Html msg
slideBgOverlay bgClass maybeRect =
    let
        ( animClass, styles ) =
            case maybeRect of
                Just r ->
                    ( if r.animate then
                        "work-slide-bg"

                      else
                        "work-slide-bg-snap"
                    , [ Attr.style "transform" ("translate3d(" ++ String.fromFloat r.left ++ "px, " ++ String.fromFloat r.top ++ "px, 0)")
                      , Attr.style "width" (String.fromFloat r.width ++ "px")
                      , Attr.style "height" (String.fromFloat r.height ++ "px")
                      , Attr.style "opacity"
                            (if r.visible then
                                "1"

                             else
                                "0"
                            )
                      ]
                    )

                Nothing ->
                    ( "work-slide-bg-snap"
                    , [ Attr.style "transform" "translate3d(0px, 0px, 0)"
                      , Attr.style "width" "0px"
                      , Attr.style "height" "0px"
                      , Attr.style "opacity" "0"
                      ]
                    )
    in
    div
        ([ Attr.attribute "aria-hidden" "true"
         , Attr.class (animClass ++ " pointer-events-none absolute left-0 top-0 z-0 box-squircle " ++ bgClass)
         ]
            ++ styles
        )
        []



-- INDEX VIEW (/components)


viewIndex : ViewConfig msg -> Model -> Html msg
viewIndex config model =
    let
        categories =
            uniqueCategories model.items

        filtered =
            case model.activeCategory of
                Nothing ->
                    model.items

                Just cat ->
                    List.filter (\item -> item.category == cat) model.items
    in
    div [ Attr.class "flex flex-col pointer-events-auto space-y-8" ]
        [ section [ Attr.class "space-y-3" ]
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
                    [ text (String.fromInt (List.length model.items) ++ " components · Vue · React · Elm") ]
                ]
            , h1 [ Attr.class "font-display font-semibold text-2xl sm:text-[2.125rem] leading-[1.08] tracking-[-0.03em] text-[var(--page-fg)]" ]
                [ text "Samponents" ]
            , p [ Attr.class "text-[14.5px] leading-relaxed text-[var(--page-muted)] text-pretty" ]
                [ text "Copy-paste styled components built for this portfolio with Tailwind CSS, shipped with full usage and source code for Vue, React, and Elm. Click any card to inspect its preview and code." ]
            ]
        , div
            [ Attr.class "relative flex flex-wrap items-center gap-1.5"
            , Events.onMouseLeave (config.toMsg (HoverCategory Nothing))
            ]
            (slideBgOverlay "bg-[var(--tab-bg)]/65" model.hoveredCat
                :: categoryPill config.toMsg "All" Nothing (model.activeCategory == Nothing)
                :: List.map
                    (\cat -> categoryPill config.toMsg cat (Just cat) (model.activeCategory == Just cat))
                    categories
            )
        , div
            [ Attr.class "relative grid grid-cols-1 sm:grid-cols-2 gap-3.5"
            , Events.onMouseLeave (config.toMsg (HoverCard Nothing))
            ]
            (slideBgOverlay "bg-[var(--tab-bg)]/70" model.hoveredCard
                :: List.map (viewShowcaseCard config model) filtered
            )
        , viewUtilityBar config "/" "Portfolio" config.onBackHome
        ]


categoryPill : (Msg -> msg) -> String -> Maybe String -> Bool -> Html msg
categoryPill toMsg label target isActive =
    button
        [ Attr.type_ "button"
        , Events.onClick (toMsg (SelectCategory target))
        , Events.on "mouseenter" (boxRectDecoder True (HoverCategory >> toMsg))
        , Attr.class
            ("relative z-10 box-squircle px-3 py-1 font-mono text-[11px] cursor-pointer transition-colors duration-150 "
                ++ (if isActive then
                        "bg-[var(--tab-bg)] text-[var(--page-fg)] font-medium"

                    else
                        "bg-[var(--tab-bg)]/25 text-[var(--page-muted)] hover:text-[var(--page-fg)]"
                   )
                ++ " "
                ++ focusRing
            )
        ]
        [ text label ]


viewShowcaseCard : ViewConfig msg -> Model -> ComponentEntry -> Html msg
viewShowcaseCard config model item =
    div
        [ Events.on "mouseenter" (boxRectDecoder True (HoverCard >> config.toMsg))
        , Attr.class "group/card relative z-10 box-squircle bg-[var(--tab-bg)]/30 transition-colors duration-200 p-4 flex flex-col justify-between gap-4"
        ]
        [ div [ Attr.class "group/preview box-squircle bg-[var(--page-bg)] min-h-[108px] px-4 py-5 flex items-center justify-center overflow-hidden" ]
            [ viewMiniPreview config model item.preview ]
        , a
            [ Attr.href ("/components/" ++ Slug.toString item.slug)
            , onInternalLinkClick (config.onOpenComponent item.slug)
            , Attr.class ("block space-y-1.5 rounded-xs " ++ focusRing)
            ]
            [ div [ Attr.class "flex items-center justify-between gap-2" ]
                [ h2 [ Attr.class "font-display font-semibold text-[15px] text-[var(--page-fg)] tracking-[-0.015em]" ]
                    [ text item.title ]
                , span [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)] group-hover/card:text-[var(--page-fg)] transition-colors duration-150 shrink-0" ]
                    [ text "Inspect →" ]
                ]
            , p [ Attr.class "text-[12.5px] leading-relaxed text-[var(--page-muted)] text-pretty line-clamp-2" ]
                [ text item.summary ]
            , div [ Attr.class "pt-1 flex items-center justify-between gap-2 font-mono text-[10px] text-[var(--page-subtle)]" ]
                [ bayerBadge item.category "var(--tab-bg)" "var(--tab-fg)"
                , span [] [ text "Vue · React · Elm" ]
                ]
            ]
        ]



-- DETAIL VIEW (/components/<slug>)


viewDetail : ViewConfig msg -> Model -> Slug -> Html msg
viewDetail config model slug =
    case findBySlug slug model of
        Nothing ->
            div [ Attr.class "flex flex-col pointer-events-auto space-y-6 py-6" ]
                [ bayerBadge "404" "var(--callout-warn-bg)" "var(--callout-warn-fg)"
                , div [ Attr.class "space-y-2" ]
                    [ h1 [ Attr.class "font-display font-semibold text-2xl text-[var(--page-fg)]" ]
                        [ text "Component not found" ]
                    , p [ Attr.class "text-sm text-[var(--page-muted)]" ]
                        [ text ("No component exists at /components/" ++ Slug.toString slug ++ ".") ]
                    ]
                , div [ Attr.class "flex items-center gap-3" ]
                    [ a
                        [ Attr.href "/components"
                        , onInternalLinkClick config.onOpenComponentsIndex
                        , Attr.class ("group inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] transition-colors duration-150 " ++ focusRing)
                        ]
                        [ chevronLeftIcon, text "All components" ]
                    ]
                , viewUtilityBar config "/" "Portfolio" config.onBackHome
                ]

        Just item ->
            let
                fwIdx =
                    case model.activeFramework of
                        Vue ->
                            0

                        React ->
                            1

                        Elm ->
                            2

                selectedFw =
                    item.frameworks
                        |> List.filter (\f -> f.id == model.activeFramework)
                        |> List.head
                        |> Maybe.withDefault
                            (item.frameworks
                                |> List.head
                                |> Maybe.withDefault { id = model.activeFramework, usage = Nothing, source = Nothing }
                            )
            in
            div [ Attr.class "flex flex-col pointer-events-auto space-y-8" ]
                [ section [ Attr.class "space-y-3" ]
                    [ div [ Attr.class "flex items-center justify-between gap-x-4" ]
                        [ a
                            [ Attr.href "/components"
                            , onInternalLinkClick config.onOpenComponentsIndex
                            , Attr.class
                                ("group inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] transition-colors duration-150 "
                                    ++ focusRing
                                )
                            ]
                            [ chevronLeftIcon
                            , span [] [ text "Components" ]
                            ]
                        , bayerBadge item.category "var(--callout-note-bg)" "var(--callout-note-fg)"
                        ]
                    , h1 [ Attr.class "font-display font-semibold text-2xl sm:text-[2rem] leading-[1.1] tracking-[-0.03em] text-[var(--page-fg)]" ]
                        [ text item.title ]
                    , if List.isEmpty item.descriptionBlocks then
                        p [ Attr.class "text-[14.5px] leading-relaxed text-[var(--page-muted)] text-pretty" ]
                            [ text item.summary ]

                      else
                        Blog.viewMarkdownBlocks (\codeStr -> config.toMsg (CopyCode codeStr)) config.theme model.copiedCode item.descriptionBlocks
                    ]
                , section [ Attr.class "space-y-2.5" ]
                    [ div [ Attr.class "flex items-center justify-between font-mono text-[10.5px] text-[var(--page-subtle)]" ]
                        [ span [] [ text "Interactive Preview" ]
                        , span [] [ text (String.join " · " item.tags) ]
                        ]
                    , div [ Attr.class "box-squircle bg-[var(--surface-1)] p-6 sm:p-8 min-h-[150px] flex items-center justify-center" ]
                        [ viewInteractivePreview config model item.preview ]
                    ]
                , section [ Attr.class "space-y-5" ]
                    [ div [ Attr.class "flex flex-wrap items-center justify-between gap-3" ]
                        [ div [ Attr.class "relative inline-grid grid-cols-3 w-full sm:w-[17rem] p-0.5 box-squircle bg-[var(--surface-2)]" ]
                            [ div
                                [ Attr.class "pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 w-[calc((100%-4px)/3)] box-squircle bg-[var(--tab-bg)] transition-transform duration-200 ease-out"
                                , Attr.style "transform" ("translate3d(" ++ String.fromInt (fwIdx * 100) ++ "%, 0, 0)")
                                ]
                                []
                            , frameworkTab config.toMsg model.activeFramework Vue "Vue"
                            , frameworkTab config.toMsg model.activeFramework React "React"
                            , frameworkTab config.toMsg model.activeFramework Elm "Elm"
                            ]
                        , span [ Attr.class "font-mono text-[11px] text-[var(--page-subtle)]" ]
                            [ text "Tailwind CSS · Copy & Paste" ]
                        ]
                    , if List.isEmpty item.frameworks then
                        div [ Attr.class "box-squircle bg-[var(--code-bg)] px-4 py-8 font-mono text-xs text-[var(--page-subtle)]" ]
                            [ text "Loading code snippets…" ]

                      else
                        div [ Attr.class "space-y-5" ]
                            [ case selectedFw.usage of
                                Just snippet ->
                                    viewCodePanel config.toMsg config.theme model.copiedCode "Usage" snippet

                                Nothing ->
                                    text ""
                            , case selectedFw.source of
                                Just snippet ->
                                    viewCodePanel config.toMsg config.theme model.copiedCode "Source" snippet

                                Nothing ->
                                    text ""
                            ]
                    ]
                , viewUtilityBar config "/components" "Components" config.onOpenComponentsIndex
                ]


frameworkTab : (Msg -> msg) -> FrameworkId -> FrameworkId -> String -> Html msg
frameworkTab toMsg active target label =
    button
        [ Attr.type_ "button"
        , Events.onClick (toMsg (SelectFramework target))
        , Attr.class
            ("relative z-10 py-1.5 font-mono text-[11.5px] cursor-pointer transition-colors duration-150 "
                ++ (if active == target then
                        "text-[var(--page-fg)] font-medium"

                    else
                        "text-[var(--page-subtle)] hover:text-[var(--page-muted)]"
                   )
                ++ " "
                ++ focusRing
            )
        ]
        [ text label ]


viewCodePanel : (Msg -> msg) -> Theme -> Maybe String -> String -> CodeSnippet -> Html msg
viewCodePanel toMsg theme copiedCode sectionLabel snippet =
    let
        isCopied =
            copiedCode == Just snippet.code

        headerTitle =
            if not (String.isEmpty snippet.filename) then
                snippet.filename

            else if not (String.isEmpty snippet.lang) then
                snippet.lang

            else
                "code"
    in
    div [ Attr.class "space-y-2" ]
        [ div [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)]" ]
            [ text sectionLabel ]
        , div [ Attr.class "box-squircle bg-[var(--code-bg)] overflow-hidden" ]
            [ div [ Attr.class "flex items-center justify-between gap-x-3 pl-4 pr-2.5 pt-2.5 pb-1" ]
                [ bayerBadge headerTitle "var(--tab-bg)" "var(--tab-fg)"
                , button
                    [ Attr.type_ "button"
                    , Events.onClick (toMsg (CopyCode snippet.code))
                    , Attr.attribute "aria-label"
                        (if isCopied then
                            "Copied"

                         else
                            "Copy code"
                        )
                    , Attr.class
                        ("inline-flex items-center justify-center size-8 btn-squircle transition-colors duration-150 cursor-pointer "
                            ++ (if isCopied then
                                    "text-[var(--page-fg)] bg-[var(--tab-bg)]"

                                else
                                    "text-[var(--page-subtle)] hover:text-[var(--page-fg)] hover:bg-[var(--tab-bg)]"
                               )
                            ++ " "
                            ++ focusRing
                        )
                    ]
                    [ morphCopyIcon isCopied ]
                ]
            , pre [ Attr.class "pt-2 pb-4 px-4 overflow-x-auto scroll-clean font-mono text-[13px] leading-[1.7] text-[var(--page-fg)]" ]
                [ code [ Attr.attribute "translate" "no", Attr.class "block min-w-max" ]
                    (List.indexedMap
                        (\idx lineTokens ->
                            span [ Attr.class "block" ]
                                (span
                                    [ Attr.class "inline-block w-7 mr-3 text-right select-none text-[var(--page-subtle)]/45 tabular-nums text-[11.5px]"
                                    , Attr.attribute "aria-hidden" "true"
                                    ]
                                    [ text (String.fromInt (idx + 1)) ]
                                    :: List.map
                                        (\tok ->
                                            span
                                                [ Attr.style "color"
                                                    (case theme of
                                                        Dark ->
                                                            tok.dark

                                                        Light ->
                                                            tok.light
                                                    )
                                                ]
                                                [ text tok.text ]
                                        )
                                        lineTokens
                                )
                        )
                        snippet.lines
                    )
                ]
            ]
        ]



-- LIVE PREVIEWS (MINI + INTERACTIVE)


viewMiniPreview : ViewConfig msg -> Model -> String -> Html msg
viewMiniPreview config model kind =
    case kind of
        "grainient-rail-button" ->
            button
                [ Attr.type_ "button"
                , Attr.class "group/demo relative overflow-hidden inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[var(--code-bg)] font-mono text-[11px] font-medium text-[var(--page-fg)] cursor-pointer"
                ]
                [ span [ Attr.class "pointer-events-none absolute inset-x-0 bottom-0 h-[2px] group-hover/demo:h-full og-grainient opacity-80 group-hover/demo:opacity-100 transition-[height,opacity] duration-250 ease-out" ] []
                , span [ Attr.class "relative z-10 group-hover/demo:text-white light:group-hover/demo:text-[#0c0a14] transition-colors duration-200" ] [ text "Check PRs →" ]
                ]

        "violet-wash-button" ->
            button
                [ Attr.type_ "button"
                , Attr.class "group/demo inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] transition-colors duration-150 cursor-pointer"
                ]
                [ chevronLeftIcon
                , text "Portfolio"
                ]

        "squircle-button" ->
            div [ Attr.class "flex flex-wrap items-center justify-center gap-1.5" ]
                [ button [ Attr.type_ "button", Attr.class "px-2.5 py-1 btn-squircle bg-[var(--page-fg)] text-[var(--page-bg)] hover:bg-[var(--tab-fg)] font-mono text-[10px] font-medium cursor-pointer transition-colors" ] [ text "Invert" ]
                , button [ Attr.type_ "button", Attr.class "px-2.5 py-1 btn-squircle bg-[var(--code-bg)] hover:bg-[var(--tab-bg)] font-mono text-[10px] text-[var(--page-fg)] transition-colors cursor-pointer" ] [ text "Surface" ]
                , button [ Attr.type_ "button", Attr.class "px-2.5 py-1 btn-squircle border border-[var(--page-line)] hover:border-[var(--page-subtle)] font-mono text-[10px] text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors cursor-pointer" ] [ text "Outline" ]
                ]

        "terminal-link" ->
            div [ Attr.class "flex flex-wrap items-center justify-center gap-3 font-mono text-[11px]" ]
                [ button [ Attr.type_ "button", Attr.class "group/t inline-flex items-center gap-1 text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors cursor-pointer" ]
                    [ span [ Attr.class "text-[var(--page-subtle)] group-hover/t:text-[var(--page-fg)]" ] [ text "[" ]
                    , span [] [ text "Keycap" ]
                    , span [ Attr.class "text-[var(--page-subtle)] group-hover/t:text-[var(--page-fg)]" ] [ text "]" ]
                    ]
                , button [ Attr.type_ "button", Attr.class "inline-flex items-center gap-1.5 text-[var(--page-fg)] cursor-pointer" ]
                    [ span [ Attr.class "relative flex size-1.5" ]
                        [ span [ Attr.class "animate-ping absolute inline-flex h-full w-full rounded-full bg-[var(--callout-note-bg)] opacity-75" ] []
                        , span [ Attr.class "relative inline-flex rounded-full size-1.5 bg-[var(--callout-note-bg)]" ] []
                        ]
                    , text "Beacon"
                    ]
                , button [ Attr.type_ "button", Attr.class "inline-flex items-center gap-1 text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors cursor-pointer" ]
                    [ span [ Attr.class "text-[var(--page-subtle)]" ] [ text "/" ]
                    , span [] [ text "slash" ]
                    ]
                ]

        "bayer-button" ->
            div [ Attr.class "flex flex-wrap items-center justify-center gap-2" ]
                [ button [ Attr.type_ "button", Attr.class "cursor-pointer active:scale-[0.98] transition-transform" ] [ bayerBadge "Check PRs →" "var(--tab-bg)" "var(--tab-fg)" ]
                , button [ Attr.type_ "button", Attr.class "cursor-pointer active:scale-[0.98] transition-transform" ] [ bayerBadge "Active ×" "var(--callout-note-bg)" "var(--callout-note-fg)" ]
                ]

        "progressive-blur" ->
            let
                miniRows =
                    [ ( "01", "Elm 0.19.3 opaque types", "var(--callout-note-bg)" )
                    , ( "02", "WebGL2 Grainient shader", "var(--callout-tip-bg)" )
                    , ( "03", "Spring-morphed side wings", "var(--callout-warn-bg)" )
                    , ( "04", "8x8 ordered Bayer dissolve", "var(--callout-note-bg)" )
                    , ( "05", "3-band progressive blur", "var(--callout-tip-bg)" )
                    , ( "06", "Zero-border squircle surfaces", "var(--callout-warn-bg)" )
                    , ( "07", "Shiki dual-theme tokens", "var(--callout-note-bg)" )
                    , ( "08", "Lazy JSON article loader", "var(--callout-tip-bg)" )
                    ]
            in
            div
                [ Attr.attribute "data-local-scroll" "true"
                , Attr.class "relative isolate w-full h-[96px] box-squircle bg-[var(--page-bg)]"
                ]
                [ div [ Attr.class "relative z-0 scroll-clean h-full box-squircle overflow-y-auto overscroll-contain px-3 py-1.5 space-y-1.5 font-mono text-[10.5px] text-[var(--page-muted)]" ]
                    (List.map
                        (\( num, label, dotColor ) ->
                            div [ Attr.class "flex items-center justify-between gap-2" ]
                                [ span [ Attr.class "inline-flex items-center gap-1.5 min-w-0" ]
                                    [ span [ Attr.class "size-1.5 rounded-full shrink-0", Attr.style "background-color" dotColor ] []
                                    , span [ Attr.class "text-[var(--page-fg)] truncate" ] [ text label ]
                                    ]
                                , span [ Attr.class "text-[var(--page-subtle)] tabular-nums shrink-0" ] [ text num ]
                                ]
                        )
                        miniRows
                    )
                , div [ Attr.attribute "aria-hidden" "true", Attr.class "pointer-events-none absolute inset-x-0 top-0 h-9 z-20 rounded-t-[1.15rem] pblur" ] [ Html.node "i" [] [], Html.node "i" [] [] ]
                , div [ Attr.attribute "aria-hidden" "true", Attr.class "pointer-events-none absolute inset-x-0 bottom-0 h-9 z-20 rounded-b-[1.15rem] pblur pblur-bottom" ] [ Html.node "i" [] [], Html.node "i" [] [] ]
                ]

        "bayer-dither-badge" ->
            div [ Attr.class "flex flex-wrap items-center justify-center gap-2" ]
                [ bayerBadge "Building" "var(--callout-note-bg)" "var(--callout-note-fg)"
                , bayerBadge "Go · TUI" "var(--callout-tip-bg)" "var(--callout-tip-fg)"
                , bayerBadge "NixOS" "var(--callout-warn-bg)" "var(--callout-warn-fg)"
                ]

        "sliding-tabs" ->
            div [ Attr.class "relative inline-grid grid-cols-3 w-44 p-0.5 box-squircle bg-[var(--surface-2)] font-mono text-[10px]" ]
                [ div [ Attr.class "pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 w-[calc((100%-4px)/3)] box-squircle bg-[var(--tab-bg)]" ] []
                , span [ Attr.class "relative z-10 py-1 text-center text-[var(--page-fg)] font-medium" ] [ text "All" ]
                , span [ Attr.class "relative z-10 py-1 text-center text-[var(--page-subtle)]" ] [ text "Merged" ]
                , span [ Attr.class "relative z-10 py-1 text-center text-[var(--page-subtle)]" ] [ text "Open" ]
                ]

        "spec-drawers" ->
            div [ Attr.class "w-full max-w-[230px] space-y-1.5" ]
                [ div [ Attr.class "box-squircle bg-[var(--tab-bg)]/75 px-3 py-2 flex items-center justify-between text-[11px]" ]
                    [ span [ Attr.class "font-medium text-[var(--page-fg)]" ] [ text "Twig" ]
                    , bayerBadge "Building" "var(--callout-note-bg)" "var(--callout-note-fg)"
                    ]
                , div [ Attr.class "box-squircle bg-[var(--tab-bg)]/25 px-3 py-1.5 flex items-center justify-between text-[11px] opacity-55" ]
                    [ span [ Attr.class "text-[var(--page-muted)]" ] [ text "mural" ]
                    , span [ Attr.class "font-mono text-[10px] text-[var(--page-subtle)]" ] [ text "+" ]
                    ]
                ]

        "github-contribution-graph" ->
            let
                squircle =
                    "M5 0C8.6 0 10 1.4 10 5C10 8.6 8.6 10 5 10C1.4 10 0 8.6 0 5C0 1.4 1.4 0 5 0Z"

                lvlColor lvl =
                    case config.theme of
                        Dark ->
                            case lvl of
                                1 -> "#362e63"
                                2 -> "#5c4bc4"
                                3 -> "#8b75ff"
                                4 -> "#d4c9ff"
                                _ -> "#18181f"

                        Light ->
                            case lvl of
                                1 -> "#ddd6ff"
                                2 -> "#b19eff"
                                3 -> "#7b62f0"
                                4 -> "#4c35b8"
                                _ -> "#e3e1d9"

                realWeeks =
                    let
                        allW =
                            config.githubGraph.stats.weeks

                        n =
                            List.length allW
                    in
                    List.drop (max 0 (n - 16)) allW

                cells =
                    List.indexedMap
                        (\w week ->
                            Svg.g []
                                (List.indexedMap
                                    (\d day ->
                                        Svg.g [ SvgAttr.transform ("translate(" ++ String.fromInt (w * 13) ++ "," ++ String.fromInt (d * 13) ++ ")") ]
                                            [ path [ SvgAttr.d squircle, SvgAttr.fill (lvlColor day.level) ] [] ]
                                    )
                                    week
                                )
                        )
                        realWeeks

                svgW =
                    max 1 (List.length realWeeks * 13 - 3)
            in
            svg [ SvgAttr.viewBox ("0 0 " ++ String.fromInt svgW ++ " 88"), SvgAttr.class "block w-full max-w-[220px] h-auto overflow-visible" ]
                cells

        "github-pr-drawer" ->
            let
                stats =
                    config.githubGraph.stats

                topPrs =
                    List.take 2 stats.recentPrs
            in
            div [ Attr.class "w-full max-w-[225px] space-y-1.5 font-mono text-[10px]" ]
                (div [ Attr.class "flex items-center justify-between" ]
                    [ bayerBadge ("PRs · " ++ String.fromInt stats.prs) "var(--callout-note-bg)" "var(--callout-note-fg)"
                    , span [ Attr.class "text-[var(--page-subtle)]" ] [ text "All · Merged · Open" ]
                    ]
                    :: List.map
                        (\pr ->
                            div [ Attr.class "box-squircle bg-[var(--surface-2)] px-2.5 py-1.5 flex items-center justify-between gap-2" ]
                                [ span [ Attr.class "text-[var(--page-fg)] truncate" ] [ text pr.title ]
                                , span
                                    [ Attr.class
                                        ("shrink-0 "
                                            ++ (if pr.state == "MERGED" then
                                                    "text-[var(--callout-note-bg)]"

                                                else
                                                    "text-[var(--callout-tip-bg)]"
                                               )
                                        )
                                    ]
                                    [ text (String.toLower pr.state) ]
                                ]
                        )
                        topPrs
                )

        "dither-footer" ->
            div
                [ Attr.class
                    ("w-full h-[76px] box-squircle overflow-hidden "
                        ++ (case config.theme of
                                Dark ->
                                    "bg-[#050505]"

                                Light ->
                                    "bg-[#f5f4f0]"
                           )
                    )
                ]
                [ DitherFooter.viewSized "block w-full h-full object-cover object-bottom pixel-crisp cursor-crosshair select-none touch-none" config.theme model.previewFooter
                    |> Html.map (PreviewFooterMsg >> config.toMsg)
                ]

        "callout-box" ->
            div [ Attr.class "w-full max-w-[230px] box-squircle bg-[var(--surface-2)] p-2.5 space-y-1.5" ]
                [ bayerBadge "Tip" "var(--callout-tip-bg)" "var(--callout-tip-fg)"
                , div [ Attr.class "h-2 w-4/5 rounded-full bg-[var(--tab-bg)]" ] []
                ]

        "code-block" ->
            div [ Attr.class "w-full max-w-[230px] box-squircle bg-[var(--code-bg)] p-2.5 space-y-2 font-mono text-[10px]" ]
                [ div [ Attr.class "flex items-center justify-between" ]
                    [ bayerBadge "main.go" "var(--tab-bg)" "var(--tab-fg)"
                    , span [ Attr.class "text-[var(--page-subtle)]" ] [ morphCopyIcon False ]
                    ]
                , div [ Attr.class "text-[var(--page-muted)]" ] [ text "func main() {}" ]
                ]

        "card-group" ->
            div [ Attr.class "w-full max-w-[230px] grid grid-cols-2 gap-1.5" ]
                [ div [ Attr.class "box-squircle bg-[var(--surface-2)] p-2 space-y-1" ]
                    [ div [ Attr.class "font-mono text-[9px] text-[var(--page-fg)]" ] [ text "FAST" ]
                    , div [ Attr.class "h-1.5 w-3/4 rounded-full bg-[var(--tab-bg)]" ] []
                    ]
                , div [ Attr.class "box-squircle bg-[var(--surface-2)] p-2 space-y-1" ]
                    [ div [ Attr.class "font-mono text-[9px] text-[var(--page-fg)]" ] [ text "PURE" ]
                    , div [ Attr.class "h-1.5 w-3/4 rounded-full bg-[var(--tab-bg)]" ] []
                    ]
                ]

        "bento-grid" ->
            div [ Attr.class "w-full max-w-[220px] grid grid-cols-2 gap-1.5" ]
                [ div [ Attr.class "col-span-2 h-7 box-squircle bg-[var(--surface-3)]" ] []
                , div [ Attr.class "h-7 box-squircle bg-[var(--surface-2)]" ] []
                , div [ Attr.class "h-7 box-squircle bg-[var(--surface-2)]" ] []
                ]

        "stacked-deck" ->
            div [ Attr.class "relative w-full max-w-[210px] pb-3.5" ]
                [ div [ Attr.class "pointer-events-none absolute inset-x-5 top-0 bottom-0 translate-y-3 scale-[0.90] box-squircle bg-[var(--surface-1)]" ] []
                , div [ Attr.class "pointer-events-none absolute inset-x-2.5 top-0 bottom-1.5 translate-y-1.5 scale-[0.95] box-squircle bg-[var(--surface-2)]" ] []
                , div [ Attr.class "relative box-squircle bg-[var(--surface-3)] px-3 py-2.5 flex items-center justify-between gap-2 shadow-[0_8px_18px_rgba(0,0,0,0.32)]" ]
                    [ div [ Attr.class "flex items-center gap-2 min-w-0" ]
                        [ span [ Attr.class "font-display font-medium text-[11px] text-[var(--page-fg)] truncate" ] [ text "Twig" ]
                        , bayerBadge "Go" "var(--callout-note-bg)" "var(--callout-note-fg)"
                        ]
                    , span [ Attr.class "font-mono text-[10px] text-[var(--page-subtle)] shrink-0" ] [ text "01/04" ]
                    ]
                ]

        "stack-matrix" ->
            div [ Attr.class "flex flex-wrap items-center justify-center gap-1.5 font-mono text-[10px]" ]
                [ span [ Attr.class "box-squircle px-2 py-0.5 bg-[var(--callout-note-bg)] text-[var(--callout-note-fg)] font-medium" ] [ text "Go" ]
                , span [ Attr.class "box-squircle px-2 py-0.5 bg-[var(--surface-2)] text-[var(--page-muted)]" ] [ text "NixOS" ]
                , span [ Attr.class "box-squircle px-2 py-0.5 bg-[var(--surface-2)] text-[var(--page-muted)]" ] [ text "Elm" ]
                ]

        _ ->
            div [ Attr.class "w-full max-w-[210px] text-[var(--page-muted)]" ]
                [ ditherDividerSvg 120 "w-full" ]


viewInteractivePreview : ViewConfig msg -> Model -> String -> Html msg
viewInteractivePreview config model kind =
    let
        toMsg =
            config.toMsg

        siteTheme =
            config.theme
    in
    case kind of
        "grainient-rail-button" ->
            let
                railClass =
                    if model.previewBtnOpen then
                        "pointer-events-none absolute inset-x-0 bottom-0 h-full og-grainient opacity-100 transition-[height,opacity] duration-250 ease-out"

                    else
                        "pointer-events-none absolute inset-x-0 bottom-0 h-[2px] group-hover:h-full og-grainient opacity-75 group-hover:opacity-100 transition-[height,opacity] duration-250 ease-out"

                textClass =
                    if model.previewBtnOpen then
                        "text-white light:text-[#0c0a14]"

                    else
                        "text-[var(--page-fg)] hover:text-white light:hover:text-[#0c0a14]"
            in
            div [ Attr.class "flex flex-col items-center gap-3" ]
                [ button
                    [ Attr.type_ "button"
                    , Events.onClick (toMsg TogglePreviewBtn)
                    , Attr.class ("group relative overflow-hidden inline-flex items-center gap-x-1.5 px-3.5 py-2 btn-squircle bg-[var(--code-bg)] font-mono text-xs font-medium transition-colors duration-200 cursor-pointer " ++ textClass ++ " " ++ focusRing)
                    ]
                    [ span [ Attr.class railClass, Attr.attribute "aria-hidden" "true" ] []
                    , span [ Attr.class "relative z-10 inline-flex items-center gap-x-1.5 leading-none" ]
                        [ text
                            (if model.previewBtnOpen then
                                "Close PRs ×"

                             else
                                "Check PRs →"
                            )
                        ]
                    ]
                , span [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)]" ]
                    [ text "Hover to fill · Click to toggle active state" ]
                ]

        "violet-wash-button" ->
            div [ Attr.class "flex flex-wrap items-center gap-3" ]
                [ button
                    [ Attr.type_ "button"
                    , Attr.class ("group inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] transition-colors duration-150 cursor-pointer " ++ focusRing)
                    ]
                    [ chevronLeftIcon, text "Portfolio" ]
                , button
                    [ Attr.type_ "button"
                    , Attr.class ("group inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs font-medium text-[var(--callout-note-bg)] light:text-[#443299] transition-colors duration-150 cursor-pointer " ++ focusRing)
                    ]
                    [ text "All posts →" ]
                ]

        "squircle-button" ->
            let
                specRow title btn =
                    div [ Attr.class "box-squircle bg-[var(--page-bg)] px-3.5 py-2.5 flex items-center justify-between gap-3" ]
                        [ span [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)]" ] [ text title ]
                        , btn
                        ]
            in
            div [ Attr.class "w-full grid grid-cols-1 sm:grid-cols-2 gap-2" ]
                [ specRow "variant=\"ghost\""
                    (button [ Attr.type_ "button", Attr.class "group inline-flex items-center gap-x-1.5 px-2.5 py-1.5 btn-squircle font-mono text-xs text-[var(--page-muted)] hover:text-[var(--page-fg)] hover:bg-[var(--tab-bg)] transition-colors duration-150 cursor-pointer" ]
                        [ chevronLeftIcon, text "Portfolio" ]
                    )
                , specRow "variant=\"surface\""
                    (button [ Attr.type_ "button", Attr.class "inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[var(--code-bg)] hover:bg-[var(--tab-bg)] font-mono text-xs text-[var(--page-fg)] transition-colors duration-150 cursor-pointer" ]
                        [ text "Check PRs →" ]
                    )
                , specRow "variant=\"outline\""
                    (button [ Attr.type_ "button", Attr.class "inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle border border-[var(--page-line)] hover:border-[var(--page-subtle)] font-mono text-xs text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 cursor-pointer" ]
                        [ text "Inspect →" ]
                    )
                , specRow "variant=\"invert\""
                    (button [ Attr.type_ "button", Attr.class "inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[var(--page-fg)] text-[var(--page-bg)] hover:bg-[var(--tab-fg)] font-mono text-xs font-medium transition-colors duration-150 cursor-pointer" ]
                        [ text "Get Started" ]
                    )
                , specRow "variant=\"shimmer\""
                    (button [ Attr.type_ "button", Attr.class "inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[var(--code-bg)] ring-1 ring-[#8b75ff]/45 hover:ring-[#8b75ff] hover:shadow-[0_0_16px_rgba(139,117,255,0.28)] font-mono text-xs text-[var(--page-fg)] transition-all duration-200 cursor-pointer" ]
                        [ text "Shimmer" ]
                    )
                , specRow "variant=\"elevation\""
                    (button [ Attr.type_ "button", Attr.class "inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[var(--code-bg)] hover:bg-[var(--tab-bg)] shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_2px_6px_rgba(0,0,0,0.35)] active:translate-y-px font-mono text-xs text-[var(--page-fg)] transition-all duration-150 cursor-pointer" ]
                        [ text "Elevation" ]
                    )
                ]

        "terminal-link" ->
            let
                specRow title btn =
                    div [ Attr.class "box-squircle bg-[var(--page-bg)] px-3.5 py-2.5 flex items-center justify-between gap-3" ]
                        [ span [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)]" ] [ text title ]
                        , btn
                        ]
            in
            div [ Attr.class "w-full grid grid-cols-1 sm:grid-cols-2 gap-2" ]
                [ specRow "variant=\"keycap\""
                    (button [ Attr.type_ "button", Attr.class "group inline-flex items-center gap-1 font-mono text-xs text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 cursor-pointer" ]
                        [ span [ Attr.class "text-[var(--page-subtle)] group-hover:text-[var(--page-fg)] transition-colors" ] [ text "[" ]
                        , span [] [ text "Portfolio" ]
                        , span [ Attr.class "text-[var(--page-subtle)] group-hover:text-[var(--page-fg)] transition-colors" ] [ text "]" ]
                        ]
                    )
                , specRow "variant=\"underline\""
                    (button [ Attr.type_ "button", Attr.class "group relative inline-flex items-center gap-1 font-mono text-xs text-[var(--page-fg)] cursor-pointer pb-0.5" ]
                        [ span [] [ text "Check PRs →" ]
                        , span [ Attr.class "pointer-events-none absolute inset-x-0 bottom-0 h-px bg-[var(--page-fg)] origin-left scale-x-0 group-hover:scale-x-100 transition-transform duration-200 ease-out" ] []
                        ]
                    )
                , specRow "variant=\"beacon\""
                    (button [ Attr.type_ "button", Attr.class "inline-flex items-center gap-2 font-mono text-xs text-[var(--page-fg)] cursor-pointer" ]
                        [ span [ Attr.class "relative flex size-1.5" ]
                            [ span [ Attr.class "animate-ping absolute inline-flex h-full w-full rounded-full bg-[var(--callout-note-bg)] opacity-75" ] []
                            , span [ Attr.class "relative inline-flex rounded-full size-1.5 bg-[var(--callout-note-bg)]" ] []
                            ]
                        , text "Live Status"
                        ]
                    )
                , specRow "variant=\"slash\""
                    (button [ Attr.type_ "button", Attr.class "group inline-flex items-center gap-1 font-mono text-xs text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 cursor-pointer" ]
                        [ span [ Attr.class "text-[var(--page-subtle)] group-hover:text-[var(--callout-note-bg)] transition-colors" ] [ text "/" ]
                        , span [] [ text "blog" ]
                        ]
                    )
                , specRow "variant=\"chip\""
                    (button [ Attr.type_ "button", Attr.class "group inline-flex items-center gap-1.5 font-mono text-xs text-[var(--page-fg)] cursor-pointer" ]
                        [ span [ Attr.class "inline-flex items-center justify-center size-5 btn-squircle bg-[var(--tab-bg)] transition-transform duration-150 group-hover:-translate-x-0.5" ] [ chevronLeftIcon ]
                        , text "Back"
                        ]
                    )
                ]

        "bayer-button" ->
            div [ Attr.class "flex flex-wrap items-center justify-center gap-3" ]
                [ button [ Attr.type_ "button", Attr.class "cursor-pointer active:scale-[0.98] transition-transform" ] [ bayerBadge "Check PRs →" "var(--tab-bg)" "var(--tab-fg)" ]
                , button [ Attr.type_ "button", Attr.class "cursor-pointer active:scale-[0.98] transition-transform" ] [ bayerBadge "Close PRs ×" "var(--callout-note-bg)" "var(--callout-note-fg)" ]
                , button [ Attr.type_ "button", Attr.class "cursor-pointer active:scale-[0.98] transition-transform" ] [ bayerBadge "Merged" "var(--callout-tip-bg)" "var(--callout-tip-fg)" ]
                , button [ Attr.type_ "button", Attr.class "cursor-pointer active:scale-[0.98] transition-transform" ] [ bayerBadge "Warning" "var(--callout-warn-bg)" "var(--callout-warn-fg)" ]
                ]

        "progressive-blur" ->
            let
                scrollRows =
                    [ ( "01", "Elm 0.19.3 opaque types", "var(--callout-note-bg)" )
                    , ( "02", "WebGL2 Grainient shader", "var(--callout-tip-bg)" )
                    , ( "03", "Spring-morphed side wings", "var(--callout-warn-bg)" )
                    , ( "04", "8x8 ordered Bayer dissolve", "var(--callout-note-bg)" )
                    , ( "05", "3-band progressive blur", "var(--callout-tip-bg)" )
                    , ( "06", "Zero-border squircle surfaces", "var(--callout-warn-bg)" )
                    , ( "07", "Shiki dual-theme tokens", "var(--callout-note-bg)" )
                    , ( "08", "Lazy JSON article loader", "var(--callout-tip-bg)" )
                    , ( "09", "Lenis exponential wheel glide", "var(--callout-warn-bg)" )
                    , ( "10", "Static per-route OG shells", "var(--callout-note-bg)" )
                    ]

                renderList =
                    List.map
                        (\( num, title, dotColor ) ->
                            div [ Attr.class "flex items-center justify-between gap-2.5 py-2 border-b border-[var(--page-line)] last:border-b-0 font-mono text-[11px]" ]
                                [ div [ Attr.class "flex items-center gap-2 min-w-0" ]
                                    [ span [ Attr.class "size-1.5 rounded-full shrink-0", Attr.style "background-color" dotColor ] []
                                    , span [ Attr.class "text-[var(--page-fg)] truncate" ] [ text title ]
                                    ]
                                , span [ Attr.class "text-[10px] text-[var(--page-subtle)] tabular-nums shrink-0" ] [ text num ]
                                ]
                        )
                        scrollRows

                demoBox title subtitle hasTop hasBottom =
                    div [ Attr.class "space-y-1.5" ]
                        [ div [ Attr.class "flex items-baseline justify-between font-mono text-[10px]" ]
                            [ span [ Attr.class "text-[var(--page-fg)] font-medium" ] [ text title ]
                            , span [ Attr.class "text-[var(--page-subtle)]" ] [ text subtitle ]
                            ]
                        , div
                            [ Attr.attribute "data-local-scroll" "true"
                            , Attr.class "relative isolate h-48 box-squircle bg-[var(--page-bg)]"
                            ]
                            [ div [ Attr.class "relative z-0 scroll-clean h-full box-squircle overflow-y-auto overscroll-contain px-3.5 py-1.5" ] renderList
                            , if hasTop then
                                div [ Attr.attribute "aria-hidden" "true", Attr.class "pointer-events-none absolute inset-x-0 top-0 h-14 z-20 rounded-t-[1.15rem] pblur" ] [ Html.node "i" [] [], Html.node "i" [] [] ]

                              else
                                text ""
                            , if hasBottom then
                                div [ Attr.attribute "aria-hidden" "true", Attr.class "pointer-events-none absolute inset-x-0 bottom-0 h-14 z-20 rounded-b-[1.15rem] pblur pblur-bottom" ] [ Html.node "i" [] [], Html.node "i" [] [] ]

                              else
                                text ""
                            ]
                        ]
            in
            div [ Attr.class "w-full space-y-4" ]
                [ div [ Attr.class "grid grid-cols-1 md:grid-cols-3 gap-3" ]
                    [ demoBox "Top Edge" "scroll inside" True False
                    , demoBox "Bottom Edge" "scroll inside" False True
                    , demoBox "Top + Bottom" "scroll inside" True True
                    ]
                , div [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)] text-center" ]
                    [ text "Hover any box above and scroll — wheel input stays capped inside that box" ]
                ]

        "bayer-dither-badge" ->
            div [ Attr.class "flex flex-wrap items-center justify-center gap-2.5" ]
                [ bayerBadge "Building" "var(--callout-note-bg)" "var(--callout-note-fg)"
                , bayerBadge "Go · TUI" "var(--callout-tip-bg)" "var(--callout-tip-fg)"
                , bayerBadge "NixOS" "var(--callout-warn-bg)" "var(--callout-warn-fg)"
                , bayerBadge "Neovim" "var(--tab-bg)" "var(--tab-fg)"
                ]

        "sliding-tabs" ->
            let
                tabBtn idx label =
                    button
                        [ Attr.type_ "button"
                        , Events.onClick (toMsg (SetPreviewTab idx))
                        , Attr.class
                            ("relative z-10 py-1.5 font-mono text-[11px] cursor-pointer transition-colors duration-150 "
                                ++ (if model.previewTab == idx then
                                        "text-[var(--page-fg)] font-medium"

                                    else
                                        "text-[var(--page-subtle)] hover:text-[var(--page-muted)]"
                                   )
                            )
                        ]
                        [ text label ]
            in
            div [ Attr.class "relative inline-grid grid-cols-3 w-64 p-0.5 box-squircle bg-[var(--page-bg)]" ]
                [ div
                    [ Attr.class "pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 w-[calc((100%-4px)/3)] box-squircle bg-[var(--tab-bg)] transition-transform duration-200 ease-out"
                    , Attr.style "transform" ("translate3d(" ++ String.fromInt (model.previewTab * 100) ++ "%, 0, 0)")
                    ]
                    []
                , tabBtn 0 "All"
                , tabBtn 1 "Merged"
                , tabBtn 2 "Open"
                ]

        "github-contribution-graph" ->
            div [ Attr.class "w-full" ]
                [ GithubGraph.view
                    { toMsg = config.onGithubGraphMsg
                    , onTogglePrWing = config.onTogglePrWing
                    , prWingOpen = config.prOpen
                    , prBtnCoverage = config.prCoverage
                    }
                    siteTheme
                    config.githubGraph
                ]

        "github-pr-drawer" ->
            GithubGraph.viewPrPanel { toMsg = config.onGithubGraphMsg } config.githubGraph

        "dither-footer" ->
            let
                effectiveTheme =
                    case model.previewFooterTheme of
                        ThemeFollow ->
                            siteTheme

                        ThemeDark ->
                            Dark

                        ThemeLight ->
                            Light

                heightClass =
                    case model.previewFooterHeight of
                        FooterCompact ->
                            "h-24"

                        FooterStandard ->
                            "h-36"

                        FooterTall ->
                            "h-52"

                bgClass =
                    case effectiveTheme of
                        Dark ->
                            "bg-[#050505]"

                        Light ->
                            "bg-[#f5f4f0]"

                ripplesActive =
                    DitherFooter.activeRippleCount model.previewFooter

                optBtn isOn clickMsg label =
                    button
                        [ Attr.type_ "button"
                        , Events.onClick (toMsg clickMsg)
                        , Attr.class
                            ("px-2 py-0.5 btn-squircle font-mono text-[10.5px] cursor-pointer transition-colors duration-150 "
                                ++ (if isOn then
                                        "bg-[var(--page-fg)] text-[var(--page-bg)] font-medium"

                                    else
                                        "bg-[var(--page-bg)] text-[var(--page-muted)] hover:text-[var(--page-fg)]"
                                   )
                            )
                        ]
                        [ text label ]

                actionBtn clickMsg label =
                    button
                        [ Attr.type_ "button"
                        , Events.onClick (toMsg clickMsg)
                        , Attr.class "px-2 py-0.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-[10.5px] text-[var(--callout-note-bg)] light:text-[#443299] cursor-pointer transition-colors duration-150"
                        ]
                        [ text label ]
            in
            div [ Attr.class "w-full space-y-3" ]
                [ div [ Attr.class "flex flex-wrap items-center justify-between gap-2 font-mono text-[10.5px]" ]
                    [ div [ Attr.class "flex flex-wrap items-center gap-1.5" ]
                        [ optBtn model.previewFooterPlaying TogglePreviewFooterMotion
                            (if model.previewFooterPlaying then
                                "Playing"

                             else
                                "Paused"
                            )
                        , span [ Attr.class "text-[var(--page-subtle)] mx-0.5" ] [ text "·" ]
                        , optBtn (model.previewFooterSpeed == 0.5) (SetPreviewFooterSpeed 0.5) "0.5x"
                        , optBtn (model.previewFooterSpeed == 1.0) (SetPreviewFooterSpeed 1.0) "1x"
                        , optBtn (model.previewFooterSpeed == 2.0) (SetPreviewFooterSpeed 2.0) "2x"
                        , span [ Attr.class "text-[var(--page-subtle)] mx-0.5" ] [ text "·" ]
                        , optBtn (model.previewFooterHeight == FooterCompact) (SetPreviewFooterHeight FooterCompact) "Compact"
                        , optBtn (model.previewFooterHeight == FooterStandard) (SetPreviewFooterHeight FooterStandard) "Standard"
                        , optBtn (model.previewFooterHeight == FooterTall) (SetPreviewFooterHeight FooterTall) "Tall"
                        ]
                    , div [ Attr.class "flex flex-wrap items-center gap-1.5" ]
                        [ optBtn (model.previewFooterTheme == ThemeFollow) (SetPreviewFooterTheme ThemeFollow) "Auto"
                        , optBtn (model.previewFooterTheme == ThemeDark) (SetPreviewFooterTheme ThemeDark) "Dark"
                        , optBtn (model.previewFooterTheme == ThemeLight) (SetPreviewFooterTheme ThemeLight) "Light"
                        , span [ Attr.class "text-[var(--page-subtle)] mx-0.5" ] [ text "·" ]
                        , actionBtn TriggerPreviewFooterRipple
                            (if ripplesActive > 0 then
                                "Ripple (" ++ String.fromInt ripplesActive ++ ")"

                             else
                                "Ripple"
                            )
                        , actionBtn ReplayPreviewFooterIntro "Replay intro"
                        ]
                    ]
                , div [ Attr.class ("box-squircle overflow-hidden transition-[height,background-color] duration-250 " ++ heightClass ++ " " ++ bgClass) ]
                    [ DitherFooter.viewSized "block w-full h-full object-cover object-bottom pixel-crisp cursor-crosshair select-none touch-none" effectiveTheme model.previewFooter
                        |> Html.map (PreviewFooterMsg >> toMsg)
                    ]
                , div [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)] text-center" ]
                    [ text "Move pointer to disturb the wave · Click canvas or Ripple to layer up to 4 concurrent waves" ]
                ]

        "callout-box" ->
            let
                callout =
                    case model.previewCallout of
                        1 ->
                            { label = "Tip", bg = "var(--callout-tip-bg)", fg = "var(--callout-tip-fg)", body = "Prefer opaque custom types in Elm so invalid states cannot be constructed." }

                        2 ->
                            { label = "Warning", bg = "var(--callout-warn-bg)", fg = "var(--callout-warn-fg)", body = "Never animate opacity on a parent wrapper around backdrop-filter layers." }

                        _ ->
                            { label = "Note", bg = "var(--callout-note-bg)", fg = "var(--callout-note-fg)", body = "Blog posts and components are authored in Markdown and highlighted at build time with Shiki." }

                pill idx lbl =
                    button
                        [ Attr.type_ "button"
                        , Events.onClick (toMsg (SetPreviewCallout idx))
                        , Attr.class
                            ("px-2.5 py-1 btn-squircle font-mono text-[10.5px] cursor-pointer transition-colors "
                                ++ (if model.previewCallout == idx then
                                        "bg-[var(--tab-bg)] text-[var(--page-fg)] font-medium"

                                    else
                                        "text-[var(--page-subtle)] hover:text-[var(--page-fg)]"
                                   )
                            )
                        ]
                        [ text lbl ]
            in
            div [ Attr.class "w-full max-w-md space-y-3" ]
                [ div [ Attr.class "flex items-center gap-1" ]
                    [ pill 0 "Note", pill 1 "Tip", pill 2 "Warning" ]
                , aside [ Attr.class "box-squircle bg-[var(--page-bg)] p-4 space-y-2.5" ]
                    [ bayerBadge callout.label callout.bg callout.fg
                    , p [ Attr.class "text-[13.5px] leading-relaxed text-[var(--page-muted)]" ] [ text callout.body ]
                    ]
                ]

        "code-block" ->
            div [ Attr.class "w-full max-w-md box-squircle bg-[var(--code-bg)] overflow-hidden" ]
                [ div [ Attr.class "flex items-center justify-between pl-4 pr-2.5 pt-2.5 pb-1" ]
                    [ bayerBadge "main.go" "var(--tab-bg)" "var(--tab-fg)"
                    , button
                        [ Attr.type_ "button"
                        , Events.onClick (toMsg TogglePreviewCodeCopy)
                        , Attr.attribute "aria-label" "Toggle copy icon preview"
                        , Attr.class
                            ("inline-flex items-center justify-center size-8 btn-squircle transition-colors duration-150 cursor-pointer "
                                ++ (if model.previewCodeCopied then
                                        "text-[var(--page-fg)] bg-[var(--tab-bg)]"

                                    else
                                        "text-[var(--page-subtle)] hover:text-[var(--page-fg)] hover:bg-[var(--tab-bg)]"
                                   )
                            )
                        ]
                        [ morphCopyIcon model.previewCodeCopied ]
                    ]
                , pre [ Attr.class "pt-2 pb-4 px-4 font-mono text-[12.5px] leading-[1.7] text-[var(--page-fg)]" ]
                    [ code [] [ text "package main\n\nfunc main() {\n    println(\"hello from samouly\")\n}" ] ]
                ]

        "card-group" ->
            div [ Attr.class "w-full max-w-md grid grid-cols-1 sm:grid-cols-2 gap-3" ]
                [ div [ Attr.class "p-4 box-squircle bg-[var(--page-bg)] space-y-1.5" ]
                    [ p [ Attr.class "font-mono text-[11px] uppercase tracking-[0.14em] text-[var(--page-fg)]" ] [ text "Declarative" ]
                    , p [ Attr.class "text-[13px] leading-relaxed text-[var(--page-muted)]" ] [ text "Your entire workstation is version-controlled in one flake." ]
                    ]
                , div [ Attr.class "p-4 box-squircle bg-[var(--page-bg)] space-y-1.5" ]
                    [ p [ Attr.class "font-mono text-[11px] uppercase tracking-[0.14em] text-[var(--page-fg)]" ] [ text "Reproducible" ]
                    , p [ Attr.class "text-[13px] leading-relaxed text-[var(--page-muted)]" ] [ text "Identical builds across laptops, CI, and servers." ]
                    ]
                ]

        "bento-grid" ->
            let
                items =
                    [ { cat = 0, name = "Twig", summary = "Live diff viewer for huge working trees", tag = "Building" }
                    , { cat = 1, name = "mural", summary = "Pure Go Wayland wallpaper daemon", tag = "Go · TUI" }
                    , { cat = 2, name = "Samouly Flake", summary = "Declarative NixOS setup", tag = "NixOS" }
                    ]

                shown =
                    case model.previewBentoFilter of
                        1 ->
                            List.filter (\it -> it.cat /= 2) items

                        2 ->
                            List.filter (\it -> it.cat == 2) items

                        _ ->
                            items

                fBtn idx lbl =
                    button
                        [ Attr.type_ "button"
                        , Events.onClick (toMsg (SetPreviewBento idx))
                        , Attr.class
                            ("relative z-10 py-1 font-mono text-[10.5px] cursor-pointer "
                                ++ (if model.previewBentoFilter == idx then
                                        "text-[var(--page-fg)] font-medium"

                                    else
                                        "text-[var(--page-subtle)]"
                                   )
                            )
                        ]
                        [ text lbl ]
            in
            div [ Attr.class "w-full max-w-md space-y-2.5" ]
                [ div [ Attr.class "relative inline-grid grid-cols-3 w-56 p-0.5 box-squircle bg-[var(--page-bg)]" ]
                    [ div
                        [ Attr.class "pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 w-[calc((100%-4px)/3)] box-squircle bg-[var(--tab-bg)] transition-transform duration-200"
                        , Attr.style "transform" ("translate3d(" ++ String.fromInt (model.previewBentoFilter * 100) ++ "%, 0, 0)")
                        ]
                        []
                    , fBtn 0 "All"
                    , fBtn 1 "Go & TUI"
                    , fBtn 2 "Nix"
                    ]
                , div [ Attr.class "grid grid-cols-1 sm:grid-cols-2 gap-2" ]
                    (List.indexedMap
                        (\i it ->
                            div
                                [ Attr.class
                                    ("box-squircle bg-[var(--page-bg)] p-3 space-y-1 "
                                        ++ (if i == 0 && model.previewBentoFilter == 0 then
                                                "sm:col-span-2"

                                            else
                                                ""
                                           )
                                    )
                                ]
                                [ div [ Attr.class "flex items-center justify-between gap-2" ]
                                    [ span [ Attr.class "text-sm font-medium text-[var(--page-fg)]" ] [ text it.name ]
                                    , bayerBadge it.tag "var(--callout-note-bg)" "var(--callout-note-fg)"
                                    ]
                                , p [ Attr.class "text-xs text-[var(--page-muted)]" ] [ text it.summary ]
                                ]
                        )
                        shown
                    )
                ]

        "stacked-deck" ->
            let
                slides =
                    [ { name = "Twig"
                      , repo = "sam0uly/twig"
                      , summary = "Live diff viewer for working trees bigger than your screen."
                      , tag = "Building"
                      , bg = "var(--callout-note-bg)"
                      , fg = "var(--callout-note-fg)"
                      , stack = [ "Go", "Bubble Tea", "Git" ]
                      }
                    , { name = "mural"
                      , repo = "sam0uly/mural"
                      , summary = "Terminal wallpaper manager with a pure Go Wayland daemon."
                      , tag = "Go · TUI"
                      , bg = "var(--callout-tip-bg)"
                      , fg = "var(--callout-tip-fg)"
                      , stack = [ "Go", "Wayland", "Layer Shell" ]
                      }
                    , { name = "Spin"
                      , repo = "sam0uly/spin"
                      , summary = "Language-agnostic project template CLI with interactive prompts."
                      , tag = "CLI"
                      , bg = "var(--callout-warn-bg)"
                      , fg = "var(--callout-warn-fg)"
                      , stack = [ "Go", "CLI", "Templates" ]
                      }
                    , { name = "Samouly Flake"
                      , repo = "sam0uly/samouly-flake"
                      , summary = "Declarative NixOS workstation setup for Hyprland and Niri."
                      , tag = "NixOS"
                      , bg = "var(--callout-note-bg)"
                      , fg = "var(--callout-note-fg)"
                      , stack = [ "Nix", "NixOS", "Niri" ]
                      }
                    ]

                total =
                    List.length slides

                renderCard idx slide =
                    let
                        rel =
                            modBy total (idx - model.previewDeckIdx + total)

                        isExiting =
                            model.previewDeckPrev == Just idx && idx /= model.previewDeckIdx

                        peelClass =
                            if isExiting then
                                if model.previewDeckDir < 0 then
                                    "z-40 deck-peel-right bg-[var(--page-bg)] shadow-[0_14px_34px_rgba(0,0,0,0.42)]"

                                else
                                    "z-40 deck-peel-left bg-[var(--page-bg)] shadow-[0_14px_34px_rgba(0,0,0,0.42)]"

                            else
                                ""

                        pose =
                            case rel of
                                0 ->
                                    { tf = "translate3d(0, 0px, 0) scale(1)"
                                    , op = "1"
                                    , filt = "brightness(1)"
                                    , cls = "z-30 bg-[var(--page-bg)] shadow-[0_14px_34px_rgba(0,0,0,0.42)] light:shadow-[0_12px_28px_rgba(14,14,18,0.12)] cursor-pointer"
                                    , front = True
                                    }

                                1 ->
                                    { tf = "translate3d(0, 14px, 0) scale(0.955)"
                                    , op = "0.92"
                                    , filt = "brightness(0.86)"
                                    , cls = "z-20 bg-[var(--surface-2)] cursor-pointer hover:bg-[var(--surface-3)]"
                                    , front = False
                                    }

                                2 ->
                                    { tf = "translate3d(0, 27px, 0) scale(0.91)"
                                    , op = "0.72"
                                    , filt = "brightness(0.74)"
                                    , cls = "z-10 bg-[var(--surface-1)] cursor-pointer"
                                    , front = False
                                    }

                                _ ->
                                    { tf = "translate3d(0, 34px, 0) scale(0.87)"
                                    , op = "0"
                                    , filt = "brightness(0.68)"
                                    , cls = "z-0 pointer-events-none bg-[var(--surface-1)]"
                                    , front = False
                                    }
                    in
                    div
                        ([ Attr.class
                            ("deck-card absolute inset-x-0 top-0 box-squircle p-5 space-y-3 select-none "
                                ++ (if isExiting then
                                        peelClass

                                    else
                                        pose.cls
                                   )
                            )
                         , Attr.style "transform" pose.tf
                         , Attr.style "opacity" pose.op
                         , Attr.style "filter" pose.filt
                         , Attr.style "transform-origin" "50% 100%"
                         ]
                            ++ (if isExiting then
                                    []

                                else if pose.front then
                                    [ Events.onClick (toMsg (StepPreviewDeck 1)) ]

                                else
                                    [ Events.onClick (toMsg (SetPreviewDeck idx)) ]
                               )
                        )
                        [ div [ Attr.class "flex items-center justify-between gap-3" ]
                            [ span [ Attr.class "font-display font-semibold text-base text-[var(--page-fg)] truncate" ]
                                [ text slide.name ]
                            , bayerBadge slide.tag slide.bg slide.fg
                            ]
                        , p [ Attr.class "text-[13px] leading-relaxed text-[var(--page-muted)] text-pretty min-h-[40px]" ]
                            [ text slide.summary ]
                        , div [ Attr.class "pt-1 flex items-center justify-between gap-2" ]
                            [ div [ Attr.class "flex flex-wrap items-center gap-1.5" ]
                                (List.map
                                    (\tech ->
                                        span [ Attr.class "box-squircle px-2 py-0.5 bg-[var(--surface-2)] font-mono text-[10px] text-[var(--page-muted)]" ]
                                            [ text tech ]
                                    )
                                    slide.stack
                                )
                            , span [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)] shrink-0" ]
                                [ text slide.repo ]
                            ]
                        ]
            in
            div [ Attr.class "w-full max-w-md space-y-5" ]
                [ div [ Attr.class "relative h-[186px]" ]
                    (List.indexedMap renderCard slides)
                , div [ Attr.class "flex items-center justify-between gap-3 pt-1" ]
                    [ div [ Attr.class "flex items-center gap-1.5" ]
                        (List.indexedMap
                            (\idx slide ->
                                let
                                    isActive =
                                        idx == model.previewDeckIdx
                                in
                                button
                                    [ Attr.type_ "button"
                                    , Events.onClick (toMsg (SetPreviewDeck idx))
                                    , Attr.attribute "aria-label" ("Show " ++ slide.name)
                                    , Attr.style "width"
                                        (if isActive then
                                            "28px"

                                         else
                                            "8px"
                                        )
                                    , Attr.class
                                        ("deck-pill h-1.5 rounded-full cursor-pointer "
                                            ++ (if isActive then
                                                    "bg-[var(--callout-note-bg)]"

                                                else
                                                    "bg-[var(--tab-bg)] hover:bg-[var(--page-subtle)]"
                                               )
                                        )
                                    ]
                                    []
                            )
                            slides
                        )
                    , div [ Attr.class "flex items-center gap-2" ]
                        [ span [ Attr.class "font-mono text-[11px] text-[var(--page-subtle)] tabular-nums" ]
                            [ text ("0" ++ String.fromInt (model.previewDeckIdx + 1) ++ " / 0" ++ String.fromInt total) ]
                        , div [ Attr.class "inline-flex items-center gap-1" ]
                            [ button
                                [ Attr.type_ "button"
                                , Events.onClick (toMsg (StepPreviewDeck -1))
                                , Attr.attribute "aria-label" "Previous card"
                                , Attr.class "inline-flex items-center justify-center size-7 btn-squircle bg-[var(--page-bg)] hover:bg-[var(--tab-bg)] font-mono text-xs text-[var(--page-fg)] transition-colors duration-150 cursor-pointer"
                                ]
                                [ text "←" ]
                            , button
                                [ Attr.type_ "button"
                                , Events.onClick (toMsg (StepPreviewDeck 1))
                                , Attr.attribute "aria-label" "Next card"
                                , Attr.class "inline-flex items-center justify-center size-7 btn-squircle bg-[var(--page-bg)] hover:bg-[var(--tab-bg)] font-mono text-xs text-[var(--page-fg)] transition-colors duration-150 cursor-pointer"
                                ]
                                [ text "→" ]
                            ]
                        ]
                    ]
                ]

        "stack-matrix" ->
            let
                techs =
                    [ "Go", "Bubble Tea", "Wayland", "NixOS" ]

                cards =
                    [ ( "Twig", [ "Go", "Bubble Tea" ] )
                    , ( "mural", [ "Go", "Wayland" ] )
                    , ( "Samouly Flake", [ "NixOS" ] )
                    ]
            in
            div [ Attr.class "w-full max-w-md space-y-3" ]
                [ div [ Attr.class "flex flex-wrap gap-1.5" ]
                    (List.map
                        (\t ->
                            let
                                isOn =
                                    model.previewMatrixTech == Just t
                            in
                            button
                                [ Attr.type_ "button"
                                , Events.onClick (toMsg (TogglePreviewMatrix t))
                                , Attr.class
                                    ("box-squircle px-2.5 py-1 font-mono text-[10.5px] cursor-pointer transition-colors "
                                        ++ (if isOn then
                                                "bg-[var(--callout-note-bg)] text-[var(--callout-note-fg)] font-medium"

                                            else
                                                "bg-[var(--page-bg)] text-[var(--page-muted)] hover:text-[var(--page-fg)]"
                                           )
                                    )
                                ]
                                [ text t ]
                        )
                        techs
                    )
                , div [ Attr.class "grid grid-cols-1 sm:grid-cols-3 gap-2" ]
                    (List.map
                        (\( name, stack ) ->
                            let
                                matches =
                                    case model.previewMatrixTech of
                                        Nothing ->
                                            True

                                        Just t ->
                                            List.member t stack
                            in
                            div
                                [ Attr.class
                                    ("box-squircle p-3 transition-colors duration-200 "
                                        ++ (if matches then
                                                "bg-[var(--page-bg)]"

                                            else
                                                "bg-[var(--surface-1)]"
                                           )
                                    )
                                ]
                                [ div
                                    [ Attr.class
                                        ("text-sm font-medium transition-colors duration-200 "
                                            ++ (if matches then
                                                    "text-[var(--page-fg)]"

                                                else
                                                    "text-[var(--page-subtle)]"
                                               )
                                        )
                                    ]
                                    [ text name ]
                                , div [ Attr.class "mt-1 font-mono text-[10px] text-[var(--page-subtle)]" ] [ text (String.join " · " stack) ]
                                ]
                        )
                        cards
                    )
                ]

        "spec-drawers" ->
            let
                demoItems =
                    [ { id = "twig", name = "Twig", summary = "Live diff viewer for working trees", tag = "Building", story = "Streams and virtualizes huge Git diffs in the terminal." }
                    , { id = "mural", name = "mural", summary = "Pure Go Wayland wallpaper daemon", tag = "Go · TUI", story = "Single Go binary speaking Wayland layer-shell directly." }
                    ]
            in
            div
                [ Attr.class "relative w-full max-w-md space-y-1.5"
                , Events.onMouseLeave (toMsg (HoverPreviewDrawer Nothing))
                ]
                (slideBgOverlay "bg-[var(--tab-bg)]/60" model.previewDrawerHover
                    :: List.map
                        (\d ->
                            let
                                isOpen =
                                    model.previewDrawerOpen == Just d.id
                            in
                            div
                                [ Events.on "mouseenter" (boxRectDecoder (not isOpen) (HoverPreviewDrawer >> toMsg))
                                , Attr.class
                                    ("relative z-10 box-squircle transition-[background-color,opacity] duration-200 "
                                        ++ (if isOpen then
                                                "bg-[var(--tab-bg)]/75"

                                            else
                                                "bg-[var(--tab-bg)]/25"
                                           )
                                    )
                                ]
                                [ button
                                    [ Attr.type_ "button"
                                    , Events.onClick (toMsg (TogglePreviewDrawer d.id))
                                    , Attr.class "w-full px-3.5 py-2.5 flex items-center justify-between gap-3 text-left cursor-pointer"
                                    ]
                                    [ div [ Attr.class "flex items-baseline gap-2.5 min-w-0" ]
                                        [ span [ Attr.class "text-[13.5px] font-medium text-[var(--page-fg)] shrink-0" ] [ text d.name ]
                                        , span [ Attr.class "text-[12px] text-[var(--page-muted)] truncate" ] [ text d.summary ]
                                        ]
                                    , div [ Attr.class "flex items-center gap-2 shrink-0" ]
                                        [ bayerBadge d.tag "var(--callout-note-bg)" "var(--callout-note-fg)"
                                        , span [ Attr.class "font-mono text-xs text-[var(--page-subtle)]" ]
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
                                        [ p
                                            [ Attr.class "px-3.5 pb-3 pt-0.5 text-[12.5px] leading-relaxed text-[var(--page-muted)] cursor-pointer"
                                            , Events.onClick (toMsg (TogglePreviewDrawer d.id))
                                            ]
                                            [ text d.story ]
                                        ]
                                    ]
                                ]
                        )
                        demoItems
                )

        _ ->
            div [ Attr.class "w-full max-w-md space-y-4 text-center" ]
                [ div [ Attr.class "text-[var(--page-fg)]/80" ] [ ditherDividerSvg 160 "w-full" ]
                , div [ Attr.class "text-[var(--callout-note-bg)]" ] [ ditherDividerSvg 160 "w-full" ]
                , div [ Attr.class "text-[var(--callout-tip-bg)]" ] [ ditherDividerSvg 160 "w-full" ]
                ]



-- SHARED SVGS & UTILITY BAR


bayerBadge : String -> String -> String -> Html msg
bayerBadge label bgColor fgColor =
    span [ Attr.class "inline-flex items-stretch h-[20px] font-mono text-[10px] tracking-[0.06em] shrink-0" ]
        [ span
            [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none font-medium"
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


viewUtilityBar : ViewConfig msg -> String -> String -> msg -> Html msg
viewUtilityBar config backHref backLabel backMsg =
    div [ Attr.class "pt-4 space-y-3" ]
        [ div
            [ Attr.attribute "role" "separator"
            , Attr.class "flex items-center justify-center text-[var(--page-subtle)]/65"
            ]
            [ ditherDividerSvg 160 "w-full max-w-[24rem] sm:max-w-[32rem]" ]
        , div [ Attr.class "flex flex-wrap items-center justify-between gap-x-4 gap-y-1 font-mono text-[11px] text-[var(--page-subtle)]" ]
            [ div [ Attr.class "flex items-center gap-x-4" ]
                [ a
                    [ Attr.href backHref
                    , onInternalLinkClick backMsg
                    , Attr.class ("group inline-flex items-center gap-1.5 min-h-11 sm:min-h-7 text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 rounded-xs " ++ focusRing)
                    ]
                    [ chevronLeftIcon
                    , span [] [ text backLabel ]
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
                    , Attr.class ("inline-flex items-center min-h-11 sm:min-h-7 text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 cursor-pointer rounded-xs " ++ focusRing)
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
                    , Attr.class ("inline-flex items-center min-h-11 sm:min-h-7 text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors duration-150 cursor-pointer rounded-xs " ++ focusRing)
                    ]
                    [ text
                        (if config.motionPlaying then
                            "Pause"

                         else
                            "Play"
                        )
                    ]
                , span [ Attr.class "tabular-nums" ] [ text ("© " ++ config.currentYear) ]
                ]
            ]
        ]


ditherDividerSvg : Int -> String -> Html msg
ditherDividerSvg totalCols widthClass =
    let
        fadeCols =
            totalCols // 4

        solidWidth =
            totalCols - fadeCols * 2

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
            rect
                [ SvgAttr.x (String.fromInt fadeCols)
                , SvgAttr.y "0"
                , SvgAttr.width (String.fromInt solidWidth)
                , SvgAttr.height "1"
                , SvgAttr.fill "currentColor"
                ]
                []
    in
    svg
        [ SvgAttr.viewBox ("0 0 " ++ String.fromInt totalCols ++ " 2")
        , SvgAttr.preserveAspectRatio "none"
        , SvgAttr.class ("block h-[2px] " ++ widthClass)
        , Attr.attribute "shape-rendering" "crispEdges"
        , Attr.attribute "aria-hidden" "true"
        ]
        (solid :: edges)


morphCopyIcon : Bool -> Html msg
morphCopyIcon isCopied =
    svg
        [ SvgAttr.viewBox "0 0 16 16"
        , SvgAttr.fill "none"
        , SvgAttr.class "size-3.5 shrink-0 overflow-visible"
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        [ Svg.g
            [ Attr.style "transform-origin" "8px 8px"
            , SvgAttr.class
                ("transition-[transform,opacity] duration-200 ease-out "
                    ++ (if isCopied then
                            "scale-75 -rotate-12 opacity-0"

                        else
                            "scale-100 rotate-0 opacity-100"
                       )
                )
            ]
            [ rect
                [ SvgAttr.x "5.5"
                , SvgAttr.y "5.5"
                , SvgAttr.width "7.5"
                , SvgAttr.height "8"
                , SvgAttr.rx "1.5"
                , SvgAttr.stroke "currentColor"
                , SvgAttr.strokeWidth "1.35"
                ]
                []
            , path
                [ SvgAttr.d "M3.5 10.5V3.5C3.5 2.67157 4.17157 2 5 2H10.5"
                , SvgAttr.stroke "currentColor"
                , SvgAttr.strokeWidth "1.35"
                , SvgAttr.strokeLinecap "round"
                ]
                []
            ]
        , path
            [ SvgAttr.d "M3.25 8.5L6.5 11.75L13 4.75"
            , SvgAttr.stroke "currentColor"
            , SvgAttr.strokeWidth "1.6"
            , SvgAttr.strokeLinecap "round"
            , SvgAttr.strokeLinejoin "round"
            , SvgAttr.strokeDasharray "16"
            , SvgAttr.strokeDashoffset
                (if isCopied then
                    "0"

                 else
                    "16"
                )
            , SvgAttr.class
                ("transition-[stroke-dashoffset,opacity] duration-300 ease-out "
                    ++ (if isCopied then
                            "opacity-100 delay-75"

                        else
                            "opacity-0"
                       )
                )
            ]
            []
        ]


chevronLeftIcon : Html msg
chevronLeftIcon =
    svg
        [ SvgAttr.viewBox "0 0 16 16"
        , SvgAttr.fill "none"
        , SvgAttr.class "size-3.5 shrink-0 transition-transform duration-150 group-hover:-translate-x-0.5"
        , Attr.attribute "aria-hidden" "true"
        ]
        [ path
            [ SvgAttr.d "M10 3.5L5.5 8L10 12.5"
            , SvgAttr.stroke "currentColor"
            , SvgAttr.strokeWidth "1.5"
            , SvgAttr.strokeLinecap "round"
            , SvgAttr.strokeLinejoin "round"
            ]
            []
        ]
