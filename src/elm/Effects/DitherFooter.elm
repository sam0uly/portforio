module Effects.DitherFooter exposing (Model, Msg, activeRippleCount, init, isAnimating, replayIntro, spawnRipple, tick, update, view, viewSized)

import Data.Theme as Theme exposing (Theme)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import WebGL exposing (Mesh, Shader)


type alias Ripple =
    { x : Float
    , y : Float
    , age : Float
    }


type alias Model =
    { time : Float
    , intro : Float
    , targetMouse : ( Float, Float )
    , smoothMouse : ( Float, Float )
    , hovering : Bool
    , presence : Float
    , ripples : List Ripple
    }


type Msg
    = PointerMove Float Float
    | PointerLeave
    | PointerDown Float Float


rippleDuration : Float
rippleDuration =
    2.1


init : Bool -> Model
init prefersReduced =
    { time = 0
    , intro =
        if prefersReduced then
            1.0

        else
            0.0
    , targetMouse = ( 0.5, 0.35 )
    , smoothMouse = ( 0.5, 0.35 )
    , hovering = False
    , presence = 0
    , ripples = []
    }


isAnimating : Model -> Bool
isAnimating model =
    model.intro
        < 1.0
        || model.hovering
        || model.presence
        > 0.005
        || not (List.isEmpty model.ripples)


activeRippleCount : Model -> Int
activeRippleCount model =
    List.length model.ripples


replayIntro : Model -> Model
replayIntro model =
    { model | intro = 0.0 }


spawnRipple : Float -> Float -> Model -> Model
spawnRipple nx ny model =
    let
        fresh =
            { x = clamp 0 1 nx, y = clamp 0 1 ny, age = 0.0 }
    in
    { model | ripples = fresh :: List.take 3 model.ripples }


update : Msg -> Model -> Model
update msg model =
    case msg of
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

                nextRipples =
                    fresh :: List.take 3 model.ripples
            in
            { model
                | targetMouse = ( nx, ny )
                , hovering = True
                , ripples = nextRipples
            }


tick : Bool -> Float -> Model -> Model
tick motionEnabled dtMs model =
    let
        dt =
            min 0.05 (dtMs / 1000)

        ( tx, ty ) =
            model.targetMouse

        ( sx, sy ) =
            model.smoothMouse

        follow =
            1 - e ^ (-dt / 0.045)

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
                1 - e ^ (-dt / 0.35)

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
            min 1.0 (model.intro + dt / 1.14)
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


touchEndDecoder : Decode.Decoder Msg
touchEndDecoder =
    Decode.field "pointerType" Decode.string
        |> Decode.andThen
            (\kind ->
                if kind == "touch" then
                    Decode.succeed PointerLeave

                else
                    Decode.fail "keep mouse hover"
            )


rippleAt : Int -> List Ripple -> Vec3
rippleAt index list =
    case List.drop index list |> List.head of
        Just r ->
            vec3 r.x r.y r.age

        Nothing ->
            vec3 0.5 0.5 -1.0


view : Theme -> Model -> Html Msg
view theme model =
    viewSized "block w-full h-32 sm:h-auto aspect-[800/210] object-cover object-bottom pixel-crisp cursor-crosshair select-none touch-none" theme model


