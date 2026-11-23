module BayerMask exposing
    ( Model
    , TickEvent(..)
    , init
    , isAnimating
    , sheetBackgroundColorStyle
    , sheetBackgroundStyle
    , sheetDropShadowStyle
    , startRouteSwitch
    , startThemeSwitch
    , tick
    , viewOverlay
    )

import Html exposing (Attribute, Html)
import Html.Attributes as Attr
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Theme exposing (Theme(..))
import WebGL exposing (Mesh, Shader)


type TickEvent
    = NoEvent
    | SwapTheme Theme
    | SwapRoute


type Phase
    = Idle
    | IntroReveal Float
    | ThemeOut Float Theme Theme
    | ThemeIn Float Theme Theme
    | RouteOut Float
    | RouteIn Float


type alias ShadowAnim =
    { elapsed : Float
    , fromTheme : Theme
    , targetTheme : Theme
    }


type alias Model =
    { phase : Phase
    , shadow : Maybe ShadowAnim
    }


introDurationMs : Float
introDurationMs =
    780


outMs : Float
outMs =
    310


inMs : Float
inMs =
    350


routeOutMs : Float
routeOutMs =
    240


routeInMs : Float
routeInMs =
    280


shadowMs : Float
shadowMs =
    840


init : Bool -> Model
init prefersReduced =
    { phase =
        if prefersReduced then
            Idle

        else
            IntroReveal 0
    , shadow = Nothing
    }


isAnimating : Model -> Bool
isAnimating model =
    model.phase /= Idle || model.shadow /= Nothing


startThemeSwitch : Bool -> Theme -> Theme -> Model -> ( Model, Maybe Theme )
startThemeSwitch prefersReduced fromTheme targetTheme model =
    if prefersReduced then
        ( { model | phase = Idle, shadow = Nothing }, Just targetTheme )

    else
        ( { model
            | phase = ThemeOut 0 fromTheme targetTheme
            , shadow = Just { elapsed = 0, fromTheme = fromTheme, targetTheme = targetTheme }
          }
        , Nothing
        )


startRouteSwitch : Bool -> Model -> ( Model, Bool )
startRouteSwitch prefersReduced model =
    if prefersReduced then
        ( { model | phase = Idle }, True )

    else
        ( { model | phase = RouteOut 0 }, False )


tickShadow : Float -> Maybe ShadowAnim -> Maybe ShadowAnim
tickShadow dtMs maybeShadow =
    case maybeShadow of
        Nothing ->
            Nothing

        Just anim ->
            let
                next =
                    anim.elapsed + min 50 dtMs
            in
            if next >= shadowMs then
                Nothing

            else
                Just { anim | elapsed = next }


tick : Float -> Model -> ( Model, TickEvent )
tick dtMs model =
    let
        nextShadow =
            tickShadow dtMs model.shadow
    in
    case model.phase of
        Idle ->
            ( { model | shadow = nextShadow }, NoEvent )

        IntroReveal elapsed ->
            let
                next =
                    elapsed + min 50 dtMs
            in
            if next >= introDurationMs then
                ( { model | phase = Idle, shadow = nextShadow }, NoEvent )

            else
                ( { model | phase = IntroReveal next, shadow = nextShadow }, NoEvent )

        ThemeOut elapsed fromTheme targetTheme ->
            let
                next =
                    elapsed + min 50 dtMs
            in
            if next >= outMs then
                ( { model | phase = ThemeIn 0 fromTheme targetTheme, shadow = nextShadow }
                , SwapTheme targetTheme
                )

            else
                ( { model | phase = ThemeOut next fromTheme targetTheme, shadow = nextShadow }
                , NoEvent
                )

        ThemeIn elapsed fromTheme targetTheme ->
            let
                next =
                    elapsed + min 50 dtMs
            in
            if next >= inMs then
                ( { model | phase = Idle, shadow = nextShadow }, NoEvent )

            else
                ( { model | phase = ThemeIn next fromTheme targetTheme, shadow = nextShadow }, NoEvent )

        RouteOut elapsed ->
            let
                next =
                    elapsed + min 50 dtMs
            in
            if next >= routeOutMs then
                ( { model | phase = RouteIn 0, shadow = nextShadow }, SwapRoute )

            else
                ( { model | phase = RouteOut next, shadow = nextShadow }, NoEvent )

        RouteIn elapsed ->
            let
                next =
                    elapsed + min 50 dtMs
            in
            if next >= routeInMs then
                ( { model | phase = Idle, shadow = nextShadow }, NoEvent )

            else
                ( { model | phase = RouteIn next, shadow = nextShadow }, NoEvent )


