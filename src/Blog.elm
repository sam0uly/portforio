module Blog exposing
    ( Block(..)
    , Inline(..)
    , Model
    , Msg
    , Post
    , TocItem
    , clearCopiedCode
    , clearCopiedHeading
    , decodePosts
    , findBySlug
    , init
    , setActiveHeading
    , update
    , viewDesktopTocWing
    , viewIndex
    , viewMobileTocOverlay
    , viewPost
    )

import Html exposing (Html, a, article, blockquote, button, code, del, div, em, h1, h2, h3, h4, h5, h6, input, li, nav, ol, p, pre, section, span, strong, table, tbody, td, text, th, thead, tr, ul)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Lazy as Lazy
import Json.Decode as Decode exposing (Decoder)
import Svg exposing (path, rect, svg)
import Svg.Attributes as SvgAttr
import Theme exposing (Theme(..))
import TocWingMorph


type alias CodeToken =
    { text : String
    , dark : String
    , light : String
    }


type Inline
    = PlainText String
    | Strong String
    | Italic String
    | StrongItalic String
    | Strike String
    | InlineCode String
    | Link String String


type alias CardItem =
    { title : String
    , blocks : List Block
    }


type Block
    = Heading Int String (List Inline)
    | Paragraph (List Inline)
    | Blockquote (List Inline)
    | Callout String (List Block)
    | CardGroup (List CardItem)
    | CodeBlock String String String (List (List CodeToken))
    | ListBlock Bool (List (List Inline))
    | TableBlock (List (List Inline)) (List (List (List Inline)))
    | HorizontalRule


type alias TocItem =
    { id : String
    , text : String
    , level : Int
    }


type alias Post =
    { slug : String
    , title : String
    , summary : String
    , dateIso : String
    , dateLabel : String
    , readTime : String
    , tags : List String
    , toc : List TocItem
    , blocks : List Block
    }


type alias Model =
    { posts : List Post
    , query : String
    , activeTag : Maybe String
    , activeHeading : String
    , tocOpen : Bool
    , copiedCode : Maybe String
    , copiedHeading : Maybe String
    }


type Msg
    = SetQuery String
    | SelectTag (Maybe String)
    | ResetFilters
    | ToggleToc
    | JumpToHeading String
    | CopyCode String
    | CopyHeadingLink String


init : List Post -> Model
init posts =
    { posts = posts
    , query = ""
    , activeTag = Nothing
    , activeHeading = ""
    , tocOpen = False
    , copiedCode = Nothing
    , copiedHeading = Nothing
    }


setActiveHeading : String -> Model -> Model
setActiveHeading headingId model =
    if model.activeHeading == headingId then
        model

    else
        { model | activeHeading = headingId }


clearCopiedCode : Model -> Model
clearCopiedCode model =
    { model | copiedCode = Nothing }


clearCopiedHeading : Model -> Model
clearCopiedHeading model =
    { model | copiedHeading = Nothing }


findBySlug : String -> Model -> Maybe Post
findBySlug slug model =
    List.filter (\post -> post.slug == slug) model.posts
        |> List.head


type alias UpdateEffect =
    { scrollTo : Maybe String
    , copyText : Maybe String
    , copyHeading : Maybe String
    }


noEffect : UpdateEffect
noEffect =
    { scrollTo = Nothing, copyText = Nothing, copyHeading = Nothing }


update : Msg -> Model -> ( Model, UpdateEffect )
update msg model =
    case msg of
        SetQuery nextQuery ->
            ( { model | query = nextQuery }, noEffect )

        SelectTag maybeTag ->
            ( { model
                | activeTag =
                    if model.activeTag == maybeTag then
                        Nothing

                    else
                        maybeTag
              }
            , noEffect
            )

        ResetFilters ->
            ( { model | query = "", activeTag = Nothing }, noEffect )

        ToggleToc ->
            ( { model | tocOpen = not model.tocOpen }, noEffect )

        JumpToHeading headingId ->
            ( { model | activeHeading = headingId, tocOpen = False }
            , { scrollTo = Just headingId, copyText = Nothing, copyHeading = Nothing }
            )

        CopyCode snippet ->
            ( { model | copiedCode = Just snippet }
            , { scrollTo = Nothing, copyText = Just snippet, copyHeading = Nothing }
            )

        CopyHeadingLink headingId ->
            ( { model | copiedHeading = Just headingId }
            , { scrollTo = Just headingId, copyText = Nothing, copyHeading = Just headingId }
            )


decodePosts : Decoder (List Post)
decodePosts =
    Decode.list decodePost


decodePost : Decoder Post
decodePost =
    Decode.map8
        (\slug title summary dateIso dateLabel readTime tags toc ->
            Post slug title summary dateIso dateLabel readTime tags toc
        )
        (Decode.field "slug" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "summary" Decode.string)
        (Decode.field "dateIso" Decode.string)
        (Decode.field "dateLabel" Decode.string)
        (Decode.field "readTime" Decode.string)
        (Decode.field "tags" (Decode.list Decode.string))
        (Decode.field "toc" (Decode.list decodeTocItem))
        |> Decode.andThen
            (\buildPost ->
                Decode.field "blocks" (Decode.list decodeBlock)
                    |> Decode.map buildPost
            )


decodeTocItem : Decoder TocItem
decodeTocItem =
    Decode.map3 TocItem
        (Decode.field "id" Decode.string)
        (Decode.field "text" Decode.string)
        (Decode.field "level" Decode.int)


decodeInline : Decoder Inline
decodeInline =
    Decode.field "kind" Decode.string
        |> Decode.andThen
            (\kind ->
                case kind of
                    "strong" ->
                        Decode.map Strong (Decode.field "text" Decode.string)

                    "italic" ->
                        Decode.map Italic (Decode.field "text" Decode.string)

                    "strongItalic" ->
                        Decode.map StrongItalic (Decode.field "text" Decode.string)

                    "strike" ->
                        Decode.map Strike (Decode.field "text" Decode.string)

                    "code" ->
                        Decode.map InlineCode (Decode.field "text" Decode.string)

                    "link" ->
                        Decode.map2 Link
                            (Decode.field "text" Decode.string)
                            (Decode.field "href" Decode.string)

                    _ ->
                        Decode.map PlainText (Decode.field "text" Decode.string)
            )


decodeCardItem : Decoder CardItem
decodeCardItem =
    Decode.map2 CardItem
        (Decode.field "title" Decode.string)
        (Decode.field "blocks" (Decode.list (Decode.lazy (\_ -> decodeBlock))))


decodeCodeToken : Decoder CodeToken
decodeCodeToken =
    Decode.map3 CodeToken
        (Decode.field "t" Decode.string)
        (Decode.field "d" Decode.string)
        (Decode.field "l" Decode.string)


decodeBlock : Decoder Block
decodeBlock =
    Decode.field "kind" Decode.string
        |> Decode.andThen
            (\kind ->
                case kind of
                    "heading" ->
                        Decode.map3 Heading
                            (Decode.field "level" Decode.int)
                            (Decode.field "id" Decode.string)
                            (Decode.field "inlines" (Decode.list decodeInline))

                    "blockquote" ->
                        Decode.map Blockquote (Decode.field "inlines" (Decode.list decodeInline))

                    "callout" ->
                        Decode.map2 Callout
                            (Decode.field "variant" Decode.string)
                            (Decode.field "blocks" (Decode.list (Decode.lazy (\_ -> decodeBlock))))

                    "cardGroup" ->
                        Decode.map CardGroup (Decode.field "cards" (Decode.list decodeCardItem))

                    "code" ->
                        Decode.map4 CodeBlock
                            (Decode.field "lang" Decode.string)
                            (Decode.field "filename" Decode.string)
                            (Decode.field "code" Decode.string)
                            (Decode.oneOf
                                [ Decode.field "lines" (Decode.list (Decode.list decodeCodeToken))
                                , Decode.succeed []
                                ]
                            )

                    "list" ->
                        Decode.map2 ListBlock
                            (Decode.field "ordered" Decode.bool)
                            (Decode.field "items" (Decode.list (Decode.list decodeInline)))

                    "table" ->
                        Decode.map2 TableBlock
                            (Decode.field "headers" (Decode.list (Decode.list decodeInline)))
                            (Decode.field "rows" (Decode.list (Decode.list (Decode.list decodeInline))))

                    "hr" ->
                        Decode.succeed HorizontalRule

                    _ ->
                        Decode.map Paragraph (Decode.field "inlines" (Decode.list decodeInline))
            )


