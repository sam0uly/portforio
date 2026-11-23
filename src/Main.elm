port module Main exposing (main)

import BayerMask
import Blog
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


port pushRoute : String -> Cmd msg


port resetScroll : () -> Cmd msg


port scrollToHeading : String -> Cmd msg


port copyHeadingUrl : String -> Cmd msg


port routeChanged : (String -> msg) -> Sub msg


port activeHeadingChanged : (String -> msg) -> Sub msg


port footerVisibilityChanged : (Bool -> msg) -> Sub msg


type Route
    = Home
    | BlogIndex
    | BlogPost String


type alias Flags =
    { currentYear : String
    , diveDepthMeters : String
    , prefersReducedMotion : Bool
    , initialRoute : String
    , blogPosts : List Blog.Post
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
    , route : Route
    , pendingRoute : Maybe Route
    , lastPostSlug : Maybe String
    , theme : Theme
    , motionPlaying : Bool
    , bayerMask : BayerMask.Model
    , ditherTop : DitherTop.Model
    , ditherFooter : DitherFooter.Model
    , footerVisible : Bool
    , blog : Blog.Model
    , copyState : CopyState
    , liveAnnouncement : String
    }


type Msg
    = TopDitherMsg DitherTop.Msg
    | FooterDitherMsg DitherFooter.Msg
    | BlogMsg Blog.Msg
    | AnimationTick Float
    | ToggleTheme
    | ToggleMotion
    | ReducedMotionChanged Bool
    | Navigate Route
    | ExternalRouteChanged String
    | ActiveHeadingChanged String
    | FooterVisibilityChanged Bool
    | CopyEmail
    | GotClipboardResult Bool
    | ResetCopyState
    | ResetCodeCopy
    | ResetHeadingCopy


routeFromString : String -> Route
routeFromString raw =
    let
        cleaned =
            raw
                |> String.trim
                |> (\s ->
                        if String.startsWith "/" s then
                            String.dropLeft 1 s

                        else
                            s
                   )
                |> (\s ->
                        if String.endsWith "/" s then
                            String.dropRight 1 s

                        else
                            s
                   )
    in
    if cleaned == "blog" then
        BlogIndex

    else if String.startsWith "blog/" cleaned then
        let
            slug =
                String.dropLeft 5 cleaned
        in
        if String.isEmpty slug then
            BlogIndex

        else
            BlogPost slug

    else
        Home


routeToString : Route -> String
routeToString route =
    case route of
        Home ->
            "/"

        BlogIndex ->
            "/blog"

        BlogPost slug ->
            "/blog/" ++ slug


emailAddress : String
emailAddress =
    "alasamouly@gmail.com"


defaultFlags : Flags
defaultFlags =
    { currentYear = "2026"
    , diveDepthMeters = "35"
    , prefersReducedMotion = False
    , initialRoute = "/"
    , blogPosts = []
    }