currentBgLight : Theme -> Model -> Float
currentBgLight currentTheme model =
    case model.phase of
        Idle ->
            Theme.isLightFloat currentTheme

        IntroReveal _ ->
            Theme.isLightFloat currentTheme

        RouteOut _ ->
            Theme.isLightFloat currentTheme

        RouteIn _ ->
            Theme.isLightFloat currentTheme

        ThemeOut elapsed fromTheme targetTheme ->
            let
                t =
                    clamp 0 1 (((elapsed / outMs) - 0.5) / 0.5)

                eased =
                    t * t * (3 - 2 * t) * 0.5
            in
            lerp (Theme.isLightFloat fromTheme) (Theme.isLightFloat targetTheme) eased

        ThemeIn elapsed fromTheme targetTheme ->
            let
                t =
                    clamp 0 1 ((elapsed / inMs) / 0.5)

                eased =
                    0.5 + (t * t * (3 - 2 * t)) * 0.5
            in
            lerp (Theme.isLightFloat fromTheme) (Theme.isLightFloat targetTheme) eased


lerp : Float -> Float -> Float -> Float
lerp a b t =
    a + (b - a) * t


fmtPx : Float -> String
fmtPx val =
    String.fromFloat (toFloat (round (val * 10)) / 10) ++ "px"


fmtAlpha : Float -> String
fmtAlpha val =
    String.fromFloat (toFloat (round (clamp 0 1 val * 1000)) / 1000)


sheetDropShadowStyle : Model -> List (Attribute msg)
sheetDropShadowStyle model =
    case model.shadow of
        Nothing ->
            []

        Just anim ->
            let
                t =
                    clamp 0 1 (anim.elapsed / shadowMs)

                colorT =
                    t * t * (3 - 2 * t)

                lightMix =
                    lerp (Theme.isLightFloat anim.fromTheme) (Theme.isLightFloat anim.targetTheme) colorT

                dip =
                    sin (pi * t) ^ 1.25

                sizeScale =
                    1 - 0.58 * dip

                r =
                    round (lerp 0 14 lightMix)

                g =
                    round (lerp 0 14 lightMix)

                b =
                    round (lerp 0 18 lightMix)

                rgbPrefix =
                    "rgba(" ++ String.fromInt r ++ ", " ++ String.fromInt g ++ ", " ++ String.fromInt b ++ ", "

                topY =
                    -6 * sizeScale

                topBlur =
                    14 * sizeScale

                topAlpha =
                    lerp 0.34 0.08 lightMix * (1 - 0.35 * dip)

                botY =
                    12 * sizeScale

                botBlur =
                    lerp 24 22 lightMix * sizeScale

                botAlpha =
                    lerp 0.5 0.11 lightMix * (1 - 0.35 * dip)

                value =
                    "0 "
                        ++ fmtPx topY
                        ++ " "
                        ++ fmtPx topBlur
                        ++ " "
                        ++ rgbPrefix
                        ++ fmtAlpha topAlpha
                        ++ "), 0 "
                        ++ fmtPx botY
                        ++ " "
                        ++ fmtPx botBlur
                        ++ " "
                        ++ rgbPrefix
                        ++ fmtAlpha botAlpha
                        ++ ")"
            in
            [ Attr.style "box-shadow" value ]


insetShadowStyle : Maybe ShadowAnim -> List (Attribute msg)
insetShadowStyle maybeShadow =
    case maybeShadow of
        Nothing ->
            []

        Just anim ->
            let
                t =
                    clamp 0 1 (anim.elapsed / shadowMs)

                colorT =
                    t * t * (3 - 2 * t)

                lightMix =
                    lerp (Theme.isLightFloat anim.fromTheme) (Theme.isLightFloat anim.targetTheme) colorT

                insetAlpha =
                    lerp 0.08 0.65 lightMix
            in
            [ Attr.style "box-shadow" ("0 -1px 0 0 rgba(255, 255, 255, " ++ fmtAlpha insetAlpha ++ ") inset") ]


sheetBackgroundColorStyle : Theme -> Model -> List (Attribute msg)
sheetBackgroundColorStyle currentTheme model =
    case model.phase of
        ThemeOut _ _ _ ->
            let
                mixVal =
                    currentBgLight currentTheme model

                r =
                    round (5 + (245 - 5) * mixVal)

                g =
                    round (5 + (244 - 5) * mixVal)

                b =
                    round (5 + (240 - 5) * mixVal)

                rgbStr =
                    "rgb(" ++ String.fromInt r ++ ", " ++ String.fromInt g ++ ", " ++ String.fromInt b ++ ")"
            in
            [ Attr.style "background-color" rgbStr
            , Attr.style "color" rgbStr
            ]

        ThemeIn _ _ _ ->
            let
                mixVal =
                    currentBgLight currentTheme model

                r =
                    round (5 + (245 - 5) * mixVal)

                g =
                    round (5 + (244 - 5) * mixVal)

                b =
                    round (5 + (240 - 5) * mixVal)

                rgbStr =
                    "rgb(" ++ String.fromInt r ++ ", " ++ String.fromInt g ++ ", " ++ String.fromInt b ++ ")"
            in
            [ Attr.style "background-color" rgbStr
            , Attr.style "color" rgbStr
            ]

        _ ->
            []