uniqueTags : List Post -> List String
uniqueTags postList =
    postList
        |> List.concatMap .tags
        |> List.foldl
            (\tag acc ->
                if List.member tag acc then
                    acc

                else
                    acc ++ [ tag ]
            )
            []


matchesPost : String -> Maybe String -> Post -> Bool
matchesPost rawQuery activeTag post =
    let
        tagMatches =
            case activeTag of
                Nothing ->
                    True

                Just tag ->
                    List.member tag post.tags

        trimmed =
            String.trim (String.toLower rawQuery)

        queryMatches =
            if String.isEmpty trimmed then
                True

            else
                let
                    haystack =
                        String.toLower
                            (post.title
                                ++ " "
                                ++ post.summary
                                ++ " "
                                ++ String.join " " post.tags
                            )
                in
                String.contains trimmed haystack
    in
    tagMatches && queryMatches


type alias ViewConfig msg =
    { toMsg : Msg -> msg
    , onBackHome : msg
    , onOpenBlogIndex : msg
    , onOpenPost : String -> msg
    , onToggleTheme : msg
    , onToggleMotion : msg
    , theme : Theme
    , motionPlaying : Bool
    , currentYear : String
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


viewIndex : ViewConfig msg -> Model -> Html msg
viewIndex config model =
    let
        filtered =
            List.filter (matchesPost model.query Nothing) model.posts

        totalCount =
            List.length model.posts

        shownCount =
            List.length filtered

        hasSearch =
            not (String.isEmpty (String.trim model.query))
    in
    div [ Attr.class "flex flex-col pointer-events-auto" ]
        [ viewIndexHeader config
        , viewPostsSection config model filtered shownCount totalCount hasSearch
        , viewUtilityBar config "/" "Back to portfolio" config.onBackHome
        ]


viewIndexHeader : ViewConfig msg -> Html msg
viewIndexHeader config =
    section
        [ Attr.id "blog-header"
        , Attr.attribute "aria-labelledby" "blog-heading"
        , Attr.class "scroll-mt-8 flex flex-col gap-y-3 sm:grid sm:grid-cols-[2.75rem_1fr] sm:gap-x-6 sm:items-start"
        ]
        [ viewVerticalLabel "Blog"
        , div [ Attr.class "min-w-0 sm:pt-1 space-y-2.5" ]
            [ div [ Attr.class "flex items-baseline justify-between gap-x-4" ]
                [ h1
                    [ Attr.id "blog-heading"
                    , Attr.class "font-display font-semibold text-2xl sm:text-[2.125rem] leading-[1.08] tracking-[-0.03em] text-balance text-[var(--page-fg)]"
                    ]
                    [ text "Writing" ]
                , a
                    [ Attr.href "/"
                    , onInternalLinkClick config.onBackHome
                    , Attr.class
                        ("group inline-flex items-center gap-1.5 min-h-11 sm:min-h-8 shrink-0 font-mono text-xs text-[var(--page-muted)] transition-colors duration-150 hover:text-[var(--page-fg)] rounded-xs "
                            ++ focusRing
                        )
                    ]
                    [ chevronLeftIcon
                    , span [] [ text "Home" ]
                    ]
                ]
            , p [ Attr.class "text-[14px] sm:text-[15px] leading-relaxed text-pretty text-[var(--page-muted)]" ]
                [ text "Notes on "
                , span [ Attr.attribute "translate" "no", Attr.class "text-[var(--page-fg)]" ] [ text "Go" ]
                , text ", "
                , span [ Attr.attribute "translate" "no", Attr.class "text-[var(--page-fg)]" ] [ text "Linux" ]
                , text ", "
                , span [ Attr.attribute "translate" "no", Attr.class "text-[var(--page-fg)]" ] [ text "NixOS" ]
                , text ", and terminal tooling."
                ]
            ]
        ]


viewPostsSection : ViewConfig msg -> Model -> List Post -> Int -> Int -> Bool -> Html msg
viewPostsSection config model filtered shownCount totalCount hasSearch =
    section
        [ Attr.id "posts"
        , Attr.attribute "aria-labelledby" "posts-heading"
        , Attr.class "scroll-mt-8 mt-12 sm:mt-16 flex flex-col gap-y-3 sm:grid sm:grid-cols-[2.75rem_1fr] sm:gap-x-6 sm:items-start"
        ]
        [ viewVerticalHeading "posts-heading" "Posts"
        , div [ Attr.class "min-w-0 space-y-5" ]
            [ viewControls config model shownCount totalCount hasSearch
            , if List.isEmpty filtered then
                viewEmptyState config

              else
                ul [ Attr.class "group/posts min-w-0 divide-y divide-[var(--page-line)]" ]
                    (List.map (viewPostRow config) filtered)
            ]
        ]


viewControls : ViewConfig msg -> Model -> Int -> Int -> Bool -> Html msg
viewControls config model shownCount totalCount hasSearch =
    div [ Attr.class "relative flex items-center border-b border-[var(--page-line)] focus-within:border-[var(--page-fg)] transition-colors duration-150" ]
        [ input
            [ Attr.type_ "search"
            , Attr.value model.query
            , Events.onInput (SetQuery >> config.toMsg)
            , Attr.placeholder "Search posts..."
            , Attr.attribute "aria-label" "Search blog posts"
            , Attr.attribute "autocomplete" "off"
            , Attr.attribute "spellcheck" "false"
            , Attr.class "w-full min-h-11 sm:min-h-9 bg-transparent py-1.5 pr-16 text-sm text-[var(--page-fg)] placeholder:text-[var(--page-subtle)] focus:outline-none"
            ]
            []
        , if not (String.isEmpty model.query) then
            button
                [ Attr.type_ "button"
                , Events.onClick (config.toMsg (SetQuery ""))
                , Attr.class
                    ("absolute right-0 inline-flex items-center min-h-11 sm:min-h-8 px-1 font-mono text-[11px] text-[var(--page-subtle)] hover:text-[var(--page-fg)] transition-colors duration-150 rounded-xs "
                        ++ focusRing
                    )
                ]
                [ text "Clear" ]

          else
            span [ Attr.class "pointer-events-none absolute right-0 font-mono text-[11px] text-[var(--page-subtle)] tabular-nums" ]
                [ text (formatCount shownCount totalCount hasSearch) ]
        ]


formatCount : Int -> Int -> Bool -> String
formatCount shown total hasFilters =
    let
        noun =
            if shown == 1 then
                "post"

            else
                "posts"
    in
    if hasFilters then
        String.fromInt shown ++ " of " ++ String.fromInt total

    else
        String.fromInt shown ++ " " ++ noun


viewFilterChip : ViewConfig msg -> String -> Maybe String -> Bool -> Html msg
viewFilterChip config labelText maybeTag isActive =
    button
        [ Attr.type_ "button"
        , Events.onClick (config.toMsg (SelectTag maybeTag))
        , Attr.attribute "aria-pressed"
            (if isActive then
                "true"

             else
                "false"
            )
        , Attr.attribute "translate" "no"
        , Attr.class
            ("group inline-flex items-stretch min-h-8 sm:min-h-7 font-mono text-[11px] transition-opacity duration-150 "
                ++ (if isActive then
                        "opacity-100"

                    else
                        "opacity-55 hover:opacity-100"
                   )
                ++ " "
                ++ focusRing
            )
        ]
        [ span
            [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none"
            , Attr.style "background-color"
                (if isActive then
                    "var(--page-fg)"

                 else
                    "var(--tab-bg)"
                )
            , Attr.style "color"
                (if isActive then
                    "var(--page-bg)"

                 else
                    "var(--tab-fg)"
                )
            ]
            [ text labelText ]
        , span
            [ Attr.class "inline-flex items-stretch"
            , Attr.style "color"
                (if isActive then
                    "var(--page-fg)"

                 else
                    "var(--tab-bg)"
                )
            ]
            [ ditherTailSvg ]
        ]


viewDitherTagButton : ViewConfig msg -> String -> Html msg
viewDitherTagButton config tag =
    button
        [ Attr.type_ "button"
        , Events.onClick (config.toMsg (SelectTag (Just tag)))
        , Attr.attribute "translate" "no"
        , Attr.class
            ("inline-flex items-stretch h-[20px] font-mono text-[10.5px] opacity-75 hover:opacity-100 transition-opacity duration-150 "
                ++ focusRing
            )
        ]
        [ span
            [ Attr.class "inline-flex items-center pl-1.5 pr-1 leading-none"
            , Attr.style "background-color" "var(--tab-bg)"
            , Attr.style "color" "var(--tab-fg)"
            ]
            [ text tag ]
        , span
            [ Attr.class "inline-flex items-stretch"
            , Attr.style "color" "var(--tab-bg)"
            ]
            [ ditherTailSvg ]
        ]


viewDitherTagStatic : String -> Html msg
viewDitherTagStatic tag =
    span
        [ Attr.attribute "translate" "no"
        , Attr.class "inline-flex items-stretch h-[20px] font-mono text-[10.5px]"
        ]
        [ span
            [ Attr.class "inline-flex items-center pl-1.5 pr-1 leading-none"
            , Attr.style "background-color" "var(--tab-bg)"
            , Attr.style "color" "var(--tab-fg)"
            ]
            [ text tag ]
        , span
            [ Attr.class "inline-flex items-stretch"
            , Attr.style "color" "var(--tab-bg)"
            ]
            [ ditherTailSvg ]
        ]


viewPostRow : ViewConfig msg -> Post -> Html msg
viewPostRow config post =
    li [ Attr.class "min-w-0 py-4 first:pt-1 transition-opacity duration-150 group-hover/posts:opacity-45 hover:!opacity-100 focus-within:!opacity-100" ]
        [ article [ Attr.class "space-y-2" ]
            [ a
                [ Attr.href ("/blog/" ++ post.slug)
                , onInternalLinkClick (config.onOpenPost post.slug)
                , Attr.class ("group block space-y-1.5 rounded-xs " ++ focusRing)
                ]
                [ div [ Attr.class "flex flex-col sm:flex-row sm:items-baseline sm:justify-between gap-x-4 gap-y-0.5" ]
                    [ h3 [ Attr.class "text-[15px] font-medium leading-snug text-[var(--page-fg)] text-pretty group-hover:underline decoration-current/30 underline-offset-4" ]
                        [ text post.title ]
                    , div [ Attr.class "shrink-0 flex items-center gap-x-2 font-mono text-[11px] text-[var(--page-subtle)] tabular-nums" ]
                        [ span [] [ text post.dateLabel ]
                        , span [ Attr.attribute "aria-hidden" "true" ] [ text "·" ]
                        , span [] [ text post.readTime ]
                        ]
                    ]
                , p [ Attr.class "text-[13.5px] leading-relaxed text-[var(--page-muted)] text-pretty" ]
                    [ text post.summary ]
                ]
            , div [ Attr.class "flex flex-wrap items-center gap-x-2 gap-y-1.5 pt-0.5" ]
                (List.map viewDitherTagStatic post.tags)
            ]
        ]


viewEmptyState : ViewConfig msg -> Html msg
viewEmptyState config =
    div [ Attr.class "py-8 space-y-2.5 border-t border-[var(--page-line)]" ]
        [ p [ Attr.class "text-sm text-[var(--page-muted)]" ]
            [ text "No posts match that search." ]
        , button
            [ Attr.type_ "button"
            , Events.onClick (config.toMsg ResetFilters)
            , Attr.class
                ("inline-flex items-center min-h-11 sm:min-h-8 font-mono text-xs text-[var(--page-fg)] underline decoration-current/30 underline-offset-4 hover:decoration-current transition-colors duration-150 rounded-xs "
                    ++ focusRing
                )
            ]
            [ text "Clear search" ]
        ]


viewPost : ViewConfig msg -> Model -> String -> Html msg
viewPost config model slug =
    case findBySlug slug model of
        Nothing ->
            div [ Attr.class "flex flex-col pointer-events-auto" ]
                [ section [ Attr.class "py-8 space-y-4" ]
                    [ h1 [ Attr.class "font-display font-semibold text-2xl text-[var(--page-fg)]" ]
                        [ text "Post not found" ]
                    , p [ Attr.class "text-sm text-[var(--page-muted)]" ]
                        [ text "That article does not exist or was moved." ]
                    , a
                        [ Attr.href "/blog"
                        , onInternalLinkClick config.onOpenBlogIndex
                        , Attr.class
                            ("group inline-flex items-center gap-1.5 min-h-11 font-mono text-xs text-[var(--page-fg)] "
                                ++ focusRing
                            )
                        ]
                        [ chevronLeftIcon
                        , span [] [ text "Back to writing" ]
                        ]
                    ]
                ]

        Just post ->
            let
                ( prevPost, nextPost ) =
                    adjacentPosts slug model.posts
            in
            div [ Attr.class "flex flex-col pointer-events-auto pt-10 xl:pt-0" ]
                [ viewPostHeader config post
                , Lazy.lazy5 viewArticleBody config.toMsg config.theme model.copiedCode model.copiedHeading post.blocks
                , viewAdjacentNav config prevPost nextPost
                , viewUtilityBar config "/blog" "All posts" config.onOpenBlogIndex
                ]


adjacentPosts : String -> List Post -> ( Maybe Post, Maybe Post )
adjacentPosts slug postList =
    let
        go prev rest =
            case rest of
                [] ->
                    ( Nothing, Nothing )

                current :: tail ->
                    if current.slug == slug then
                        ( prev, List.head tail )

                    else
                        go (Just current) tail
    in
    go Nothing postList


viewPostHeader : ViewConfig msg -> Post -> Html msg
viewPostHeader config post =
    section
        [ Attr.id "post-header"
        , Attr.attribute "aria-labelledby" "post-heading"
        , Attr.class "scroll-mt-8 space-y-3"
        ]
        [ div [ Attr.class "flex items-center justify-between gap-x-4" ]
            [ a
                [ Attr.href "/blog"
                , onInternalLinkClick config.onOpenBlogIndex
                , Attr.class
                    ("group inline-flex items-center gap-1.5 min-h-11 sm:min-h-8 font-mono text-xs text-[var(--page-muted)] transition-colors duration-150 hover:text-[var(--page-fg)] rounded-xs "
                        ++ focusRing
                    )
                ]
                [ chevronLeftIcon
                , span [] [ text "Writing" ]
                ]
            , div [ Attr.class "flex items-center gap-x-2 font-mono text-[11px] text-[var(--page-subtle)] tabular-nums" ]
                [ span [] [ text post.dateLabel ]
                , span [ Attr.attribute "aria-hidden" "true" ] [ text "·" ]
                , span [] [ text post.readTime ]
                ]
            ]
        , h1
            [ Attr.id "post-heading"
            , Attr.class "font-display font-semibold text-2xl sm:text-[2rem] leading-[1.12] tracking-[-0.03em] text-balance text-[var(--page-fg)]"
            ]
            [ text post.title ]
        , p [ Attr.class "text-[14.5px] leading-relaxed text-pretty text-[var(--page-muted)]" ]
            [ text post.summary ]
        , div [ Attr.class "flex flex-wrap items-center gap-x-2 gap-y-1.5 pt-1" ]
            (List.map viewDitherTagStatic post.tags)
        , div
            [ Attr.attribute "role" "separator"
            , Attr.class "pt-5 pb-1 flex items-center justify-center text-[var(--page-subtle)]/65"
            ]
            [ ditherHeaderDividerSvg ]
        ]


viewDesktopTocWing : ViewConfig msg -> Float -> List (Html.Attribute msg) -> Html msg -> Model -> Maybe String -> Html msg
viewDesktopTocWing config morphProgress tintStyle overlayHtml model maybeSlug =
    let
        maybePost =
            maybeSlug |> Maybe.andThen (\slug -> findBySlug slug model)

        hasToc =
            maybePost |> Maybe.map (.toc >> List.isEmpty >> not) |> Maybe.withDefault False

        e =
            if hasToc then
                clamp 0.0 1.08 morphProgress

            else
                0.0

        isVisible =
            e > 0.002

        isInteractive =
            e > 0.7

        contentAlpha =
            clamp 0.0 1.0 ((e - 0.55) / 0.42)

        slidePx =
            (1.0 - contentAlpha) * 10.0

        clipStyle =
            case TocWingMorph.wingClipPath e of
                Just clipVal ->
                    [ Attr.style "clip-path" clipVal ]

                Nothing ->
                    []

        pathD =
            TocWingMorph.wingPath e
    in
    if not isVisible then
        Html.text ""

    else
        div
            ([ Attr.id "desktop-toc-wing"
             , Attr.attribute "data-grainient-shield" "true"
             , Attr.attribute "aria-label" "Table of contents"
             , Attr.attribute "aria-hidden"
                (if isInteractive then
                    "false"

                 else
                    "true"
                )
             , Attr.class
                ("hidden xl:flex flex-col absolute right-full top-1/2 -translate-y-1/2 h-[24rem] w-[216px] z-[5] text-[var(--page-bg)] select-text "
                    ++ (if isInteractive then
                            "pointer-events-auto"

                        else
                            "pointer-events-none"
                       )
                )
             ]
                ++ tintStyle
            )
            [ svg
                [ SvgAttr.viewBox "0 0 216 432"
                , SvgAttr.class "pointer-events-none select-none absolute left-0 -top-6 w-[216px] h-[432px] overflow-visible z-0 [filter:drop-shadow(-8px_10px_20px_var(--wing-shadow-color))]"
                , Attr.attribute "aria-hidden" "true"
                , Attr.attribute "focusable" "false"
                ]
                [ path
                    [ SvgAttr.d pathD
                    , SvgAttr.fill "currentColor"
                    ]
                    []
                ]
            , div
                ([ Attr.id "toc-wing-inner"
                 , Attr.class "relative z-10 isolate flex-1 min-h-0 flex flex-col toc-wing-squircle"
                 , Attr.style "opacity" (String.fromFloat contentAlpha)
                 , Attr.style "transform" ("translate3d(" ++ String.fromFloat slidePx ++ "px, 0, 0)")
                 ]
                    ++ clipStyle
                )
                [ case maybePost of
                    Nothing ->
                        Html.text ""

                    Just post ->
                        let
                            activeId =
                                if String.isEmpty model.activeHeading then
                                    post.toc |> List.head |> Maybe.map .id |> Maybe.withDefault ""

                                else
                                    model.activeHeading

                            total =
                                List.length post.toc

                            activeIdx =
                                post.toc
                                    |> List.indexedMap Tuple.pair
                                    |> List.filter (\( _, item ) -> item.id == activeId)
                                    |> List.head
                                    |> Maybe.map (Tuple.first >> (+) 1)
                                    |> Maybe.withDefault 1
                        in
                        div [ Attr.class "flex-1 min-h-0 flex flex-col px-4 pt-4 pb-3 text-[var(--page-fg)]" ]
                            [ div [ Attr.class "flex items-center justify-between gap-x-2 mb-1.5 shrink-0" ]
                                [ span [ Attr.class "inline-flex items-stretch h-[18px] font-mono text-[9.5px] uppercase tracking-[0.14em]" ]
                                    [ span
                                        [ Attr.class "inline-flex items-center pl-1.5 pr-1 leading-none"
                                        , Attr.style "background-color" "var(--tab-bg)"
                                        , Attr.style "color" "var(--tab-fg)"
                                        ]
                                        [ text "TOC" ]
                                    , span
                                        [ Attr.class "inline-flex items-stretch"
                                        , Attr.style "color" "var(--tab-bg)"
                                        ]
                                        [ ditherTailSvg ]
                                    ]
                                , span [ Attr.class "font-mono text-[10px] text-[var(--page-subtle)] tabular-nums" ]
                                    [ text (String.fromInt activeIdx ++ "/" ++ String.fromInt total) ]
                                ]
                            , div [ Attr.class "relative flex-1 min-h-0" ]
                                [ nav
                                    [ Attr.id "desktop-toc-nav"
                                    , Attr.class "relative z-0 h-full overflow-y-hidden py-9 space-y-0.5 pr-1"
                                    ]
                                    (List.map (viewWingTocItem config activeId) post.toc)
                                , div
                                    ([ Attr.class "pointer-events-none select-none absolute inset-x-0 top-0 h-9 z-20 pblur" ]
                                        ++ tintStyle
                                    )
                                    [ Html.node "i" [] [], Html.node "i" [] [] ]
                                , div
                                    ([ Attr.class "pointer-events-none select-none absolute inset-x-0 bottom-0 h-9 z-20 pblur pblur-bottom" ]
                                        ++ tintStyle
                                    )
                                    [ Html.node "i" [] [], Html.node "i" [] [] ]
                                ]
                            ]
                , if e > 0.995 then
                    overlayHtml

                  else
                    Html.text ""
                ]
            ]


viewWingTocItem : ViewConfig msg -> String -> TocItem -> Html msg
viewWingTocItem config activeId item =
    let
        isActive =
            item.id == activeId

        isSub =
            item.level >= 3

        indentClass =
            if item.level >= 5 then
                "pl-4 text-[10px]"

            else if item.level == 4 then
                "pl-3 text-[10.5px]"

            else if item.level == 3 then
                "pl-1.5 text-[11px]"

            else
                "text-[11.5px]"
    in
    button
        [ Attr.type_ "button"
        , Attr.attribute "data-toc-id" item.id
        , Events.onClick (config.toMsg (JumpToHeading item.id))
        , Attr.class
            ("group/toc flex items-start gap-2 w-full text-left py-1 leading-snug transition-colors duration-150 rounded-xs "
                ++ (if isActive then
                        "text-[var(--page-fg)] font-medium"

                    else
                        "text-[var(--page-subtle)] hover:text-[var(--page-fg)]"
                   )
                ++ " "
                ++ focusRing
            )
        ]
        [ span [ Attr.class "shrink-0 w-2.5 flex items-center justify-center pt-[4px]" ]
            [ tocRailPixel isActive isSub ]
        , span [ Attr.class ("min-w-0 flex-1 " ++ indentClass) ]
            [ text item.text ]
        ]


viewMobileTocOverlay : ViewConfig msg -> List (Html.Attribute msg) -> Model -> String -> Html msg
viewMobileTocOverlay config tintStyle model slug =
    case findBySlug slug model of
        Nothing ->
            Html.text ""

        Just post ->
            if List.isEmpty post.toc then
                Html.text ""

            else
                let
                    activeId =
                        if String.isEmpty model.activeHeading then
                            post.toc |> List.head |> Maybe.map .id |> Maybe.withDefault ""

                        else
                            model.activeHeading

                    total =
                        List.length post.toc

                    indexed =
                        List.indexedMap Tuple.pair post.toc

                    activeEntry =
                        indexed
                            |> List.filter (\( _, item ) -> item.id == activeId)
                            |> List.head
                            |> Maybe.withDefault
                                ( 0
                                , post.toc
                                    |> List.head
                                    |> Maybe.withDefault { id = "", text = "Contents", level = 2 }
                                )

                    activeIndex =
                        Tuple.first activeEntry + 1

                    activeTitle =
                        (Tuple.second activeEntry).text
                in
                div
                    [ Attr.class
                        ("xl:hidden absolute inset-x-0 top-0 z-25 pl-5 pr-7 sm:px-10 pt-2 "
                            ++ (if model.tocOpen then
                                    "pb-3"

                                else
                                    ""
                               )
                        )
                    ]
                    [ if model.tocOpen then
                        div
                            ([ Attr.class "pointer-events-none select-none absolute inset-x-0 top-0 -bottom-8 z-0 sheet-squircle-shape pblur pblur-toc-open" ]
                                ++ tintStyle
                            )
                            [ Html.node "i" [] [], Html.node "i" [] [] ]

                      else
                        div
                            ([ Attr.class "pointer-events-none select-none absolute inset-x-0 top-0 -bottom-7 z-0 sheet-squircle-shape pblur" ]
                                ++ tintStyle
                            )
                            [ Html.node "i" [] [], Html.node "i" [] [] ]
                    , button
                        [ Attr.id "mobile-toc-toggle"
                        , Attr.type_ "button"
                        , Events.onClick (config.toMsg ToggleToc)
                        , Attr.attribute "aria-expanded"
                            (if model.tocOpen then
                                "true"

                             else
                                "false"
                            )
                        , Attr.class
                            ("relative z-10 group w-full flex items-center justify-between gap-x-3 py-2 min-h-11 sm:min-h-10 text-left rounded-xs "
                                ++ focusRing
                            )
                        ]
                        [ div [ Attr.class "flex items-center gap-x-2.5 min-w-0" ]
                            [ span [ Attr.class "shrink-0 inline-flex items-stretch h-[19px] font-mono text-[9.5px] uppercase tracking-[0.14em]" ]
                                [ span
                                    [ Attr.class "inline-flex items-center pl-1.5 pr-1 leading-none"
                                    , Attr.style "background-color" "var(--tab-bg)"
                                    , Attr.style "color" "var(--tab-fg)"
                                    ]
                                    [ text "TOC" ]
                                , span
                                    [ Attr.class "inline-flex items-stretch"
                                    , Attr.style "color" "var(--tab-bg)"
                                    ]
                                    [ ditherTailSvg ]
                                ]
                            , span [ Attr.class "truncate text-[13px] font-medium text-[var(--page-fg)]" ]
                                [ text activeTitle ]
                            ]
                        , div [ Attr.class "shrink-0 flex items-center gap-x-2 text-[var(--page-subtle)] group-hover:text-[var(--page-fg)] transition-colors duration-150" ]
                            [ span [ Attr.class "font-mono text-[11px] tabular-nums" ]
                                [ text (String.fromInt activeIndex ++ "/" ++ String.fromInt total) ]
                            , chevronDownIcon model.tocOpen
                            ]
                        ]
                    , if model.tocOpen then
                        div [ Attr.class "relative z-10" ]
                            [ nav
                                [ Attr.id "mobile-toc-nav"
                                , Attr.attribute "aria-label" "Table of contents"
                                , Attr.class "max-h-[30dvh] overflow-y-auto scroll-clean py-2 pb-4 toc-nav-fade"
                                ]
                                [ div [ Attr.class "grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-0.5" ]
                                    (List.map (viewWingTocItem config activeId) post.toc)
                                ]
                            ]

                      else
                        Html.text ""
                    ]


viewArticleBody : (Msg -> msg) -> Theme -> Maybe String -> Maybe String -> List Block -> Html msg
viewArticleBody toMsg theme copiedCode copiedHeading blocks =
    article
        [ Attr.id "article-body"
        , Attr.class "mt-8 sm:mt-9 min-w-0 space-y-4 text-[14.5px] sm:text-[15px] leading-[1.72] text-[var(--page-muted)]"
        ]
        (List.map (viewBlock toMsg theme copiedCode copiedHeading) blocks)


viewHeadingAnchor : (Msg -> msg) -> Maybe String -> String -> List Inline -> Html msg
viewHeadingAnchor toMsg copiedHeading id inlines =
    let
        isCopied =
            copiedHeading == Just id
    in
    a
        [ Attr.href ("#" ++ id)
        , onInternalLinkClick (toMsg (CopyHeadingLink id))
        , Attr.title
            (if isCopied then
                "Link copied"

             else
                "Copy link to section"
            )
        , Attr.class ("group/heading inline-flex items-baseline gap-2 rounded-xs transition-colors duration-150 " ++ focusRing)
        ]
        [ span [] (List.map viewInline inlines)
        , span
            [ Attr.attribute "aria-hidden" "true"
            , Attr.class
                ("shrink-0 font-mono text-[0.72em] font-normal select-none transition-opacity duration-150 "
                    ++ (if isCopied then
                            "text-[var(--page-fg)] opacity-100"

                        else
                            "text-[var(--page-subtle)] opacity-0 group-hover/heading:opacity-80 group-focus-visible/heading:opacity-100"
                       )
                )
            ]
            [ text
                (if isCopied then
                    "copied"

                 else
                    "#"
                )
            ]
        ]


viewBlock : (Msg -> msg) -> Theme -> Maybe String -> Maybe String -> Block -> Html msg
viewBlock toMsg theme copiedCode copiedHeading block =
    case block of
        Heading level id inlines ->
            let
                headingContent =
                    [ viewHeadingAnchor toMsg copiedHeading id inlines ]
            in
            if level <= 2 then
                h2
                    [ Attr.id id
                    , Attr.class "scroll-mt-8 pt-6 first:pt-0 font-display font-semibold text-lg sm:text-[1.3rem] leading-snug tracking-[-0.02em] text-[var(--page-fg)] text-balance"
                    ]
                    headingContent

            else if level == 3 then
                h3
                    [ Attr.id id
                    , Attr.class "scroll-mt-8 pt-4 font-display font-semibold text-[15.5px] sm:text-base leading-snug tracking-[-0.015em] text-[var(--page-fg)] text-balance"
                    ]
                    headingContent

            else if level == 4 then
                h4
                    [ Attr.id id
                    , Attr.class "scroll-mt-8 pt-3 font-display font-medium text-[14.5px] leading-snug text-[var(--page-fg)]/90 text-balance"
                    ]
                    headingContent

            else if level == 5 then
                h5
                    [ Attr.id id
                    , Attr.class "scroll-mt-8 pt-2.5 font-display font-medium text-[13.5px] leading-snug text-[var(--page-fg)]/85 text-balance"
                    ]
                    headingContent

            else
                h6
                    [ Attr.id id
                    , Attr.class "scroll-mt-8 pt-2 font-display font-medium text-[13px] leading-snug text-[var(--page-muted)] text-balance"
                    ]
                    headingContent

        Paragraph inlines ->
            p [ Attr.class "text-pretty break-words" ]
                (List.map viewInline inlines)

        Blockquote inlines ->
            blockquote [ Attr.class "pl-4 py-0.5 border-l-2 border-[var(--page-line)] text-[var(--page-fg)]/85 italic text-pretty" ]
                (List.map viewInline inlines)

        Callout variant blocks ->
            let
                ( label, badgeBg, badgeFg ) =
                    case String.toLower variant of
                        "warning" ->
                            ( "Warning", "var(--callout-warn-bg)", "var(--callout-warn-fg)" )

                        "tip" ->
                            ( "Tip", "var(--callout-tip-bg)", "var(--callout-tip-fg)" )

                        _ ->
                            ( "Note", "var(--callout-note-bg)", "var(--callout-note-fg)" )
            in
            div [ Attr.class "my-5 box-squircle bg-[var(--tab-bg)]/55 px-4 py-3.5 sm:px-5 sm:py-4 space-y-2" ]
                (span [ Attr.class "inline-flex items-stretch h-[20px] font-mono text-[9.5px] font-medium uppercase tracking-[0.16em]" ]
                    [ span
                        [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none"
                        , Attr.style "background-color" badgeBg
                        , Attr.style "color" badgeFg
                        ]
                        [ text label ]
                    , span
                        [ Attr.class "inline-flex items-stretch"
                        , Attr.style "color" badgeBg
                        ]
                        [ ditherTailSvg ]
                    ]
                    :: List.map (viewBlock toMsg theme copiedCode copiedHeading) blocks
                )

        CardGroup cards ->
            let
                gridCols =
                    if List.length cards > 1 then
                        "grid grid-cols-1 sm:grid-cols-2 gap-3"

                    else
                        "grid grid-cols-1"
            in
            div [ Attr.class ("my-5 " ++ gridCols) ]
                (List.map (viewCard toMsg theme copiedCode copiedHeading) cards)

        CodeBlock lang filename snippet tokenLines ->
            let
                isCopied =
                    copiedCode == Just snippet

                lineCount =
                    List.length tokenLines

                isCompact =
                    String.isEmpty filename && lineCount <= 2

                showLineNums =
                    lineCount >= 6

                headerTitle =
                    if not (String.isEmpty filename) then
                        filename

                    else if not (String.isEmpty lang) then
                        lang

                    else
                        "code"
            in
            if isCompact then
                div [ Attr.class "group/code relative my-4 box-squircle bg-[var(--code-bg)] overflow-hidden" ]
                    [ pre [ Attr.class "py-3.5 pl-4 pr-12 overflow-x-auto scroll-clean font-mono text-[13px] leading-[1.65] text-[var(--page-fg)]" ]
                        [ code [ Attr.attribute "translate" "no", Attr.class "block min-w-max" ]
                            (if List.isEmpty tokenLines then
                                [ text snippet ]

                             else
                                List.indexedMap (viewCodeLine theme False) tokenLines
                            )
                        ]
                    , button
                        [ Attr.type_ "button"
                        , Events.onClick (toMsg (CopyCode snippet))
                        , Attr.attribute "aria-label"
                            (if isCopied then
                                "Copied"

                             else
                                "Copy code"
                            )
                        , Attr.class
                            ("absolute right-2.5 top-2.5 inline-flex items-center justify-center size-8 btn-squircle transition-colors duration-150 "
                                ++ (if isCopied then
                                        "text-[var(--page-fg)] bg-[var(--tab-bg)]"

                                    else
                                        "text-[var(--page-subtle)] hover:text-[var(--page-fg)] hover:bg-[var(--tab-bg)]/80"
                                   )
                                ++ " "
                                ++ focusRing
                            )
                        ]
                        [ morphCopyIcon isCopied ]
                    ]

            else
                div [ Attr.class "my-5 box-squircle bg-[var(--code-bg)] overflow-hidden" ]
                    [ div [ Attr.class "flex items-center justify-between gap-x-3 pl-4 pr-2.5 pt-2.5 pb-1" ]
                        [ span [ Attr.attribute "translate" "no", Attr.class "inline-flex items-stretch h-[19px] font-mono text-[10px]" ]
                            [ span
                                [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none"
                                , Attr.style "background-color" "var(--tab-bg)"
                                , Attr.style "color" "var(--tab-fg)"
                                ]
                                [ text headerTitle ]
                            , span
                                [ Attr.class "inline-flex items-stretch"
                                , Attr.style "color" "var(--tab-bg)"
                                ]
                                [ ditherTailSvg ]
                            ]
                        , button
                            [ Attr.type_ "button"
                            , Events.onClick (toMsg (CopyCode snippet))
                            , Attr.attribute "aria-label"
                                (if isCopied then
                                    "Copied"

                                 else
                                    "Copy code"
                                )
                            , Attr.class
                                ("inline-flex items-center justify-center size-8 btn-squircle transition-colors duration-150 "
                                    ++ (if isCopied then
                                            "text-[var(--page-fg)] bg-[var(--tab-bg)]"

                                        else
                                            "text-[var(--page-subtle)] hover:text-[var(--page-fg)] hover:bg-[var(--tab-bg)]/80"
                                       )
                                    ++ " "
                                    ++ focusRing
                                )
                            ]
                            [ morphCopyIcon isCopied ]
                        ]
                    , pre [ Attr.class "pt-2 pb-4 px-4 overflow-x-auto scroll-clean font-mono text-[13px] leading-[1.7] text-[var(--page-fg)]" ]
                        [ code [ Attr.attribute "translate" "no", Attr.class "block min-w-max" ]
                            (if List.isEmpty tokenLines then
                                [ text snippet ]

                             else
                                List.indexedMap (viewCodeLine theme showLineNums) tokenLines
                            )
                        ]
                    ]

        ListBlock ordered items ->
            let
                tag =
                    if ordered then
                        ol

                    else
                        ul

                listClass =
                    if ordered then
                        "list-decimal pl-5 space-y-1.5 marker:text-[var(--page-subtle)] marker:font-mono marker:text-xs"

                    else
                        "list-disc pl-5 space-y-1.5 marker:text-[var(--page-subtle)]"
            in
            tag [ Attr.class listClass ]
                (List.map (\inlines -> li [ Attr.class "pl-1 text-pretty" ] (List.map viewInline inlines)) items)

        TableBlock headers rows ->
            div [ Attr.class "my-4 overflow-x-auto" ]
                [ table [ Attr.class "w-full text-left border-collapse text-[13.5px]" ]
                    [ thead [ Attr.class "border-b border-[var(--page-line)]" ]
                        [ tr []
                            (List.map
                                (\cell ->
                                    th [ Attr.class "py-2 pr-4 font-mono text-[11px] uppercase tracking-[0.12em] text-[var(--page-subtle)] font-medium" ]
                                        (List.map viewInline cell)
                                )
                                headers
                            )
                        ]
                    , tbody [ Attr.class "divide-y divide-[var(--page-line)]" ]
                        (List.map
                            (\row ->
                                tr []
                                    (List.map
                                        (\cell ->
                                            td [ Attr.class "py-2 pr-4 align-top text-[var(--page-muted)]" ]
                                                (List.map viewInline cell)
                                        )
                                        row
                                    )
                            )
                            rows
                        )
                    ]
                ]

        HorizontalRule ->
            div
                [ Attr.attribute "role" "separator"
                , Attr.class "my-8 flex items-center justify-center text-[var(--page-subtle)]/65"
                ]
                [ ditherDividerSvg ]


viewCard : (Msg -> msg) -> Theme -> Maybe String -> Maybe String -> CardItem -> Html msg
viewCard toMsg theme copiedCode copiedHeading card =
    div [ Attr.class "p-4 box-squircle bg-[var(--tab-bg)]/55 space-y-2 text-[13.5px] leading-relaxed" ]
        (if String.isEmpty card.title then
            List.map (viewBlock toMsg theme copiedCode copiedHeading) card.blocks

         else
            p [ Attr.class "font-mono text-[11px] uppercase tracking-[0.14em] text-[var(--page-fg)]" ]
                [ text card.title ]
                :: List.map (viewBlock toMsg theme copiedCode copiedHeading) card.blocks
        )


viewInline : Inline -> Html msg
viewInline inline =
    case inline of
        PlainText str ->
            text str

        Strong str ->
            strong [ Attr.class "font-medium text-[var(--page-fg)]" ] [ text str ]

        Italic str ->
            em [ Attr.class "italic" ] [ text str ]

        StrongItalic str ->
            strong [ Attr.class "font-medium italic text-[var(--page-fg)]" ] [ text str ]

        Strike str ->
            del [ Attr.class "line-through opacity-60" ] [ text str ]

        InlineCode str ->
            code [ Attr.attribute "translate" "no", Attr.class "px-1.5 py-0.5 rounded-xs bg-[var(--tab-bg)] font-mono text-[0.86em] text-[var(--page-fg)]" ]
                [ text str ]

        Link label href ->
            a
                [ Attr.href href
                , Attr.target "_blank"
                , Attr.rel "noopener noreferrer"
                , Attr.class
                    ("text-[var(--page-fg)] underline decoration-current/35 underline-offset-4 hover:decoration-current transition-[color,text-decoration-color] duration-150 rounded-xs "
                        ++ focusRing
                    )
                ]
                [ text label ]


viewAdjacentNav : ViewConfig msg -> Maybe Post -> Maybe Post -> Html msg
viewAdjacentNav config prevPost nextPost =
    if prevPost == Nothing && nextPost == Nothing then
        Html.text ""

    else
        div [ Attr.class "mt-10 space-y-5" ]
            [ div
                [ Attr.attribute "role" "separator"
                , Attr.class "flex items-center justify-center text-[var(--page-subtle)]/65"
                ]
                [ ditherHeaderDividerSvg ]
            , div [ Attr.class "grid grid-cols-1 sm:grid-cols-2 gap-4" ]
                [ case prevPost of
                    Just prev ->
                        a
                            [ Attr.href ("/blog/" ++ prev.slug)
                            , onInternalLinkClick (config.onOpenPost prev.slug)
                            , Attr.class ("group flex flex-col items-start gap-1 rounded-xs " ++ focusRing)
                            ]
                            [ span [ Attr.class "inline-flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-[0.16em] text-[var(--page-subtle)] group-hover:text-[var(--page-fg)] transition-colors duration-150" ]
                                [ chevronLeftIcon
                                , span [] [ text "Newer" ]
                                ]
                            , span [ Attr.class "text-sm font-medium text-[var(--page-muted)] group-hover:text-[var(--page-fg)] transition-colors duration-150 text-pretty" ]
                                [ text prev.title ]
                            ]

                    Nothing ->
                        div [] []
                , case nextPost of
                    Just next ->
                        a
                            [ Attr.href ("/blog/" ++ next.slug)
                            , onInternalLinkClick (config.onOpenPost next.slug)
                            , Attr.class ("group flex flex-col items-start sm:items-end sm:text-right gap-1 rounded-xs " ++ focusRing)
                            ]
                            [ span [ Attr.class "inline-flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-[0.16em] text-[var(--page-subtle)] group-hover:text-[var(--page-fg)] transition-colors duration-150" ]
                                [ span [] [ text "Older" ]
                                , chevronRightIcon
                                ]
                            , span [ Attr.class "text-sm font-medium text-[var(--page-muted)] group-hover:text-[var(--page-fg)] transition-colors duration-150 text-pretty" ]
                                [ text next.title ]
                            ]

                    Nothing ->
                        div [] []
                ]
            ]


viewUtilityBar : ViewConfig msg -> String -> String -> msg -> Html msg
viewUtilityBar config backHref backLabel backMsg =
    div [ Attr.class "mt-10 sm:mt-12 space-y-3" ]
        [ div
            [ Attr.attribute "role" "separator"
            , Attr.class "flex items-center justify-center text-[var(--page-subtle)]/65"
            ]
            [ ditherHeaderDividerSvg ]
        , div [ Attr.class "flex flex-wrap items-center justify-between gap-x-4 gap-y-1 font-mono text-[11px] text-[var(--page-subtle)]" ]
            [ a
                [ Attr.href backHref
                , onInternalLinkClick backMsg
                , Attr.class
                    ("group inline-flex items-center gap-1.5 min-h-11 sm:min-h-7 text-[var(--page-muted)] transition-colors duration-150 hover:text-[var(--page-fg)] rounded-xs "
                        ++ focusRing
                    )
                ]
                [ chevronLeftIcon
                , span [] [ text backLabel ]
                ]
            , div [ Attr.class "flex items-center gap-x-4" ]
                [ button
                    [ Attr.type_ "button"
                    , Events.onClick config.onToggleTheme
                    , Attr.attribute "aria-label"
                        (case config.theme of
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
                    , Attr.attribute "aria-pressed"
                        (if config.motionPlaying then
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
                        (if config.motionPlaying then
                            "Pause"

                         else
                            "Play"
                        )
                    ]
                , span [ Attr.class "tabular-nums" ]
                    [ text config.currentYear ]
                ]
            ]
        ]


viewCodeLine : Theme -> Bool -> Int -> List CodeToken -> Html msg
viewCodeLine theme showLineNums index tokens =
    div [ Attr.class "flex items-baseline" ]
        [ if showLineNums then
            span [ Attr.class "select-none shrink-0 w-7 pr-3 text-right text-[11px] text-[var(--page-subtle)]/50 tabular-nums" ]
                [ text (String.fromInt (index + 1)) ]

          else
            Html.text ""
        , span [ Attr.class "whitespace-pre" ]
            (if List.isEmpty tokens then
                [ text " " ]

             else
                List.map (viewCodeToken theme) tokens
            )
        ]


viewCodeToken : Theme -> CodeToken -> Html msg
viewCodeToken theme token =
    let
        color =
            case theme of
                Dark ->
                    token.dark

                Light ->
                    token.light
    in
    if String.isEmpty color then
        text token.text

    else
        span [ Attr.style "color" color ] [ text token.text ]


chevronDownIcon : Bool -> Html msg
chevronDownIcon isOpen =
    svg
        [ SvgAttr.viewBox "0 0 16 16"
        , SvgAttr.fill "none"
        , SvgAttr.class
            ("size-3.5 shrink-0 transition-transform duration-200 ease-out "
                ++ (if isOpen then
                        "rotate-180"

                    else
                        "rotate-0"
                   )
            )
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        [ path
            [ SvgAttr.d "M3.75 6.25L8 10.5L12.25 6.25"
            , SvgAttr.stroke "currentColor"
            , SvgAttr.strokeWidth "1.5"
            , SvgAttr.strokeLinecap "round"
            , SvgAttr.strokeLinejoin "round"
            ]
            []
        ]


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
                ("transition-[transform,opacity] duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] "
                    ++ (if isCopied then
                            "scale-75 -rotate-12 opacity-0"

                        else
                            "scale-100 rotate-0 opacity-100"
                       )
                )
            ]
            [ rect
                [ SvgAttr.x "5.75"
                , SvgAttr.y "5.75"
                , SvgAttr.width "7.5"
                , SvgAttr.height "7.5"
                , SvgAttr.rx "1.75"
                , SvgAttr.stroke "currentColor"
                , SvgAttr.strokeWidth "1.45"
                ]
                []
            , path
                [ SvgAttr.d "M3.75 10.25H3.5A1.75 1.75 0 0 1 1.75 8.5V3.5A1.75 1.75 0 0 1 3.5 1.75h5A1.75 1.75 0 0 1 10.25 3.5v.25"
                , SvgAttr.stroke "currentColor"
                , SvgAttr.strokeWidth "1.45"
                , SvgAttr.strokeLinecap "round"
                ]
                []
            ]
        , path
            [ SvgAttr.d "M3.5 8.6L6.4 11.4L12.5 4.6"
            , SvgAttr.stroke "currentColor"
            , SvgAttr.strokeWidth "1.7"
            , SvgAttr.strokeLinecap "round"
            , SvgAttr.strokeLinejoin "round"
            , SvgAttr.strokeDasharray "16"
            , SvgAttr.strokeDashoffset
                (if isCopied then
                    "0"

                 else
                    "16"
                )
            , Attr.style "transform-origin" "8px 8px"
            , SvgAttr.class
                ("transition-[stroke-dashoffset,transform,opacity] duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] "
                    ++ (if isCopied then
                            "scale-100 rotate-0 opacity-100"

                        else
                            "scale-75 rotate-12 opacity-0"
                       )
                )
            ]
            []
        ]


tocRailPixel : Bool -> Bool -> Html msg
tocRailPixel isActive isSub =
    if isActive then
        svg
            [ SvgAttr.viewBox "0 0 8 8"
            , SvgAttr.class "size-2 text-[var(--page-fg)] transition-transform duration-200 scale-100"
            , Attr.attribute "shape-rendering" "crispEdges"
            , Attr.attribute "aria-hidden" "true"
            ]
            [ rect [ SvgAttr.x "2", SvgAttr.y "0", SvgAttr.width "4", SvgAttr.height "2", SvgAttr.fill "currentColor" ] []
            , rect [ SvgAttr.x "0", SvgAttr.y "2", SvgAttr.width "8", SvgAttr.height "4", SvgAttr.fill "currentColor" ] []
            , rect [ SvgAttr.x "2", SvgAttr.y "6", SvgAttr.width "4", SvgAttr.height "2", SvgAttr.fill "currentColor" ] []
            ]

    else if isSub then
        svg
            [ SvgAttr.viewBox "0 0 8 8"
            , SvgAttr.class "size-2 text-[var(--page-subtle)]/45 group-hover/toc:text-[var(--page-fg)] transition-colors duration-150"
            , Attr.attribute "shape-rendering" "crispEdges"
            , Attr.attribute "aria-hidden" "true"
            ]
            [ rect [ SvgAttr.x "3", SvgAttr.y "3", SvgAttr.width "2", SvgAttr.height "2", SvgAttr.fill "currentColor" ] [] ]

    else
        svg
            [ SvgAttr.viewBox "0 0 8 8"
            , SvgAttr.class "size-2 text-[var(--page-subtle)]/65 group-hover/toc:text-[var(--page-fg)] transition-colors duration-150"
            , Attr.attribute "shape-rendering" "crispEdges"
            , Attr.attribute "aria-hidden" "true"
            ]
            [ rect [ SvgAttr.x "2", SvgAttr.y "2", SvgAttr.width "2", SvgAttr.height "2", SvgAttr.fill "currentColor" ] []
            , rect [ SvgAttr.x "4", SvgAttr.y "4", SvgAttr.width "2", SvgAttr.height "2", SvgAttr.fill "currentColor" ] []
            ]


bayerDividerRects : Int -> List (Html msg)
bayerDividerRects totalCols =
    let
        fadeCols =
            totalCols // 4

        solidStart =
            fadeCols

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
                Just
                    (rect
                        [ SvgAttr.x (String.fromInt x)
                        , SvgAttr.y (String.fromInt y)
                        , SvgAttr.width "1"
                        , SvgAttr.height "1"
                        , SvgAttr.fill "currentColor"
                        ]
                        []
                    )

            else
                Nothing

        leftEdge =
            List.range 1 2
                |> List.concatMap
                    (\y ->
                        List.range 0 (fadeCols - 1)
                            |> List.filterMap (\x -> edgeCell x y)
                    )

        rightEdge =
            List.range 1 2
                |> List.concatMap
                    (\y ->
                        List.range (totalCols - fadeCols) (totalCols - 1)
                            |> List.filterMap (\x -> edgeCell x y)
                    )

        solidMid =
            [ rect
                [ SvgAttr.x (String.fromInt solidStart)
                , SvgAttr.y "1"
                , SvgAttr.width (String.fromInt solidWidth)
                , SvgAttr.height "2"
                , SvgAttr.fill "currentColor"
                ]
                []
            ]
    in
    leftEdge ++ solidMid ++ rightEdge


ditherDividerSvg : Html msg
ditherDividerSvg =
    svg
        [ SvgAttr.viewBox "0 0 80 4"
        , SvgAttr.preserveAspectRatio "none"
        , SvgAttr.class "block w-48 sm:w-64 h-[3px]"
        , Attr.attribute "shape-rendering" "crispEdges"
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        (bayerDividerRects 80)


ditherHeaderDividerSvg : Html msg
ditherHeaderDividerSvg =
    svg
        [ SvgAttr.viewBox "0 0 160 4"
        , SvgAttr.preserveAspectRatio "none"
        , SvgAttr.class "block w-full max-w-[24rem] sm:max-w-[32rem] h-[3px]"
        , Attr.attribute "shape-rendering" "crispEdges"
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        (bayerDividerRects 160)


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


chevronRightIcon : Html msg
chevronRightIcon =
    svg
        [ SvgAttr.viewBox "0 0 16 16"
        , SvgAttr.fill "none"
        , SvgAttr.class "size-3.5 shrink-0 transition-transform duration-200 ease-out group-hover:translate-x-0.5"
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        [ path
            [ SvgAttr.d "M6.25 3.75L10.5 8L6.25 12.25"
            , SvgAttr.stroke "currentColor"
            , SvgAttr.strokeWidth "1.5"
            , SvgAttr.strokeLinecap "round"
            , SvgAttr.strokeLinejoin "round"
            ]
            []
        ]


viewVerticalLabel : String -> Html msg
viewVerticalLabel labelText =
    div [ Attr.class "flex flex-col items-start shrink-0" ]
        [ div
            [ Attr.class "inline-flex sm:flex-col items-stretch h-5 sm:h-auto sm:w-7"
            , Attr.style "color" "var(--tab-bg)"
            ]
            [ div [ Attr.class "hidden sm:block" ] [ ditherCapSvg ]
            , span
                [ Attr.class "font-mono text-[10px] tracking-[0.14em] px-2 sm:px-0 sm:py-2.5 flex items-center justify-center leading-none"
                , Attr.style "background-color" "var(--tab-bg)"
                , Attr.style "color" "var(--tab-fg)"
                ]
                [ span [ Attr.class "sm:vertical-heading" ] [ text labelText ] ]
            , div [ Attr.class "sm:hidden flex items-stretch" ] [ ditherTailSvg ]
            ]
        ]


viewVerticalHeading : String -> String -> Html msg
viewVerticalHeading headingId labelText =
    div [ Attr.class "flex flex-col items-start shrink-0" ]
        [ div
            [ Attr.class "inline-flex sm:flex-col items-stretch h-5 sm:h-auto sm:w-7"
            , Attr.style "color" "var(--tab-bg)"
            ]
            [ div [ Attr.class "hidden sm:block" ] [ ditherCapSvg ]
            , h2
                [ Attr.id headingId
                , Attr.class "font-mono text-[10px] tracking-[0.14em] px-2 sm:px-0 sm:py-2.5 flex items-center justify-center leading-none"
                , Attr.style "background-color" "var(--tab-bg)"
                , Attr.style "color" "var(--tab-fg)"
                ]
                [ span [ Attr.class "sm:vertical-heading" ] [ text labelText ] ]
            , div [ Attr.class "sm:hidden flex items-stretch" ] [ ditherTailSvg ]
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