decodeFlags : Decoder Flags
decodeFlags =
    Decode.map5 Flags
        (Decode.field "currentYear" Decode.string)
        (Decode.field "diveDepthMeters" Decode.string)
        (Decode.field "prefersReducedMotion" Decode.bool)
        (Decode.oneOf
            [ Decode.field "initialRoute" Decode.string
            , Decode.succeed "/"
            ]
        )
        (Decode.oneOf
            [ Decode.field "blogPosts" Blog.decodePosts
            , Decode.succeed []
            ]
        )


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

        initialRoute =
            routeFromString decodedFlags.initialRoute

        initialSlug =
            case initialRoute of
                BlogPost slug ->
                    Just slug

                _ ->
                    Nothing
    in
    ( { flags = decodedFlags
      , route = initialRoute
      , pendingRoute = Nothing
      , lastPostSlug = initialSlug
      , theme = Dark
      , motionPlaying = not decodedFlags.prefersReducedMotion
      , bayerMask = BayerMask.init decodedFlags.prefersReducedMotion
      , ditherTop = topModel
      , ditherFooter = DitherFooter.init decodedFlags.prefersReducedMotion
      , footerVisible = True
      , blog = Blog.init decodedFlags.blogPosts
      , copyState = CopyIdle
      , liveAnnouncement = ""
      }
    , Cmd.map TopDitherMsg topCmd
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        onHome =
            model.route == Home

        needsFrames =
            BayerMask.isAnimating model.bayerMask
                || (onHome && (model.motionPlaying || DitherTop.isAnimating model.ditherTop))
                || (model.footerVisible && DitherFooter.isAnimating model.ditherFooter)
    in
    Sub.batch
        [ clipboardResult GotClipboardResult
        , reducedMotionChanged ReducedMotionChanged
        , routeChanged ExternalRouteChanged
        , activeHeadingChanged ActiveHeadingChanged
        , footerVisibilityChanged FooterVisibilityChanged
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

        BlogMsg subMsg ->
            let
                ( nextBlog, effect ) =
                    Blog.update subMsg model.blog

                cmds =
                    List.filterMap identity
                        [ Maybe.map scrollToHeading effect.scrollTo
                        , Maybe.map copyToClipboard effect.copyText
                        , Maybe.map (\_ -> Process.sleep 1800 |> Task.perform (\_ -> ResetCodeCopy)) effect.copyText
                        , Maybe.map copyHeadingUrl effect.copyHeading
                        , Maybe.map (\_ -> Process.sleep 1800 |> Task.perform (\_ -> ResetHeadingCopy)) effect.copyHeading
                        ]
            in
            ( { model | blog = nextBlog }
            , Cmd.batch cmds
            )

        ResetCodeCopy ->
            ( { model | blog = Blog.clearCopiedCode model.blog }
            , Cmd.none
            )

        ResetHeadingCopy ->
            ( { model | blog = Blog.clearCopiedHeading model.blog }
            , Cmd.none
            )

        ActiveHeadingChanged headingId ->
            ( { model | blog = Blog.setActiveHeading headingId model.blog }
            , Cmd.none
            )

        FooterVisibilityChanged isVisible ->
            ( { model | footerVisible = isVisible }, Cmd.none )

        AnimationTick dtMs ->
            let
                ( nextMask, maskEvent ) =
                    BayerMask.tick dtMs model.bayerMask

                ( ( nextTheme, nextRoute, nextPending ), maskCmd ) =
                    case maskEvent of
                        BayerMask.SwapTheme target ->
                            ( ( target, model.route, model.pendingRoute )
                            , setTheme (themeToString target)
                            )

                        BayerMask.SwapRoute ->
                            ( ( model.theme, Maybe.withDefault model.route model.pendingRoute, Nothing )
                            , resetScroll ()
                            )

                        BayerMask.NoEvent ->
                            ( ( model.theme, model.route, model.pendingRoute )
                            , Cmd.none
                            )

                nextLastSlug =
                    case nextRoute of
                        BlogPost slug ->
                            Just slug

                        _ ->
                            model.lastPostSlug
            in
            ( { model
                | theme = nextTheme
                , route = nextRoute
                , pendingRoute = nextPending
                , lastPostSlug = nextLastSlug
                , bayerMask = nextMask
                , ditherTop =
                    if model.route == Home then
                        DitherTop.tick model.motionPlaying dtMs model.ditherTop

                    else
                        model.ditherTop
                , ditherFooter =
                    if model.footerVisible then
                        DitherFooter.tick model.motionPlaying dtMs model.ditherFooter

                    else
                        model.ditherFooter
              }
            , maskCmd
            )

        Navigate target ->
            startNavigation True target model

        ExternalRouteChanged rawRoute ->
            startNavigation False (routeFromString rawRoute) model

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


startNavigation : Bool -> Route -> Model -> ( Model, Cmd Msg )
startNavigation shouldPush target model =
    let
        alreadyThere =
            model.route == target && model.pendingRoute == Nothing

        alreadyHeadingThere =
            model.pendingRoute == Just target
    in
    if alreadyThere || alreadyHeadingThere then
        ( model, Cmd.none )

    else
        let
            announcement =
                case target of
                    Home ->
                        "Navigated to portfolio."

                    BlogIndex ->
                        "Navigated to blog."

                    BlogPost _ ->
                        "Opened blog post."

            pushCmd =
                if shouldPush then
                    pushRoute (routeToString target)

                else
                    Cmd.none

            ( nextMask, immediate ) =
                BayerMask.startRouteSwitch model.flags.prefersReducedMotion model.bayerMask
        in
        if immediate then
            ( { model
                | route = target
                , pendingRoute = Nothing
                , lastPostSlug =
                    case target of
                        BlogPost slug ->
                            Just slug

                        _ ->
                            model.lastPostSlug
                , bayerMask = nextMask
                , liveAnnouncement = announcement
              }
            , Cmd.batch [ pushCmd, resetScroll () ]
            )

        else
            ( { model
                | pendingRoute = Just target
                , bayerMask = nextMask
                , liveAnnouncement = announcement
              }
            , pushCmd
            )


focusRing : String
focusRing =
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--page-fg)] focus-visible:ring-offset-4 focus-visible:ring-offset-[var(--page-bg)]"


