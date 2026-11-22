module DitherTop exposing (Model, Msg, init, isAnimating, tick, update, view)

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Task
import Theme exposing (Theme)
import WebGL exposing (Mesh, Shader)
import WebGL.Texture as Texture exposing (Texture)


type alias Ripple =
    { x : Float
    , y : Float
    , age : Float
    }


type alias Model =
    { texture : Maybe Texture
    , time : Float
    , intro : Float
    , targetMouse : ( Float, Float )
    , smoothMouse : ( Float, Float )
    , hovering : Bool
    , presence : Float
    , ripples : List Ripple
    }


type Msg
    = TextureLoaded (Result Texture.Error Texture)
    | PointerMove Float Float
    | PointerLeave
    | PointerDown Float Float


rippleDuration : Float
rippleDuration =
    1.4


init : Bool -> ( Model, Cmd Msg )
init prefersReduced =
    let
        texOptions =
            { magnify = Texture.linear
            , minify = Texture.linear
            , horizontalWrap = Texture.clampToEdge
            , verticalWrap = Texture.clampToEdge
            , flipY = True
            }
    in
    ( { texture = Nothing
      , time = 0
      , intro =
            if prefersReduced then
                1.0

            else
                0.0
      , targetMouse = ( 0.5, 0.5 )
      , smoothMouse = ( 0.5, 0.5 )
      , hovering = False
      , presence = 0
      , ripples = []
      }
    , Texture.loadWith texOptions "/images/sam0-avatar.png"
        |> Task.attempt TextureLoaded
    )


isAnimating : Model -> Bool
isAnimating model =
    model.intro
        < 1.0
        || model.hovering
        || model.presence
        > 0.005
        || not (List.isEmpty model.ripples)


update : Msg -> Model -> Model
update msg model =
    case msg of
        TextureLoaded (Ok tex) ->
            { model | texture = Just tex }

        TextureLoaded (Err _) ->
            model

        PointerMove nx ny ->
            { model
                | targetMouse = ( nx, ny )
                , hovering = True
            }

        PointerLeave ->
            { model | hovering = False }

        PointerDown nx ny ->
            let
                fresh =
                    { x = nx, y = ny, age = 0.0 }
            in
            { model
                | targetMouse = ( nx, ny )
                , hovering = True
                , ripples = fresh :: List.take 3 model.ripples
            }


tick : Bool -> Float -> Model -> Model
tick motionEnabled dtMs model =
    if not (isAnimating model) then
        model

    else
        let
            dt =
                min 0.05 (dtMs / 1000)

            ( tx, ty ) =
                model.targetMouse

            ( sx, sy ) =
                model.smoothMouse

            follow =
                1 - e ^ (-dt / 0.07)

            nextSmooth =
                ( sx + (tx - sx) * follow
                , sy + (ty - sy) * follow
                )

            targetPresence =
                if model.hovering then
                    1

                else
                    0

            presenceRate =
                if model.hovering then
                    1 - e ^ (-dt / 0.12)

                else
                    1 - e ^ (-dt / 0.32)

            nextPresence =
                model.presence + (targetPresence - model.presence) * presenceRate

            nextRipples =
                model.ripples
                    |> List.map (\r -> { r | age = r.age + dt })
                    |> List.filter (\r -> r.age < rippleDuration)

            nextTime =
                if motionEnabled then
                    model.time + dt

                else
                    model.time

            nextIntro =
                min 1.0 (model.intro + dt / 0.92)
        in
        { model
            | time = nextTime
            , intro = nextIntro
            , smoothMouse = nextSmooth
            , presence =
                if nextPresence < 0.002 && not model.hovering then
                    0

                else
                    nextPresence
            , ripples = nextRipples
        }


pointerDecoder : (Float -> Float -> Msg) -> Decode.Decoder Msg
pointerDecoder toMsg =
    Decode.map4
        (\ox oy cw ch ->
            let
                w =
                    max 1 cw

                h =
                    max 1 ch

                nx =
                    clamp 0 1 (ox / w)

                ny =
                    clamp 0 1 (1 - (oy / h))
            in
            toMsg nx ny
        )
        (Decode.field "offsetX" Decode.float)
        (Decode.field "offsetY" Decode.float)
        (Decode.at [ "currentTarget", "clientWidth" ] Decode.float)
        (Decode.at [ "currentTarget", "clientHeight" ] Decode.float)


rippleAt : Int -> List Ripple -> Vec3
rippleAt index list =
    case List.drop index list |> List.head of
        Just r ->
            vec3 r.x r.y r.age

        Nothing ->
            vec3 0.5 0.5 -1.0


view : Theme -> Model -> Html Msg
view theme model =
    let
        ( mx, my ) =
            model.smoothMouse

        entities =
            case model.texture of
                Just tex ->
                    [ WebGL.entity
                        vertexShader
                        fragmentShader
                        quadMesh
                        { uTime = model.time
                        , uResolution = vec2 128 128
                        , uMouse = vec2 mx my
                        , uPresence = model.presence
                        , uRipple0 = rippleAt 0 model.ripples
                        , uRipple1 = rippleAt 1 model.ripples
                        , uRipple2 = rippleAt 2 model.ripples
                        , uRipple3 = rippleAt 3 model.ripples
                        , uIsLight = Theme.isLightFloat theme
                        , uIntro = model.intro
                        , uMask = tex
                        }
                    ]

                Nothing ->
                    []
    in
    WebGL.toHtmlWith
        [ WebGL.alpha True ]
        [ Attr.width 128
        , Attr.height 128
        , Attr.attribute "role" "img"
        , Attr.attribute "aria-label" "Interactive dithered portrait of Alaa El-Samouly"
        , Attr.class "block size-20 sm:size-28 shrink-0 cursor-crosshair select-none touch-manipulation"
        , Events.on "pointermove" (pointerDecoder PointerMove)
        , Events.on "pointerleave" (Decode.succeed PointerLeave)
        , Events.on "pointerdown" (pointerDecoder PointerDown)
        ]
        entities


