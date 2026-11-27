port module Main exposing (main)

import Browser
import Browser.Events
import Browser.Navigation as Nav
import Data.HeadingId as HeadingId exposing (HeadingId)
import Data.Route as Route exposing (Route(..))
import Data.Slug as Slug exposing (Slug)
import Data.Theme as Theme exposing (Theme(..))
import Effects.BayerMask as BayerMask
import Effects.DitherFooter as DitherFooter
import Effects.DitherTop as DitherTop
import Effects.GrainientBg as GrainientBg
import Effects.TocWingMorph as TocWingMorph
import Features.Blog as Blog
import Features.Components as Components
import Features.GithubGraph as GithubGraph
import Features.NotFound as NotFound
import Features.OgImages as OgImages
import Features.WorkSection as WorkSection
import Html exposing (Html, a, button, div, footer, h1, h2, main_, p, section, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Lazy as Lazy
import Json.Decode as Decode exposing (Decoder)
import Process
import Svg exposing (rect, svg)
import Svg.Attributes as SvgAttr
import Task
import Time
import Url exposing (Url)


port copyToClipboard : String -> Cmd msg


port clipboardResult : (Bool -> msg) -> Sub msg


port reducedMotionChanged : (Bool -> msg) -> Sub msg


port setTheme : String -> Cmd msg


port syncMeta :
    { title : String
    , description : String
    , canonical : String
    , ogType : String
    , ogImage : String
    , ogImageAlt : String
    }
    -> Cmd msg


port resetScroll : () -> Cmd msg


port scrollToHeading : String -> Cmd msg


port activeHeadingChanged : (String -> msg) -> Sub msg


port footerVisibilityChanged : (Bool -> msg) -> Sub msg


port playSynthNotes : List Int -> Cmd msg


type alias Flags =
    { currentYear : String
    , diveDepthMeters : String
    , prefersReducedMotion : Bool
    , blogPosts : List Blog.Post
    , components : List Components.ComponentEntry
    }


type CopyState
    = CopyIdle
    | CopySucceeded
    | CopyFailed


type alias Model =
    { navKey : Nav.Key
    , flags : Flags
    , route : Route
    , pendingRoute : Maybe Route
    , lastPostSlug : Maybe Slug
    , theme : Theme
    , motionPlaying : Bool
    , bayerMask : BayerMask.Model
    , tocWing : TocWingMorph.Model
    , prWing : TocWingMorph.Model
    , prWingOpen : Bool
    , ditherTop : DitherTop.Model
    , ditherFooter : DitherFooter.Model
    , ditherAccumMs : Float
    , footerVisible : Bool
    , blog : Blog.Model
    , components : Components.Model
    , ogImages : OgImages.Model
    , openWorkId : Maybe String
    , hoveredWork : Maybe WorkSection.HoverRect
    , githubGraph : GithubGraph.Model
    , notFound : NotFound.Model
    , copyState : CopyState
    , liveAnnouncement : String
    }


type Msg
    = TopDitherMsg DitherTop.Msg
    | FooterDitherMsg DitherFooter.Msg
    | BlogMsg Blog.Msg
    | ComponentsMsg Components.Msg
    | OgImagesMsg OgImages.Msg
    | ToggleWorkDrawer String
    | HoverWorkDrawer (Maybe WorkSection.HoverRect)
    | GithubGraphMsg GithubGraph.Msg
    | NotFoundMsg NotFound.Msg
    | TogglePrWing
    | ClosePrWing
    | AnimationTick Float
    | ToggleTheme
    | ToggleMotion
    | ReducedMotionChanged Bool
    | Navigate Route
    | UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | ActiveHeadingChanged String
    | FooterVisibilityChanged Bool
    | InitialHashJump HeadingId
    | CopyEmail
    | GotClipboardResult Bool
    | ResetCopyState
    | ResetCodeCopy
    | ResetComponentCopy
    | ResetHeadingCopy


siteOrigin : String
siteOrigin =
    "https://portforio.samouly.fun"


emailAddress : String
emailAddress =
    "alasamouly@gmail.com"


metaForRoute : Route -> Blog.Model -> Components.Model -> { title : String, description : String, canonical : String, ogType : String, ogImage : String, ogImageAlt : String }
metaForRoute route blogModel componentsModel =
    let
        path =
            Route.toPath route

        canonical =
            siteOrigin ++ path

        defaultDesc =
            "Alaa El-Samouly (Samouly, sam0uly) is an Egyptian software engineer at Charm building Go terminal interfaces, CLI tools (Twig, mural, Spin, bubbleMonitor, Mditor), NixOS setups, and web apps with Nuxt, Vue, and Elm."
    in
    case route of
        BlogIndex ->
            { title = "Writing | Alaa El-Samouly (Samouly)"
            , description = "Technical writing by Alaa El-Samouly (Samouly) on Go, Linux distributions, NixOS, terminal tooling, and software engineering."
            , canonical = canonical
            , ogType = "website"
            , ogImage = siteOrigin ++ "/og/blog.jpg"
            , ogImageAlt = "Writing by Alaa El-Samouly (Samouly) on Go, Linux, NixOS, and software engineering."
            }

        BlogPost slug ->
            case Blog.findBySlug slug blogModel of
                Just post ->
                    { title = post.title ++ " | Samouly"
                    , description =
                        if String.isEmpty post.summary then
                            defaultDesc

                        else
                            post.summary
                    , canonical = canonical
                    , ogType = "article"
                    , ogImage = siteOrigin ++ "/og/blog-" ++ Slug.toString post.slug ++ ".jpg"
                    , ogImageAlt = post.title ++ " by Alaa El-Samouly (Samouly)."
                    }

                Nothing ->
                    { title = "Post not found | Samouly"
                    , description = defaultDesc
                    , canonical = canonical
                    , ogType = "website"
                    , ogImage = siteOrigin ++ "/og-image.jpg"
                    , ogImageAlt = "Portfolio of Alaa El-Samouly (Samouly), software engineer at Charm."
                    }

        ComponentsIndex ->
            { title = "Components | Alaa El-Samouly (Samouly)"
            , description = "Interactive UI components built with Tailwind CSS, with copy-paste usage and source code for Vue, React, and Elm."
            , canonical = canonical
            , ogType = "website"
            , ogImage = siteOrigin ++ "/og-image.jpg"
            , ogImageAlt = "UI Components by Alaa El-Samouly (Samouly) for Vue, React, and Elm."
            }

        ComponentDetail slug ->
            case Components.findBySlug slug componentsModel of
                Just item ->
                    { title = item.title ++ " | Components · Samouly"
                    , description = item.summary
                    , canonical = canonical
                    , ogType = "article"
                    , ogImage = siteOrigin ++ "/og-image.jpg"
                    , ogImageAlt = item.title ++ " component for Vue, React, and Elm."
                    }

                Nothing ->
                    { title = "Component not found | Samouly"
                    , description = defaultDesc
                    , canonical = canonical
                    , ogType = "website"
                    , ogImage = siteOrigin ++ "/og-image.jpg"
                    , ogImageAlt = "Component not found."
                    }

        NotFoundRoute _ ->
            { title = "404 · Page not found | Samouly"
            , description = "The requested page could not be found."
            , canonical = canonical
            , ogType = "website"
            , ogImage = siteOrigin ++ "/og-image.jpg"
            , ogImageAlt = "404 Page not found."
            }

        _ ->
            { title = "Alaa El-Samouly (Samouly) | Software Engineer at Charm"
            , description = defaultDesc
            , canonical = canonical
            , ogType = "website"
            , ogImage = siteOrigin ++ "/og-image.jpg"
            , ogImageAlt = "Portfolio of Alaa El-Samouly (Samouly), software engineer at Charm, featuring Bayer dither artwork and selected Go, Linux, and web projects."
            }


defaultFlags : Flags
defaultFlags =
    { currentYear = "2026"
    , diveDepthMeters = "35"
    , prefersReducedMotion = False
    , blogPosts = []
    , components = []
    }


decodeFlags : Decoder Flags
decodeFlags =
    Decode.map5 Flags
        (Decode.field "currentYear" Decode.string)
        (Decode.field "diveDepthMeters" Decode.string)
        (Decode.field "prefersReducedMotion" Decode.bool)
        (Decode.oneOf
            [ Decode.field "blogPosts" Blog.decodePosts
            , Decode.succeed []
            ]
        )
        (Decode.oneOf
            [ Decode.field "components" Components.decodeList
            , Decode.succeed []
            ]
        )


main : Program Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }


init : Decode.Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init rawFlags url navKey =
    let
        decodedFlags =
            Decode.decodeValue decodeFlags rawFlags |> Result.withDefault defaultFlags

        ( topModel, topCmd ) =
            DitherTop.init decodedFlags.prefersReducedMotion

        ( githubModel, githubCmd ) =
            GithubGraph.init

        initialRoute =
            Route.fromPath url.path

        initialSlug =
            case initialRoute of
                BlogPost slug ->
                    Just slug

                _ ->
                    Nothing

        blogModel =
            Blog.init decodedFlags.blogPosts

        hashJumpCmd =
            url.fragment
                |> Maybe.andThen HeadingId.fromString
                |> Maybe.map (\hid -> Process.sleep 80 |> Task.perform (\_ -> InitialHashJump hid))
                |> Maybe.withDefault Cmd.none
        componentsModel =
            Components.init decodedFlags.prefersReducedMotion decodedFlags.components

        initialRouteCmd =
            case initialRoute of
                BlogPost slug ->
                    Cmd.map BlogMsg (Blog.ensureLoaded slug blogModel)

                ComponentDetail slug ->
                    Cmd.map ComponentsMsg (Components.ensureLoaded slug componentsModel)

                _ ->
                    Cmd.none
    in
    ( { navKey = navKey
      , flags = decodedFlags
      , route = initialRoute
      , pendingRoute = Nothing
      , lastPostSlug = initialSlug
      , theme = Dark
      , motionPlaying = not decodedFlags.prefersReducedMotion
      , bayerMask = BayerMask.init decodedFlags.prefersReducedMotion
      , tocWing =
            TocWingMorph.init
                decodedFlags.prefersReducedMotion
                (case initialRoute of
                    BlogPost _ ->
                        True

                    _ ->
                        False
                )
      , prWing = TocWingMorph.init decodedFlags.prefersReducedMotion False
      , prWingOpen = False
      , ditherTop = topModel
      , ditherFooter = DitherFooter.init decodedFlags.prefersReducedMotion
      , ditherAccumMs = 0
      , footerVisible = True
      , blog = blogModel
      , components = componentsModel
      , ogImages = OgImages.init decodedFlags.blogPosts
      , openWorkId = Nothing
      , hoveredWork = Nothing
      , githubGraph = githubModel
      , notFound = NotFound.init
      , copyState = CopyIdle
      , liveAnnouncement = ""
      }
    , Cmd.batch
        [ Cmd.map TopDitherMsg topCmd
        , Cmd.map GithubGraphMsg githubCmd
        , initialRouteCmd
        , syncMeta (metaForRoute initialRoute blogModel componentsModel)
        , hashJumpCmd
        ]
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        onHome =
            model.route == Home

        onDitherComponent =
            case model.route of
                ComponentsIndex ->
                    True

                ComponentDetail slug ->
                    Slug.toString slug == "dither-footer"

                _ ->
                    False

        onNotFound =
            case model.route of
                NotFoundRoute _ ->
                    True

                _ ->
                    False

        needsHighFps =
            BayerMask.isAnimating model.bayerMask
                || TocWingMorph.isAnimating model.tocWing
                || TocWingMorph.isAnimating model.prWing
                || (onHome && DitherTop.isAnimating model.ditherTop)
                || (model.footerVisible && DitherFooter.isAnimating model.ditherFooter)
                || (onDitherComponent && Components.isPreviewFooterAnimating model.components)
                || (onNotFound && NotFound.isAnimating (model.motionPlaying && not model.flags.prefersReducedMotion) model.notFound)

        needsAmbientFooter =
            model.footerVisible && model.motionPlaying && not model.flags.prefersReducedMotion
    in
    Sub.batch
        [ clipboardResult GotClipboardResult
        , reducedMotionChanged ReducedMotionChanged
        , activeHeadingChanged ActiveHeadingChanged
        , footerVisibilityChanged FooterVisibilityChanged
        , if needsHighFps then
            Browser.Events.onAnimationFrameDelta AnimationTick

          else if needsAmbientFooter then
            Time.every 50 (\_ -> AnimationTick 50)

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

                copyHeadingCmd =
                    case effect.copyHeading of
                        Just hid ->
                            let
                                fullPath =
                                    Route.toPath model.route ++ "#" ++ HeadingId.toString hid
                            in
                            Cmd.batch
                                [ Nav.replaceUrl model.navKey fullPath
                                , copyToClipboard (siteOrigin ++ fullPath)
                                , Process.sleep 1800 |> Task.perform (\_ -> ResetHeadingCopy)
                                ]

                        Nothing ->
                            Cmd.none

                cmds =
                    copyHeadingCmd
                        :: List.filterMap identity
                            [ Maybe.map (HeadingId.toString >> scrollToHeading) effect.scrollTo
                            , Maybe.map copyToClipboard effect.copyText
                            , Maybe.map (\_ -> Process.sleep 1800 |> Task.perform (\_ -> ResetCodeCopy)) effect.copyText
                            ]
            in
            ( { model | blog = nextBlog }
            , Cmd.batch cmds
            )

        ResetCodeCopy ->
            ( { model | blog = Blog.clearCopiedCode model.blog }
            , Cmd.none
            )

        ResetComponentCopy ->
            ( { model | components = Components.clearCopied model.components }
            , Cmd.none
            )

        ResetHeadingCopy ->
            ( { model | blog = Blog.clearCopiedHeading model.blog }
            , Cmd.none
            )

        ComponentsMsg subMsg ->
            let
                ( nextComponents, maybeCopy ) =
                    Components.update subMsg model.components

                copyCmd =
                    case maybeCopy of
                        Just snippet ->
                            Cmd.batch
                                [ copyToClipboard snippet
                                , Process.sleep 1800 |> Task.perform (\_ -> ResetComponentCopy)
                                ]

                        Nothing ->
                            Cmd.none
            in
            ( { model | components = nextComponents }
            , copyCmd
            )

        OgImagesMsg subMsg ->
            ( { model | ogImages = OgImages.update subMsg model.ogImages }
            , Cmd.none
            )

        ToggleWorkDrawer projectId ->
            let
                nextOpen =
                    if model.openWorkId == Just projectId then
                        Nothing

                    else
                        Just projectId

                nextHover =
                    Maybe.map
                        (\r ->
                            { r
                                | id = projectId
                                , visible = False
                                , animate = False
                            }
                        )
                        model.hoveredWork
            in
            ( { model | openWorkId = nextOpen, hoveredWork = nextHover }
            , Cmd.none
            )

        HoverWorkDrawer maybeRect ->
            let
                wasVisible =
                    case model.hoveredWork of
                        Just prev ->
                            prev.visible && model.openWorkId /= Just prev.id

                        Nothing ->
                            False

                nextHover =
                    case maybeRect of
                        Just r ->
                            if r.visible then
                                Just { r | animate = wasVisible }

                            else
                                case model.hoveredWork of
                                    Just prev ->
                                        Just { prev | id = r.id, visible = False, animate = False }

                                    Nothing ->
                                        Just { r | animate = False }

                        Nothing ->
                            Maybe.map (\r -> { r | id = "", visible = False, animate = False }) model.hoveredWork
            in
            ( { model | hoveredWork = nextHover }
            , Cmd.none
            )

        GithubGraphMsg subMsg ->
            ( { model | githubGraph = GithubGraph.update subMsg model.githubGraph }
            , Cmd.none
            )

        NotFoundMsg subMsg ->
            let
                ( nextNotFound, notes ) =
                    NotFound.update subMsg model.notFound
            in
            ( { model | notFound = nextNotFound }
            , if List.isEmpty notes then
                Cmd.none

              else
                playSynthNotes notes
            )

        TogglePrWing ->
            let
                nextOpen =
                    not model.prWingOpen
            in
            ( { model
                | prWingOpen = nextOpen
                , prWing = TocWingMorph.setOpen model.flags.prefersReducedMotion nextOpen model.prWing
              }
            , Cmd.none
            )

        ClosePrWing ->
            ( { model
                | prWingOpen = False
                , prWing = TocWingMorph.setOpen model.flags.prefersReducedMotion False model.prWing
              }
            , Cmd.none
            )

        ActiveHeadingChanged rawId ->
            case HeadingId.fromString rawId of
                Just hid ->
                    ( { model | blog = Blog.setActiveHeading hid model.blog }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        FooterVisibilityChanged isVisible ->
            ( { model | footerVisible = isVisible }, Cmd.none )

        InitialHashJump hid ->
            ( model, scrollToHeading (HeadingId.toString hid) )

        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    if url.path == Route.toPath model.route && url.fragment /= Nothing then
                        ( model, Cmd.none )

                    else
                        startNavigation True (Route.fromPath url.path) model

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            startNavigation False (Route.fromPath url.path) model

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

                shouldWingOpen =
                    case ( nextRoute, nextPending ) of
                        ( BlogPost _, Just Home ) ->
                            False

                        ( BlogPost _, Just BlogIndex ) ->
                            False

                        ( BlogPost _, _ ) ->
                            True

                        ( _, Just (BlogPost _) ) ->
                            True

                        _ ->
                            False

                nextTocWing =
                    model.tocWing
                        |> TocWingMorph.setOpen model.flags.prefersReducedMotion shouldWingOpen
                        |> TocWingMorph.tick dtMs

                routeSupportsPrWing r =
                    case r of
                        Home ->
                            True

                        ComponentDetail s ->
                            Slug.toString s == "github-contribution-graph"

                        _ ->
                            False

                shouldPrOpen =
                    model.prWingOpen && routeSupportsPrWing nextRoute && nextPending == Nothing

                nextPrWing =
                    model.prWing
                        |> TocWingMorph.setOpen model.flags.prefersReducedMotion shouldPrOpen
                        |> TocWingMorph.tick dtMs

                ditherTopActive =
                    model.route == Home && DitherTop.isAnimating model.ditherTop

                ditherFooterInteractive =
                    model.footerVisible && DitherFooter.isAnimating model.ditherFooter

                ( shouldTickFooter, footerDt, nextDitherAccum ) =
                    if ditherFooterInteractive then
                        ( True, dtMs, 0 )

                    else if model.footerVisible && model.motionPlaying then
                        let
                            accum =
                                model.ditherAccumMs + dtMs
                        in
                        if accum >= 45.0 then
                            ( True, accum, 0 )

                        else
                            ( False, 0, accum )

                    else
                        ( False, 0, 0 )
                ( nextNotFound, synthNotes ) =
                    case model.route of
                        NotFoundRoute _ ->
                            NotFound.tick (model.motionPlaying && not model.flags.prefersReducedMotion) dtMs model.notFound

                        _ ->
                            ( model.notFound, [] )

                tickCmd =
                    if List.isEmpty synthNotes then
                        maskCmd

                    else
                        Cmd.batch [ maskCmd, playSynthNotes synthNotes ]
            in
            ( { model
                | theme = nextTheme
                , route = nextRoute
                , pendingRoute = nextPending
                , lastPostSlug = nextLastSlug
                , bayerMask = nextMask
                , tocWing = nextTocWing
                , prWing = nextPrWing
                , prWingOpen = shouldPrOpen
                , ditherAccumMs = nextDitherAccum
                , ditherTop =
                    if ditherTopActive then
                        DitherTop.tick model.motionPlaying dtMs model.ditherTop

                    else
                        model.ditherTop
                , ditherFooter =
                    if shouldTickFooter then
                        DitherFooter.tick model.motionPlaying footerDt model.ditherFooter

                    else
                        model.ditherFooter
                , components =
                    case model.route of
                        ComponentsIndex ->
                            Components.tickPreviewFooter dtMs model.components

                        ComponentDetail slug ->
                            if Slug.toString slug == "dither-footer" then
                                Components.tickPreviewFooter dtMs model.components

                            else
                                model.components

                        _ ->
                            model.components
                , notFound = nextNotFound
              }
            , tickCmd
            )

        Navigate target ->
            startNavigation True target model

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

                    ComponentsIndex ->
                        "Opened components library."

                    ComponentDetail _ ->
                        "Opened component details."

                    OgImagesRoute ->
                        "Opened Open Graph gallery."

                    NotFoundRoute _ ->
                        "Page not found."

            pushCmd =
                if shouldPush then
                    Nav.pushUrl model.navKey (Route.toPath target)

                else
                    Cmd.none

            metaCmd =
                syncMeta (metaForRoute target model.blog model.components)

            loadRouteCmd =
                case target of
                    BlogPost slug ->
                        Cmd.map BlogMsg (Blog.ensureLoaded slug model.blog)

                    ComponentDetail slug ->
                        Cmd.map ComponentsMsg (Components.ensureLoaded slug model.components)

                    _ ->
                        Cmd.none

            ( nextMask, immediate ) =
                BayerMask.startRouteSwitch model.flags.prefersReducedMotion model.bayerMask

            targetIsPost =
                case target of
                    BlogPost _ ->
                        True

                    _ ->
                        False

            nextWing =
                TocWingMorph.setOpen model.flags.prefersReducedMotion targetIsPost model.tocWing

            nextPrOpen =
                model.prWingOpen
                    && (case target of
                            Home ->
                                True

                            ComponentDetail s ->
                                Slug.toString s == "github-contribution-graph"

                            _ ->
                                False
                       )

            nextPrWing =
                TocWingMorph.setOpen model.flags.prefersReducedMotion nextPrOpen model.prWing
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
                , tocWing = nextWing
                , prWing = nextPrWing
                , prWingOpen = nextPrOpen
                , liveAnnouncement = announcement
              }
            , Cmd.batch [ pushCmd, metaCmd, loadRouteCmd, resetScroll () ]
            )

        else
            ( { model
                | pendingRoute = Just target
                , bayerMask = nextMask
                , tocWing = nextWing
                , prWing = nextPrWing
                , prWingOpen = nextPrOpen
                , liveAnnouncement = announcement
              }
            , Cmd.batch [ pushCmd, metaCmd, loadRouteCmd ]
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


makeBlogConfig : Theme -> Bool -> String -> { toMsg : Blog.Msg -> Msg, onBackHome : Msg, onOpenBlogIndex : Msg, onOpenPost : Slug -> Msg, onToggleTheme : Msg, onToggleMotion : Msg, theme : Theme, motionPlaying : Bool, currentYear : String }
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


viewBlogPostLazy : Theme -> Bool -> String -> Blog.Model -> Slug -> Html Msg
viewBlogPostLazy theme motionPlaying currentYear blog slug =
    Blog.viewPost (makeBlogConfig theme motionPlaying currentYear) blog slug


viewOgImagesLazy : Theme -> Bool -> String -> List Blog.Post -> OgImages.Model -> Html Msg
viewOgImagesLazy theme motionPlaying currentYear posts ogModel =
    OgImages.view
        { toMsg = OgImagesMsg
        , onBackHome = Navigate Home
        , onOpenBlogIndex = Navigate BlogIndex
        , onToggleTheme = ToggleTheme
        , onToggleMotion = ToggleMotion
        , theme = theme
        , motionPlaying = motionPlaying
        , currentYear = currentYear
        , posts = posts
        }
        ogModel


makeComponentsConfig : Theme -> Bool -> String -> GithubGraph.Model -> Bool -> Float -> Components.ViewConfig Msg
makeComponentsConfig theme motionPlaying currentYear githubGraph prOpen prCoverage =
    { toMsg = ComponentsMsg
    , onBackHome = Navigate Home
    , onOpenComponentsIndex = Navigate ComponentsIndex
    , onOpenComponent = \slug -> Navigate (ComponentDetail slug)
    , onOpenBlogIndex = Navigate BlogIndex
    , onToggleTheme = ToggleTheme
    , onToggleMotion = ToggleMotion
    , onGithubGraphMsg = GithubGraphMsg
    , onTogglePrWing = TogglePrWing
    , githubGraph = githubGraph
    , prOpen = prOpen
    , prCoverage = prCoverage
    , theme = theme
    , motionPlaying = motionPlaying
    , currentYear = currentYear
    }


viewComponentsIndexLazy : Theme -> Bool -> String -> GithubGraph.Model -> Components.Model -> Html Msg
viewComponentsIndexLazy theme motionPlaying currentYear githubGraph compModel =
    Components.viewIndex (makeComponentsConfig theme motionPlaying currentYear githubGraph False 0) compModel


viewComponentDetailLazy : Theme -> Bool -> String -> GithubGraph.Model -> Bool -> Float -> Components.Model -> Slug -> Html Msg
viewComponentDetailLazy theme motionPlaying currentYear githubGraph prOpen prCoverage compModel slug =
    Components.viewDetail (makeComponentsConfig theme motionPlaying currentYear githubGraph prOpen prCoverage) compModel slug


viewNotFoundLazy : Theme -> Bool -> String -> String -> NotFound.Model -> Html Msg
viewNotFoundLazy theme motionPlaying currentYear missingPath notFoundModel =
    NotFound.view
        { toMsg = NotFoundMsg
        , onBackHome = Navigate Home
        , onOpenBlog = Navigate BlogIndex
        , onToggleTheme = ToggleTheme
        , onToggleMotion = ToggleMotion
        , theme = theme
        , motionPlaying = motionPlaying
        , currentYear = currentYear
        }
        missingPath
        notFoundModel


viewDesktopTocWingLazy : Bool -> Float -> Theme -> BayerMask.Model -> Blog.Model -> Maybe Slug -> Html Msg
viewDesktopTocWingLazy wingMoving morphProgress theme bayerMask blog wingSlug =
    Blog.viewDesktopTocWing
        (makeBlogConfig theme True "")
        morphProgress
        (BayerMask.sheetTintColorStyle theme bayerMask)
        (if wingMoving then
            text ""

         else
            Lazy.lazy2 BayerMask.viewOverlay theme bayerMask
        )
        blog
        wingSlug


viewMobileTocOverlayLazy : Theme -> BayerMask.Model -> Blog.Model -> Slug -> Html Msg
viewMobileTocOverlayLazy theme bayerMask blog slug =
    Blog.viewMobileTocOverlay
        (makeBlogConfig theme True "")
        (BayerMask.sheetTintColorStyle theme bayerMask)
        blog
        slug


viewDesktopPrWingLazy : Bool -> Float -> Theme -> BayerMask.Model -> GithubGraph.Model -> Html Msg
viewDesktopPrWingLazy wingMoving morphProgress theme bayerMask graphModel =
    GithubGraph.viewDesktopPrWing
        { toMsg = GithubGraphMsg
        , onClose = ClosePrWing
        }
        morphProgress
        (BayerMask.sheetTintColorStyle theme bayerMask)
        (if wingMoving then
            text ""

         else
            Lazy.lazy2 BayerMask.viewOverlay theme bayerMask
        )
        graphModel


viewMobilePrOverlayLazy : Bool -> Theme -> BayerMask.Model -> GithubGraph.Model -> Html Msg
viewMobilePrOverlayLazy isOpen theme bayerMask graphModel =
    GithubGraph.viewMobilePrOverlay
        { toMsg = GithubGraphMsg
        , onClose = ClosePrWing
        }
        isOpen
        (BayerMask.sheetTintColorStyle theme bayerMask)
        graphModel


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

            ComponentsIndex ->
                "Components | Alaa El-Samouly (Samouly)"

            ComponentDetail slug ->
                case Components.findBySlug slug model.components of
                    Just item ->
                        item.title ++ " | Components · Samouly"

                    Nothing ->
                        "Component not found | Samouly"

            OgImagesRoute ->
                "Open Graph Studio | Samouly"

            NotFoundRoute _ ->
                "404 · Page not found | Samouly"
    , body =
        viewSheetBody model
    }


viewSheetBody : Model -> List (Html Msg)
viewSheetBody model =
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
                    wingSlug =
                        case ( model.route, model.pendingRoute ) of
                            ( BlogPost slug, _ ) ->
                                Just slug

                            ( _, Just (BlogPost slug) ) ->
                                Just slug

                            _ ->
                                model.lastPostSlug
                  in
                  Lazy.lazy6 viewDesktopTocWingLazy (TocWingMorph.isAnimating model.tocWing) (TocWingMorph.progress model.tocWing) model.theme model.bayerMask model.blog wingSlug
                , Lazy.lazy5 viewDesktopPrWingLazy (TocWingMorph.isAnimating model.prWing) (TocWingMorph.progress model.prWing) model.theme model.bayerMask model.githubGraph
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
                                    let
                                        ( prBtnDisplayOpen, prBtnCoverage ) =
                                            prBtnDitherState model.prWing
                                    in
                                    div [ Attr.class "flex flex-col pointer-events-auto" ]
                                        [ Lazy.lazy3 viewAbout model.flags.diveDepthMeters model.theme model.ditherTop
                                        , Lazy.lazy2 viewWork model.openWorkId model.hoveredWork
                                        , Lazy.lazy4 viewGithub model.theme prBtnDisplayOpen prBtnCoverage model.githubGraph
                                        , Lazy.lazy4 viewContact model.flags.currentYear model.theme model.motionPlaying model.copyState
                                        ]

                                BlogIndex ->
                                    Lazy.lazy4 viewBlogIndexLazy model.theme model.motionPlaying model.flags.currentYear model.blog

                                BlogPost slug ->
                                    Lazy.lazy5 viewBlogPostLazy model.theme model.motionPlaying model.flags.currentYear model.blog slug

                                ComponentsIndex ->
                                    Lazy.lazy5 viewComponentsIndexLazy model.theme model.motionPlaying model.flags.currentYear model.githubGraph model.components

                                ComponentDetail slug ->
                                    let
                                        ( prBtnDisplayOpen, prBtnCoverage ) =
                                            prBtnDitherState model.prWing
                                    in
                                    viewComponentDetailLazy model.theme model.motionPlaying model.flags.currentYear model.githubGraph prBtnDisplayOpen prBtnCoverage model.components slug

                                OgImagesRoute ->
                                    Lazy.lazy5 viewOgImagesLazy model.theme model.motionPlaying model.flags.currentYear model.blog.posts model.ogImages

                                NotFoundRoute missingPath ->
                                    Lazy.lazy5 viewNotFoundLazy model.theme model.motionPlaying model.flags.currentYear missingPath model.notFound
                            ]
                        , Lazy.lazy2 viewFooter model.theme model.ditherFooter
                        ]
                    , case model.route of
                        BlogPost slug ->
                            Lazy.lazy4 viewMobileTocOverlayLazy model.theme model.bayerMask model.blog slug

                        Home ->
                            Lazy.lazy4 viewMobilePrOverlayLazy model.prWingOpen model.theme model.bayerMask model.githubGraph

                        ComponentDetail slug ->
                            if Slug.toString slug == "github-contribution-graph" then
                                Lazy.lazy4 viewMobilePrOverlayLazy model.prWingOpen model.theme model.bayerMask model.githubGraph

                            else
                                text ""

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