onInternalLinkClick : Msg -> Html.Attribute Msg
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


makeBlogConfig : Theme -> Bool -> String -> { toMsg : Blog.Msg -> Msg, onBackHome : Msg, onOpenBlogIndex : Msg, onOpenPost : String -> Msg, onToggleTheme : Msg, onToggleMotion : Msg, theme : Theme, motionPlaying : Bool, currentYear : String }
makeBlogConfig theme motionPlaying currentYear =
    { toMsg = BlogMsg
    , onBackHome = Navigate Home
    , onOpenBlogIndex = Navigate BlogIndex
    , onOpenPost = \slug -> Navigate (BlogPost slug)
    , onToggleTheme = ToggleTheme
    , onToggleMotion = ToggleMotion
    , theme = theme
    , motionPlaying = motionPlaying
    , currentYear = currentYear
    }


viewBlogIndexLazy : Theme -> Bool -> String -> Blog.Model -> Html Msg
viewBlogIndexLazy theme motionPlaying currentYear blog =
    Blog.viewIndex (makeBlogConfig theme motionPlaying currentYear) blog


viewBlogPostLazy : Theme -> Bool -> String -> Blog.Model -> String -> Html Msg
viewBlogPostLazy theme motionPlaying currentYear blog slug =
    Blog.viewPost (makeBlogConfig theme motionPlaying currentYear) blog slug


viewDesktopTocWingLazy : Bool -> Theme -> BayerMask.Model -> Blog.Model -> Maybe String -> Html Msg
viewDesktopTocWingLazy wingOpen theme bayerMask blog wingSlug =
    Blog.viewDesktopTocWing
        (makeBlogConfig theme True "")
        wingOpen
        (BayerMask.sheetBackgroundColorStyle theme bayerMask)
        (BayerMask.sheetTintColorStyle theme bayerMask)
        (Lazy.lazy2 BayerMask.viewOverlay theme bayerMask)
        blog
        wingSlug


viewMobileTocOverlayLazy : Theme -> BayerMask.Model -> Blog.Model -> String -> Html Msg
viewMobileTocOverlayLazy theme bayerMask blog slug =
    Blog.viewMobileTocOverlay
        (makeBlogConfig theme True "")
        (BayerMask.sheetTintColorStyle theme bayerMask)
        blog
        slug


viewEdgeBlurTop : Theme -> BayerMask.Model -> Html Msg
viewEdgeBlurTop theme bayerMask =
    div
        ([ Attr.id "sheet-blur-top"
         , Attr.attribute "aria-hidden" "true"
         , Attr.class "pointer-events-none select-none absolute inset-x-0 top-0 h-16 sm:h-20 z-20 sheet-squircle-shape pblur sheet-edge-blur"
         ]
            ++ BayerMask.sheetTintColorStyle theme bayerMask
        )
        [ Html.node "i" [] [], Html.node "i" [] [] ]