viewSized : String -> Theme -> Model -> Html Msg
viewSized canvasClass theme model =
    let
        ( mx, my ) =
            model.smoothMouse
    in
    WebGL.toHtmlWith
        [ WebGL.alpha True ]
        [ Attr.width 400
        , Attr.height 105
        , Attr.attribute "role" "img"
        , Attr.attribute "aria-label" "Interactive colorful Bayer-dithered generative wave artwork"
        , Attr.class canvasClass
        , Events.on "pointermove" (pointerDecoder PointerMove)
        , Events.on "pointerleave" (Decode.succeed PointerLeave)
        , Events.on "pointerup" touchEndDecoder
        , Events.on "pointercancel" (Decode.succeed PointerLeave)
        , Events.on "pointerdown" (pointerDecoder PointerDown)
        ]
        [ WebGL.entity
            vertexShader
            fragmentShader
            quadMesh
            { uTime = model.time
            , uResolution = vec2 400 105
            , uMouse = vec2 mx my
            , uPresence = model.presence
            , uRipple0 = rippleAt 0 model.ripples
            , uRipple1 = rippleAt 1 model.ripples
            , uRipple2 = rippleAt 2 model.ripples
            , uRipple3 = rippleAt 3 model.ripples
            , uIsLight = Theme.isLightFloat theme
            , uIntro = model.intro
            }
        ]


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

        vec4 mod289(vec4 x) {
            return x - floor(x * (1.0 / 289.0)) * 289.0;
        }

        vec4 permute(vec4 x) {
            return mod289(((x * 34.0) + 1.0) * x);
        }

        vec4 taylorInvSqrt(vec4 r) {
            return 1.79284291400159 - 0.85373472095314 * r;
        }

        vec2 fade(vec2 t) {
            return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
        }

        float cnoise(vec2 P) {
            vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
            vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
            Pi = mod289(Pi);
            vec4 ix = Pi.xzxz;
            vec4 iy = Pi.yyww;
            vec4 fx = Pf.xzxz;
            vec4 fy = Pf.yyww;
            vec4 i = permute(permute(ix) + iy);
            vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0;
            vec4 gy = abs(gx) - 0.5;
            vec4 tx = floor(gx + 0.5);
            gx = gx - tx;
            vec2 g00 = vec2(gx.x, gy.x);
            vec2 g10 = vec2(gx.y, gy.y);
            vec2 g01 = vec2(gx.z, gy.z);
            vec2 g11 = vec2(gx.w, gy.w);
            vec4 norm = taylorInvSqrt(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
            g00 *= norm.x;
            g01 *= norm.y;
            g10 *= norm.z;
            g11 *= norm.w;
            float n00 = dot(g00, vec2(fx.x, fy.x));
            float n10 = dot(g10, vec2(fx.y, fy.y));
            float n01 = dot(g01, vec2(fx.z, fy.z));
            float n11 = dot(g11, vec2(fx.w, fy.w));
            vec2 fade_xy = fade(Pf.xy);
            vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
            return 2.3 * mix(n_x.x, n_x.y, fade_xy.y);
        }

        float fbm(vec2 p) {
            float value = 0.0;
            float amp = 0.55;
            for (int i = 0; i < 4; i++) {
                value += amp * cnoise(p);
                p = p * 2.02 + vec2(3.1, 1.7);
                amp *= 0.5;
            }
            return value;
        }

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

        vec3 paletteSample(float t, vec3 bg) {
            vec3 c1 = vec3(0.169, 0.333, 0.702);    // #2b55b3 oceania
            vec3 c2 = vec3(0.545, 0.459, 1.000);    // #8b75ff hazy violet
            vec3 c3 = vec3(1.000, 0.310, 0.749);    // #ff4fbf pony pink
            vec3 c4 = vec3(1.000, 0.596, 0.353);    // #ff985a tang coral
            vec3 c5 = vec3(0.361, 0.875, 0.918);    // #5cdfea lichen cyan
            vec3 c6 = vec3(0.071, 0.780, 0.561);    // #12c78f guac emerald

            float s = clamp(t, 0.0, 1.0) * 6.0;
            if (s < 1.0) return mix(bg, c1, s);
            if (s < 2.0) return mix(c1, c2, s - 1.0);
            if (s < 3.0) return mix(c2, c3, s - 2.0);
            if (s < 4.0) return mix(c3, c4, s - 3.0);
            if (s < 5.0) return mix(c4, c5, s - 4.0);
            return mix(c5, c6, s - 5.0);
        }

        void applyRipple(
            vec3 rip,
            vec2 uv,
            vec2 aspectUv,
            float aspect,
            float vScale,
            inout vec2 totalWarp,
            inout float totalBoost,
            inout float totalCrest
        ) {
            float age = rip.z;
            if (age < 0.0 || age >= 2.1) {
                return;
            }
            float ry = rip.y * vScale;
            vec2 aspectRipple = vec2((rip.x - 0.5) * aspect, ry - 0.5);
            vec2 rDiff = aspectUv - aspectRipple;
            float rDist = length(rDiff);
            float life = age / 2.1;
            float fadeOut = (1.0 - life) * (1.0 - life);

            float travel = age * 1.45;
            float broadEnv = exp(-pow((rDist - travel) / 0.46, 2.0)) * fadeOut;
            float waveTrain = sin((rDist - travel) * 14.0);

            totalWarp += normalize(rDiff + 0.0001) * waveTrain * broadEnv * 0.14;
            totalBoost += (0.35 + 0.65 * max(0.0, waveTrain)) * broadEnv * 0.46;

            float hx = abs(uv.x - rip.x);
            float hTravel = age * 0.42;
            float hEnv = exp(-pow((hx - hTravel) / 0.22, 2.0)) * fadeOut;
            totalCrest += sin((hx - hTravel) * 24.0) * hEnv * 0.22;
        }

        void main() {
            // 1:1 Bayer cell per fragment on 400x105 buffer (4x faster GPU shading, bit-identical 2x2 pixels via pixel-crisp!)
            vec2 cell = floor(gl_FragCoord.xy);
            vec2 uv = (cell + 0.5) / uResolution;

            // Exact v3 coordinate space across full 800px container width with transparent headroom above vy = 1.0
            float vScale = 210.0 / 148.0;
            float vy = uv.y * vScale;
            float my = uMouse.y * vScale;
            float aspect = 800.0 / 148.0;

            vec2 aspectUv = vec2((uv.x - 0.5) * aspect, vy - 0.5);
            vec2 aspectMouse = vec2((uMouse.x - 0.5) * aspect, my - 0.5);
            vec2 diff = aspectUv - aspectMouse;
            float dist = length(diff);

            float cAngle = atan(diff.y, diff.x);
            float shapeWobble = 0.028 * sin(cAngle * 3.0 + uTime * 1.1)
                + 0.018 * cos(cAngle * 5.0 - uTime * 0.85)
                + 0.036 * cnoise(vec2(uv.x * 7.5 + uTime * 0.35, vy * 6.0));
            float organicDist = max(0.0, dist + shapeWobble);
            float radialFalloff = clamp(1.0 - organicDist / 0.42, 0.0, 1.0);
            float touch = uPresence * pow(radialFalloff, 1.35);
            float fieldReach = uPresence * (1.0 - smoothstep(0.0, 0.96, dist));

            vec2 attract = -diff * fieldReach * 0.42;
            vec2 swirl = vec2(-diff.y, diff.x) * touch * 0.24;
            vec2 push = normalize(diff + 0.0001) * sin(dist * 18.0 - uTime * 4.5) * 0.014 * touch;

            // 4 independent concurrent wavey ripples so repeated clicks layer and interfere naturally
            vec2 rippleWarp = vec2(0.0);
            float rippleBoost = 0.0;
            float rippleCrestDisp = 0.0;
            applyRipple(uRipple0, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
            applyRipple(uRipple1, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
            applyRipple(uRipple2, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);
            applyRipple(uRipple3, uv, aspectUv, aspect, vScale, rippleWarp, rippleBoost, rippleCrestDisp);

            vec2 p = vec2(uv.x * 2.6, vy * 1.45) + attract + swirl + push + rippleWarp;
            vec2 q = vec2(
                fbm(p + vec2(uTime * 0.08, 0.0)),
                fbm(p + vec2(5.2, 1.3 - uTime * 0.06))
            );
            vec2 r = vec2(
                fbm(p + 1.65 * q + vec2(1.7, 9.2 + uTime * 0.05)),
                fbm(p + 1.65 * q + vec2(8.3, 2.8 - uTime * 0.04))
            );
            float f = fbm(p + 1.4 * r);

            float horizPull = exp(-pow((uv.x - uMouse.x) * 5.9, 2.0));
            float vertProximity = smoothstep(1.50, 0.12, my);
            float magneticLift = uPresence * horizPull * vertProximity * clamp(my - 0.14, 0.0, 0.78) * 1.15;

            float crestHeight = 0.44
                + 0.18 * sin(uv.x * 4.8 + uTime * 0.3)
                + 0.12 * q.x
                + 0.09 * cos(uv.x * 9.5 - uTime * 0.2)
                + magneticLift
                + rippleCrestDisp;

            float waveMask = 1.0 - smoothstep(crestHeight - 0.22, crestHeight + 0.24, vy);

            float introEase = 1.0 - pow(1.0 - clamp(uIntro, 0.0, 1.0), 3.0);
            float introRise = smoothstep(introEase * 1.45, introEase * 1.45 - 0.55, vy);

            // Continuous gradual Bayer density falloff from center outward (no hard inner/outer step)
            float cursorMix = touch * (0.72 + 0.24 * abs(f));
            float intensity = clamp((waveMask * (0.58 + 0.68 * abs(f)) + cursorMix + rippleBoost) * introRise * introEase, 0.0, 1.0);

            float colorCoord = clamp(0.16 + 0.72 * (0.5 + 0.5 * f) + 0.22 * uv.x + 0.16 * r.y + touch * 0.08 + rippleBoost * 0.35, 0.0, 1.0);
            float contour = smoothstep(0.08, 0.0, abs(fract(f * 3.8 + q.y * 0.6) - 0.5));

            vec3 darkBg = vec3(0.0196, 0.0196, 0.0196);
            vec3 lightBg = vec3(0.961, 0.957, 0.941);
            vec3 bg = mix(darkBg, lightBg, uIsLight);

            vec3 ribbonColor = paletteSample(colorCoord, bg);
            ribbonColor = mix(ribbonColor, vec3(1.0, 0.98, 0.945), contour * 0.28 * (1.0 - uIsLight));

            float threshold = bayer8(cell);
            float density = floor(intensity * 5.0 + threshold) / 5.0;

            if (density <= 0.02) {
                gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
            } else {
                vec3 raw = mix(bg, ribbonColor, clamp(density, 0.0, 1.0));
                vec3 quantized = floor(raw * 6.0 + (threshold - 0.5)) / 6.0;
                quantized = clamp(quantized, 0.0, 1.0);
                float a = smoothstep(0.02, 0.32, density);
                gl_FragColor = vec4(quantized * a, a);
            }
        }
    |]
