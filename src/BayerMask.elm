module BayerMask exposing
    ( Model
    , init
    , isAnimating
    , sheetBackgroundStyle
    , startThemeSwitch
    , tick
    , viewOverlay
    )

import Html exposing (Attribute, Html)
import Html.Attributes as Attr
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Theme exposing (Theme(..))
import WebGL exposing (Mesh, Shader)


type Phase
    = Idle
    | IntroReveal Float
    | ThemeOut Float Theme Theme
    | ThemeMorph Float Theme Theme
    | ThemeIn Float Theme


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
    340


morphMs : Float
morphMs =
    320


inMs : Float
inMs =
    380


shadowMs : Float
shadowMs =
    1160


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


tick : Float -> Model -> ( Model, Maybe Theme )
tick dtMs model =
    let
        nextShadow =
            tickShadow dtMs model.shadow
    in
    case model.phase of
        Idle ->
            ( { model | shadow = nextShadow }, Nothing )

        IntroReveal elapsed ->
            let
                next =
                    elapsed + min 50 dtMs
            in
            if next >= introDurationMs then
                ( { model | phase = Idle, shadow = nextShadow }, Nothing )

            else
                ( { model | phase = IntroReveal next, shadow = nextShadow }, Nothing )

        ThemeOut elapsed fromTheme targetTheme ->
            let
                next =
                    elapsed + min 50 dtMs
            in
            if next >= outMs then
                ( { model | phase = ThemeMorph 0 fromTheme targetTheme, shadow = nextShadow }
                , Just targetTheme
                )

            else
                ( { model | phase = ThemeOut next fromTheme targetTheme, shadow = nextShadow }
                , Nothing
                )

        ThemeMorph elapsed fromTheme targetTheme ->
            let
                next =
                    elapsed + min 50 dtMs
            in
            if next >= morphMs then
                ( { model | phase = ThemeIn 0 targetTheme, shadow = nextShadow }, Nothing )

            else
                ( { model | phase = ThemeMorph next fromTheme targetTheme, shadow = nextShadow }, Nothing )

        ThemeIn elapsed targetTheme ->
            let
                next =
                    elapsed + min 50 dtMs
            in
            if next >= inMs then
                ( { model | phase = Idle, shadow = nextShadow }, Nothing )

            else
                ( { model | phase = ThemeIn next targetTheme, shadow = nextShadow }, Nothing )


currentBgLight : Theme -> Model -> Float
currentBgLight currentTheme model =
    case model.phase of
        Idle ->
            Theme.isLightFloat currentTheme

        IntroReveal _ ->
            Theme.isLightFloat currentTheme

        ThemeOut _ fromTheme _ ->
            Theme.isLightFloat fromTheme

        ThemeMorph elapsed fromTheme targetTheme ->
            let
                t =
                    clamp 0 1 (elapsed / morphMs)

                eased =
                    t * t * (3 - 2 * t)

                a =
                    Theme.isLightFloat fromTheme

                b =
                    Theme.isLightFloat targetTheme
            in
            a + (b - a) * eased

        ThemeIn _ targetTheme ->
            Theme.isLightFloat targetTheme


lerp : Float -> Float -> Float -> Float
lerp a b t =
    a + (b - a) * t


fmtPx : Float -> String
fmtPx val =
    String.fromFloat (toFloat (round (val * 10)) / 10) ++ "px"


fmtAlpha : Float -> String
fmtAlpha val =
    String.fromFloat (toFloat (round (clamp 0 1 val * 1000)) / 1000)


shadowStyle : Maybe ShadowAnim -> List (Attribute msg)
shadowStyle maybeShadow =
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

                dip =
                    sin (pi * t) ^ 1.25

                sizeScale =
                    1 - 0.58 * dip

                insetAlpha =
                    lerp 0.08 0.65 lightMix

                r =
                    round (lerp 0 14 lightMix)

                g =
                    round (lerp 0 14 lightMix)

                b =
                    round (lerp 0 18 lightMix)

                rgbPrefix =
                    "rgba(" ++ String.fromInt r ++ ", " ++ String.fromInt g ++ ", " ++ String.fromInt b ++ ", "

                topY =
                    -12 * sizeScale

                topBlur =
                    lerp 48 40 lightMix * sizeScale

                topSpread =
                    -12 * sizeScale

                topAlpha =
                    lerp 0.72 0.12 lightMix * (1 - 0.35 * dip)

                botY =
                    24 * sizeScale

                botBlur =
                    lerp 80 64 lightMix * sizeScale

                botSpread =
                    -16 * sizeScale

                botAlpha =
                    lerp 0.9 0.16 lightMix * (1 - 0.35 * dip)

                value =
                    "0 -1px 0 0 rgba(255, 255, 255, "
                        ++ fmtAlpha insetAlpha
                        ++ ") inset, 0 "
                        ++ fmtPx topY
                        ++ " "
                        ++ fmtPx topBlur
                        ++ " "
                        ++ fmtPx topSpread
                        ++ " "
                        ++ rgbPrefix
                        ++ fmtAlpha topAlpha
                        ++ "), 0 "
                        ++ fmtPx botY
                        ++ " "
                        ++ fmtPx botBlur
                        ++ " "
                        ++ fmtPx botSpread
                        ++ " "
                        ++ rgbPrefix
                        ++ fmtAlpha botAlpha
                        ++ ")"
            in
            [ Attr.style "box-shadow" value ]


sheetBackgroundStyle : Theme -> Model -> List (Attribute msg)
sheetBackgroundStyle currentTheme model =
    let
        bgStyle =
            case model.phase of
                Idle ->
                    []

                IntroReveal _ ->
                    []

                _ ->
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
    in
    bgStyle ++ shadowStyle model.shadow


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

        ThemeOut elapsed fromTheme _ ->
            let
                t =
                    clamp 0 1 (elapsed / outMs)

                eased =
                    t * t * (3 - 2 * t)
            in
            renderShader (Theme.isLightFloat fromTheme) eased 0.0

        ThemeMorph _ _ _ ->
            -- Content is 100% covered while both overlay & sheet glide smoothly in lockstep (zero dither on bg, zero flicker!)
            renderShader (currentBgLight currentTheme model) 1.0 0.0

        ThemeIn elapsed targetTheme ->
            let
                t =
                    clamp 0 1 (elapsed / inMs)

                eased =
                    t * t * (3 - 2 * t)
            in
            renderShader (Theme.isLightFloat targetTheme) (1 - eased) 0.0


renderShader : Float -> Float -> Float -> Html msg
renderShader bgLight progress mode =
    WebGL.toHtmlWith
        [ WebGL.alpha True ]
        [ Attr.width 400
        , Attr.height 440
        , Attr.attribute "aria-hidden" "true"
        , Attr.class "absolute inset-0 z-40 block w-full h-full pixel-crisp pointer-events-none select-none"
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