type alias Vertex =
    { position : Vec2
    }


quadMesh : Mesh Vertex
quadMesh =
    WebGL.triangles
        [ ( Vertex (vec2 -1 -1)
          , Vertex (vec2 3 -1)
          , Vertex (vec2 -1 3)
          )
        ]


type alias Uniforms =
    { uTime : Float
    , uResolution : Vec2
    , uMouse : Vec2
    , uPresence : Float
    , uRipple0 : Vec3
    , uRipple1 : Vec3
    , uRipple2 : Vec3
    , uRipple3 : Vec3
    , uIsLight : Float
    , uIntro : Float
    , uMask : Texture
    }


vertexShader : Shader Vertex Uniforms { vUv : Vec2 }
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

        uniform float uTime;
        uniform vec2 uResolution;
        uniform vec2 uMouse;
        uniform float uPresence;
        uniform vec3 uRipple0;
        uniform vec3 uRipple1;
        uniform vec3 uRipple2;
        uniform vec3 uRipple3;
        uniform float uIsLight;
        uniform float uIntro;
        uniform sampler2D uMask;

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

        void applyRipple(vec3 rip, vec2 uv, inout float totalRing, inout vec2 totalPush) {
            float age = rip.z;
            if (age < 0.0 || age >= 1.4) {
                return;
            }
            vec2 rDiff = uv - rip.xy;
            float rDist = length(rDiff);
            float life = age / 1.4;
            float ring = exp(-pow((rDist - age * 0.9) / 0.09, 2.0)) * (1.0 - life) * (1.0 - life);
            totalRing += ring;
            totalPush += normalize(rDiff + 0.0001) * ring * 0.04;
        }

        void main() {
            float pixelSize = 2.0;
            vec2 cell = floor(gl_FragCoord.xy / pixelSize);
            vec2 uv = (cell * pixelSize + 0.5 * pixelSize) / uResolution;

            vec2 diff = uv - uMouse;
            float dist = length(diff);
            float touch = uPresence * (1.0 - smoothstep(0.0, 0.52, dist));

            // Stronger demagnetic repulsion + tactile swirl & wave ripple
            vec2 dir = normalize(diff + 0.0001);
            vec2 repel = -dir * touch * 0.065;
            vec2 swirl = vec2(-diff.y, diff.x) * touch * 0.28;
            vec2 push = dir * sin(dist * 22.0 - uTime * 5.0) * 0.030 * touch;

            // 4 concurrent independent click ripples (never resets active waves on rapid clicks)
            float clickRing = 0.0;
            applyRipple(uRipple0, uv, clickRing, push);
            applyRipple(uRipple1, uv, clickRing, push);
            applyRipple(uRipple2, uv, clickRing, push);
            applyRipple(uRipple3, uv, clickRing, push);

            vec2 sampleUv = clamp(uv + repel + swirl + push, 0.0, 1.0);
            vec4 tex = texture2D(uMask, sampleUv);

            // Gentle arched Bayer fade anchored right at the jacket hem (no flat ____, minimal height lost)
            float xEdge = abs(uv.x - 0.5) * 2.0;
            float hemStart = 0.09 + 0.07 * pow(xEdge, 1.7);
            float bottomArc = smoothstep(hemStart, hemStart + 0.085, uv.y);
            float radial = 1.0 - smoothstep(0.36, 0.50, length(uv - vec2(0.5, 0.5)));

            float introEase = uIntro * uIntro * (3.0 - 2.0 * uIntro);
            float field = clamp((tex.a * bottomArc + touch * 0.22 * radial + clickRing * 0.45 * radial) * introEase, 0.0, 1.0);

            float threshold = bayer8(cell);
            float density = floor(field * 4.0 + threshold) / 4.0;

            if (density <= 0.02) {
                gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
            } else {
                vec3 darkBg = vec3(0.0196, 0.0196, 0.0196);
                vec3 lightBg = vec3(0.961, 0.957, 0.941);
                vec3 bg = mix(darkBg, lightBg, uIsLight);

                vec3 avatarRgb = mix(tex.rgb * 0.94 + vec3(0.055, 0.055, 0.075), tex.rgb, uIsLight);
                vec3 charm = mix(vec3(0.545, 0.459, 1.0), vec3(1.0, 0.31, 0.75), uv.x);

                // Keep true avatar colors inside silhouette; outer hover & click ripple shine in Charmtone pinky-violet
                vec3 fg = mix(charm, avatarRgb, smoothstep(0.15, 0.45, tex.a));
                float a = smoothstep(0.02, 0.28, density);

                gl_FragColor = vec4(mix(bg, fg, density) * a, a);
            }
        }
    |]