viewScrollTrack : () -> Html Msg
viewScrollTrack _ =
    div
        [ Attr.id "mobile-scroll-track"
        , Attr.attribute "aria-hidden" "true"
        , Attr.style "opacity" "0"
        , Attr.style "pointer-events" "none"
        , Attr.class "cursor-pointer touch-none select-none absolute right-2 top-11 bottom-0 z-30 w-[12px] rounded-t-full rounded-b-none pt-[3px] px-[3px] pb-0 grainient-scroll-track before:content-[''] before:absolute before:-inset-x-3 before:inset-y-0"
        ]
        [ div
            [ Attr.id "mobile-scroll-thumb"
            , Attr.class "w-full rounded-full grainient-scroll-thumb pointer-events-none"
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


viewWork : Maybe String -> Maybe WorkSection.HoverRect -> Html Msg
viewWork openWorkId hoveredWork =
    section
        [ Attr.id "work"
        , Attr.attribute "aria-labelledby" "work-heading"
        , Attr.class "scroll-mt-8 mt-14 sm:mt-24 flex flex-col gap-y-3 sm:grid sm:grid-cols-[2.75rem_1fr] sm:gap-x-6 sm:items-start"
        ]
        [ viewVerticalHeading "work-heading" "Work"
        , WorkSection.view
            { onToggle = ToggleWorkDrawer
            , onHover = HoverWorkDrawer
            }
            openWorkId
            hoveredWork
        ]



-- 3. GITHUB


prBtnDitherState : TocWingMorph.Model -> ( Bool, Float )
prBtnDitherState prWing =
    let
        p =
            clamp 0 1 (TocWingMorph.progress prWing)
    in
    if p < 0.5 then
        ( False, p * 2.0 )

    else
        ( True, (1.0 - p) * 2.0 )


viewGithub : Theme -> Bool -> Float -> GithubGraph.Model -> Html Msg
viewGithub theme prBtnDisplayOpen prBtnCoverage graphModel =
    if not (GithubGraph.hasData graphModel) then
        text ""

    else
        section
            [ Attr.id "github"
            , Attr.attribute "aria-labelledby" "github-heading"
            , Attr.class "scroll-mt-8 mt-12 sm:mt-16 flex flex-col gap-y-3 sm:grid sm:grid-cols-[2.75rem_1fr] sm:gap-x-6 sm:items-start"
            ]
            [ viewVerticalHeading "github-heading" "GitHub"
            , GithubGraph.view
                { toMsg = GithubGraphMsg
                , onTogglePrWing = TogglePrWing
                , prWingOpen = prBtnDisplayOpen
                , prBtnCoverage = prBtnCoverage
                }
                theme
                graphModel
            ]



-- 4. CONTACT


viewContact : String -> Theme -> Bool -> CopyState -> Html Msg
viewContact currentYear theme motionPlaying copyState =
    section
        [ Attr.id "contact"
        , Attr.attribute "aria-labelledby" "contact-heading"
        , Attr.class "scroll-mt-8 mt-12 sm:mt-14 flex flex-col gap-y-3 sm:grid sm:grid-cols-[2.75rem_1fr] sm:gap-x-6 sm:items-start"
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