sheetBackgroundStyle : Theme -> Model -> List (Attribute msg)
sheetBackgroundStyle currentTheme model =
    let
        bgStyle =
            case model.phase of
                ThemeOut _ _ _ ->
                    let
                        mixVal =
                            currentBgLight currentTheme model

                        r =
                            round (5 + (245 - 5) * mixVal)

                        g =
                            round (5 + (244 - 5) * mixVal)

                        b =
                            round (5 + (240 - 5) * mixVal)

                        rgbStr =
                            "rgb(" ++ String.fromInt r ++ ", " ++ String.fromInt g ++ ", " ++ String.fromInt b ++ ")"
                    in
                    [ Attr.style "background-color" rgbStr ]

                ThemeIn _ _ _ ->
                    let
                        mixVal =
                            currentBgLight currentTheme model

                        r =
                            round (5 + (245 - 5) * mixVal)

                        g =
                            round (5 + (244 - 5) * mixVal)

                        b =
                            round (5 + (240 - 5) * mixVal)

                        rgbStr =
                            "rgb(" ++ String.fromInt r ++ ", " ++ String.fromInt g ++ ", " ++ String.fromInt b ++ ")"
                    in
                    [ Attr.style "background-color" rgbStr ]

                _ ->
                    []
    in
    bgStyle ++ insetShadowStyle model.shadow


viewOverlay : Theme -> Model -> Html msg
viewOverlay currentTheme model =
    case model.phase of
        Idle ->
            Html.text ""

        IntroReveal elapsed ->
            let
                t =
                    clamp 0 1 (elapsed / introDurationMs)
            in
            renderShader (Theme.isLightFloat currentTheme) t 1.0

        ThemeOut elapsed _ _ ->
            let
                t =
                    clamp 0 1 (elapsed / outMs)

                eased =
                    t * t * (3 - 2 * t)
            in
            renderShader (currentBgLight currentTheme model) eased 0.0

        ThemeIn elapsed _ _ ->
            let
                t =
                    clamp 0 1 (elapsed / inMs)

                eased =
                    t * t * (3 - 2 * t)
            in
            renderShader (currentBgLight currentTheme model) (1 - eased) 0.0

        RouteOut elapsed ->
            let
                t =
                    clamp 0 1 (elapsed / routeOutMs)

                eased =
                    t * t * (3 - 2 * t)
            in
            renderShader (Theme.isLightFloat currentTheme) eased 0.0

        RouteIn elapsed ->
            let
                t =
                    clamp 0 1 (elapsed / routeInMs)

                eased =
                    t * t * (3 - 2 * t)
            in
            renderShader (Theme.isLightFloat currentTheme) (1 - eased) 0.0


renderShader : Float -> Float -> Float -> Html msg
renderShader bgLight progress mode =
    WebGL.toHtmlWith
        [ WebGL.alpha True ]
        [ Attr.width 400
        , Attr.height 440
        , Attr.attribute "aria-hidden" "true"
        , Attr.style "corner-shape" "inherit"
        , Attr.class "absolute inset-0 z-40 block w-full h-full rounded-[inherit] pixel-crisp pointer-events-none select-none"
        ]
        [ WebGL.entity
            vertexShader
            fragmentShader
            quadMesh
            { uBgLight = bgLight
            , uProgress = progress
            , uMode = mode
            }
        ]


quadMesh : Mesh { position : Vec2 }
quadMesh =
    WebGL.triangles
        [ ( { position = vec2 -1 -1 }
          , { position = vec2 3 -1 }
          , { position = vec2 -1 3 }
          )
        ]


type alias Uniforms =
    { uBgLight : Float
    , uProgress : Float
    , uMode : Float
    }


vertexShader : Shader { position : Vec2 } Uniforms { vUv : Vec2 }
vertexShader =
    [glsl|
        attribute vec2 position;
        varying vec2 vUv;
        void main() {
            vUv = position * 0.5 + 0.5;
            gl_Position = vec4(position, 0.0, 1.0);
        }
    |]


fragmentShader : Shader {} Uniforms { vUv : Vec2 }
fragmentShader =
    [glsl|
        precision highp float;
        varying vec2 vUv;
        uniform float uBgLight;
        uniform float uProgress;
        uniform float uMode;

        float bayer2(vec2 a) {
            a = floor(a);
            return fract(a.x * 0.5 + a.y * a.y * 0.75);
        }

        float bayer4(vec2 a) {
            return bayer2(0.5 * a) * 0.25 + bayer2(a);
        }

        float bayer8(vec2 a) {
            return bayer4(0.5 * a) * 0.25 + bayer2(a);
        }

        void main() {
            vec2 cell = floor(gl_FragCoord.xy);
            float threshold = bayer8(cell);
            float coverage = uProgress;

            if (uMode > 0.5) {
                float yFromTop = 1.0 - vUv.y;
                float local = clamp((uProgress * 1.45) - yFromTop * 0.45, 0.0, 1.0);
                float eased = 1.0 - pow(1.0 - local, 3.0);
                coverage = 1.0 - eased;
            }

            float mask = coverage >= 0.999 ? 1.0 : step(threshold, coverage - 0.004);
            vec3 darkBg = vec3(0.0196078, 0.0196078, 0.0196078);
            vec3 lightBg = vec3(0.9607843, 0.9568627, 0.9411765);
            vec3 col = mix(darkBg, lightBg, uBgLight);

            gl_FragColor = vec4(col * mask, mask);
        }
    |]