viewEdgeBlurBottom : Theme -> BayerMask.Model -> Html Msg
viewEdgeBlurBottom theme bayerMask =
    div
        ([ Attr.id "sheet-blur-bottom"
         , Attr.attribute "aria-hidden" "true"
         , Attr.class "pointer-events-none select-none absolute inset-x-0 bottom-0 h-20 z-20 pblur pblur-bottom sheet-edge-blur-bottom"
         ]
            ++ BayerMask.sheetTintColorStyle theme bayerMask
        )
        [ Html.node "i" [] [], Html.node "i" [] [] ]


view : Model -> Browser.Document Msg
view model =
    { title =
        case model.route of
            Home ->
                "Alaa El-Samouly (Samouly) | Software Engineer at Charm"

            BlogIndex ->
                "Writing | Alaa El-Samouly (Samouly)"

            BlogPost slug ->
                case Blog.findBySlug slug model.blog of
                    Just post ->
                        post.title ++ " | Samouly"

                    Nothing ->
                        "Post not found | Samouly"
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
                [ Attr.class "relative z-10 mt-14 sm:mt-16 w-full max-w-[50rem] flex-1 min-h-0 flex flex-col" ]
                [ div
                    ([ Attr.attribute "aria-hidden" "true"
                     , Attr.class "pointer-events-none absolute inset-0 z-0 sheet-squircle shadow-[var(--sheet-outer-shadow)]"
                     ]
                        ++ BayerMask.sheetDropShadowStyle model.bayerMask
                    )
                    []
                , let
                    wingOpen =
                        case ( model.route, model.pendingRoute ) of
                            ( BlogPost _, Just Home ) ->
                                False

                            ( BlogPost _, Just BlogIndex ) ->
                                False

                            ( BlogPost _, _ ) ->
                                True

                            _ ->
                                False

                    wingSlug =
                        case model.route of
                            BlogPost slug ->
                                Just slug

                            _ ->
                                model.lastPostSlug
                  in
                  Lazy.lazy5 viewDesktopTocWingLazy wingOpen model.theme model.bayerMask model.blog wingSlug
                , div
                    ([ Attr.id "content-sheet"
                     , Attr.attribute "data-grainient-shield" "true"
                     , Attr.class "sheet-squircle select-text relative z-10 w-full flex-1 min-h-0 flex flex-col bg-[var(--page-bg)] shadow-[var(--sheet-inset)]"
                     ]
                        ++ BayerMask.sheetBackgroundStyle model.theme model.bayerMask
                    )
                    [ div
                        [ Attr.id "dither-stage"
                        , Attr.class "scroll-clean relative z-0 flex-1 min-h-0 rounded-t-[2.4rem] overflow-x-hidden overflow-y-auto flex flex-col justify-between"
                        ]
                        [ main_
                            [ Attr.id "main-content"
                            , Attr.tabindex -1
                            , Attr.class ("relative z-20 pointer-events-none w-full pl-5 pr-7 sm:px-10 pt-5 sm:pt-7 pb-3 flex-1 flex flex-col justify-start " ++ focusRing)
                            ]
                            [ case model.route of
                                Home ->
                                    div [ Attr.class "flex flex-col pointer-events-auto" ]
                                        [ Lazy.lazy3 viewAbout model.flags.diveDepthMeters model.theme model.ditherTop
                                        , Lazy.lazy viewWork ()
                                        , Lazy.lazy4 viewContact model.flags.currentYear model.theme model.motionPlaying model.copyState
                                        ]

                                BlogIndex ->
                                    Lazy.lazy4 viewBlogIndexLazy model.theme model.motionPlaying model.flags.currentYear model.blog

                                BlogPost slug ->
                                    Lazy.lazy5 viewBlogPostLazy model.theme model.motionPlaying model.flags.currentYear model.blog slug
                            ]
                        , Lazy.lazy2 viewFooter model.theme model.ditherFooter
                        ]
                    , case model.route of
                        BlogPost slug ->
                            Lazy.lazy4 viewMobileTocOverlayLazy model.theme model.bayerMask model.blog slug

                        _ ->
                            text ""
                    , Lazy.lazy2 viewEdgeBlurTop model.theme model.bayerMask
                    , Lazy.lazy2 viewEdgeBlurBottom model.theme model.bayerMask
                    , Lazy.lazy2 BayerMask.viewOverlay model.theme model.bayerMask
                    , Lazy.lazy viewScrollTrack ()
                    ]
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
        , Attr.class "cursor-pointer touch-none select-none absolute right-2 top-11 bottom-0 z-30 w-[12px] rounded-t-full rounded-b-none pt-[3px] px-[3px] pb-0 grainient-scroll-track transition-opacity duration-200 before:content-[''] before:absolute before:-inset-x-3 before:inset-y-0"
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


ditherTailSvg : Html msg
ditherTailSvg =
    svg
        [ SvgAttr.viewBox "0 0 8 8"
        , SvgAttr.preserveAspectRatio "none"
        , SvgAttr.class "block w-2.5 h-full -ml-px shrink-0"
        , Attr.attribute "shape-rendering" "crispEdges"
        , Attr.attribute "aria-hidden" "true"
        , Attr.attribute "focusable" "false"
        ]
        [ rect [ SvgAttr.x "0", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "8", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "1", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "2", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "1", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "3", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "1", SvgAttr.y "7", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "2", SvgAttr.y "1", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "2", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "2", SvgAttr.y "5", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "2", SvgAttr.y "7", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "3", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "3", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "3", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "3", SvgAttr.y "6", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "4", SvgAttr.y "1", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "4", SvgAttr.y "5", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "5", SvgAttr.y "3", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "5", SvgAttr.y "7", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "6", SvgAttr.y "0", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "6", SvgAttr.y "4", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "7", SvgAttr.y "2", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
        , rect [ SvgAttr.x "7", SvgAttr.y "6", SvgAttr.width "1", SvgAttr.height "1", SvgAttr.fill "currentColor" ] []
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
        , Attr.class "scroll-mt-8 flex flex-col gap-y-3 sm:grid sm:grid-cols-[2.75rem_1fr] sm:gap-x-6 sm:items-start"
        ]
        [ Lazy.lazy viewVerticalLabel "About"
        , div [ Attr.class "min-w-0 grid grid-cols-[1fr_auto] gap-x-4 sm:gap-x-5 items-start" ]
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
        , Attr.class "scroll-mt-8 mt-14 sm:mt-24 flex flex-col gap-y-3 sm:grid sm:grid-cols-[2.75rem_1fr] sm:gap-x-6 sm:items-start"
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
        , Attr.class "scroll-mt-8 mt-12 sm:mt-8 flex flex-col gap-y-3 sm:grid sm:grid-cols-[2.75rem_1fr] sm:gap-x-6 sm:items-start"
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
                    , a
                        [ Attr.href "/blog"
                        , onInternalLinkClick (Navigate BlogIndex)
                        , Attr.attribute "translate" "no"
                        , Attr.class
                            ("inline-flex items-center min-h-11 sm:min-h-8 text-[var(--page-muted)] transition-colors duration-150 hover:text-[var(--page-fg)] rounded-xs "
                                ++ focusRing
                            )
                        ]
                        [ text "Blog" ]
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
    footer [ Attr.id "dither-footer", Attr.class "relative z-10 w-full -mt-4 sm:-mt-20 pointer-events-none" ]
        [ div [ Attr.class "pointer-events-auto" ]
            [ DitherFooter.view theme ditherFooterModel |> Html.map FooterDitherMsg ]
        ]
