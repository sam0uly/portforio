module Features.NotFound exposing
    ( Mode(..)
    , Model
    , Msg
    , init
    , isAnimating
    , tick
    , update
    , view
    )

import Data.Theme as Theme exposing (Theme(..))
import Html exposing (Html, a, button, div, h1, p, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Set exposing (Set)
import Svg exposing (circle, defs, g, line, path, polygon, polyline, radialGradient, rect, stop, svg, text_)
import Svg.Attributes as SvgAttr
import WebGL exposing (Mesh, Shader)


arenaW : Float
arenaW =
    640


arenaH : Float
arenaH =
    340


paddleY : Float
paddleY =
    310


paddleW : Float
paddleW =
    96


paddleH : Float
paddleH =
    11


ballR : Float
ballR =
    6.5


type Mode
    = ModeSmash
    | ModeGravity
    | ModeDive
    | ModeSynth
    | ModeClaw
    | ModeEyes
    | ModePlane
    | ModeBlackhole
    | ModeAurora
    | ModeWormhole


type GravityMode
    = GravFall
    | GravZeroG
    | GravMagnet


type ClawPhase
    = ClawIdle
    | ClawDropping
    | ClawGrabbing Float
    | ClawRising
    | ClawCarrying
    | ClawReleasing Float


type alias Brick =
    { id : Int, x : Float, y : Float, w : Float, h : Float, color : String, alive : Bool }


type alias Ball =
    { x : Float, y : Float, vx : Float, vy : Float, color : String, trail : List ( Float, Float ) }


type alias Spark =
    { x : Float, y : Float, vx : Float, vy : Float, color : String, life : Float }


type alias PhysTile =
    { id : Int, homeX : Float, homeY : Float, x : Float, y : Float, vx : Float, vy : Float, rot : Float, vrot : Float, w : Float, h : Float, color : String }


type alias Relic =
    { id : Int, label : String, x : Float, y : Float, color : String, found : Bool }


type alias Bubble =
    { x : Float, y : Float, r : Float, speed : Float, phase : Float }


type alias Capsule =
    { id : Int, label : String, x : Float, y : Float, color : String, fg : String, grabbed : Bool, won : Bool }


type alias Creature =
    { id : Int, x : Float, y : Float, size : Float, color : String, bounce : Float, dizzy : Float, blink : Float }


type alias Plane =
    { x : Float, y : Float, vx : Float, vy : Float, color : String, trail : List ( Float, Float ), age : Float }


type alias SkyRing =
    { id : Int, label : String, x : Float, y : Float, baseY : Float, r : Float, color : String, popped : Float }


type alias Flare =
    { slot : Int, x : Float, y : Float, age : Float }


type alias Model =
    { mode : Mode
    , time : Float
    , seed : Int
    -- Smash
    , bricks : List Brick
    , balls : List Ball
    , sparks : List Spark
    , paddleX : Float
    , targetPaddleX : Float
    , score : Int
    , combo : Int
    , bestCombo : Int
    , shake : Float
    , cleared : Bool
    -- Gravity
    , tiles : List PhysTile
    , gravMode : GravityMode
    , gravPointer : Maybe ( Float, Float )
    -- Dive
    , diverX : Float
    , diverY : Float
    , targetDiverX : Float
    , targetDiverY : Float
    , relics : List Relic
    , bubbles : List Bubble
    -- Synth
    , synthCells : Set ( Int, Int )
    , synthStep : Int
    , synthAccum : Float
    , synthPlaying : Bool
    , synthMuted : Bool
    -- Claw
    , clawX : Float
    , targetClawX : Float
    , clawY : Float
    , clawPhase : ClawPhase
    , capsules : List Capsule
    , wonList : List String
    -- Eyes
    , eyeX : Float
    , eyeY : Float
    , creatures : List Creature
    , speech : Maybe ( Int, String, Float )
    -- Plane
    , aimX : Float
    , aimY : Float
    , planes : List Plane
    , rings : List SkyRing
    , ringsPopped : Int
    -- WebGL Arts (Blackhole / Aurora / Wormhole)
    , artTargetMouse : ( Float, Float )
    , artSmoothMouse : ( Float, Float )
    , artHovering : Bool
    , artPresence : Float
    , flares : List Flare
    , nextFlareSlot : Int
    , artOverdrive : Bool
    }


type Msg
    = SetMode Mode
    -- Smash
    | SmashMove Float
    | SmashSpawnBall
    | SmashReset
    -- Gravity
    | GravMove Float Float
    | GravLeave
    | GravBlast Float Float
    | GravSetMode GravityMode
    | GravExplode
    -- Dive
    | DiveMove Float Float
    | DiveClick Float Float
    | DiveReset
    -- Synth
    | SynthToggleCell Int Int
    | SynthTogglePlay
    | SynthToggleMute
    | SynthPreset404
    | SynthRandom
    | SynthClear
    -- Claw
    | ClawMove Float
    | ClawDrop
    | ClawReset
    -- Eyes
    | EyesMove Float Float
    | EyesPoke Float Float
    | EyesWave
    -- Plane
    | PlaneAim Float Float
    | PlaneLaunch Float Float
    | PlaneBarrage
    | PlaneReset
    -- WebGL Arts
    | ArtMove Float Float
    | ArtLeave
    | ArtPulse Float Float
    | ArtBurst
    | ArtToggleOverdrive


brickBlueprint : List ( Int, Int, String )
brickBlueprint =
    let
        digit4 colOff color =
            [ ( 0, 0 ), ( 0, 1 ), ( 0, 2 ), ( 0, 3 )
            , ( 1, 3 ), ( 2, 3 ), ( 3, 3 ), ( 4, 3 )
            , ( 3, 0 ), ( 3, 1 ), ( 3, 2 ), ( 3, 4 ), ( 3, 5 ), ( 3, 6 )
            ]
                |> List.map (\( c, r ) -> ( c + colOff, r, color ))

        digit0 colOff color =
            [ ( 1, 0 ), ( 2, 0 ), ( 3, 0 )
            , ( 0, 1 ), ( 4, 1 )
            , ( 0, 2 ), ( 3, 2 ), ( 4, 2 )
            , ( 0, 3 ), ( 2, 3 ), ( 4, 3 )
            , ( 0, 4 ), ( 1, 4 ), ( 4, 4 )
            , ( 0, 5 ), ( 4, 5 )
            , ( 1, 6 ), ( 2, 6 ), ( 3, 6 )
            ]
                |> List.map (\( c, r ) -> ( c + colOff, r, color ))
    in
    digit4 0 "#b8a8ff" ++ digit0 6 "#7ee7be" ++ digit4 12 "#ffc482"


initialBricks : List Brick
initialBricks =
    let
        originX =
            (arenaW - (17 * 30 - 4)) / 2
    in
    List.indexedMap
        (\idx ( col, row, color ) ->
            { id = idx, x = originX + toFloat col * 30, y = 38 + toFloat row * 20, w = 26, h = 16, color = color, alive = True }
        )
        brickBlueprint


initialTiles : List PhysTile
initialTiles =
    let
        originX =
            (arenaW - (17 * 30 - 4)) / 2
    in
    List.indexedMap
        (\idx ( col, row, color ) ->
            let
                hx =
                    originX + toFloat col * 30

                hy =
                    88 + toFloat row * 22
            in
            { id = idx, homeX = hx, homeY = hy, x = hx, y = hy, vx = toFloat (modBy 7 idx - 3) * 18, vy = -(toFloat (modBy 5 idx)) * 14, rot = 0, vrot = toFloat (modBy 5 idx - 2) * 16, w = 26, h = 18, color = color }
        )
        brickBlueprint


initialRelics : List Relic
initialRelics =
    [ { id = 0, label = "4", x = 112, y = 225, color = "#b8a8ff", found = False }
    , { id = 1, label = "0", x = 315, y = 112, color = "#7ee7be", found = False }
    , { id = 2, label = "4", x = 518, y = 248, color = "#ffc482", found = False }
    , { id = 3, label = "✦", x = 218, y = 282, color = "#b8a8ff", found = False }
    , { id = 4, label = "⚡", x = 442, y = 96, color = "#7ee7be", found = False }
    ]


initialBubbles : List Bubble
initialBubbles =
    List.range 0 15
        |> List.map (\i -> { x = toFloat (modBy 16 (i * 5 + 2)) * 40 + 18, y = toFloat (modBy 11 (i * 3 + 1)) * 31, r = 2.2 + toFloat (modBy 4 i) * 1.4, speed = 20 + toFloat (modBy 5 i) * 9, phase = toFloat i * 0.9 })


initialSynthSet : Set ( Int, Int )
initialSynthSet =
    brickBlueprint |> List.map (\( c, r, _ ) -> ( c, r )) |> Set.fromList


initialCapsules : List Capsule
initialCapsules =
    [ { id = 0, label = "404", x = 185, y = 290, color = "#b8a8ff", fg = "#120d26", grabbed = False, won = False }
    , { id = 1, label = "home", x = 258, y = 296, color = "#7ee7be", fg = "#0a2018", grabbed = False, won = False }
    , { id = 2, label = "bug", x = 330, y = 286, color = "#ffc482", fg = "#261405", grabbed = False, won = False }
    , { id = 3, label = "blog", x = 402, y = 295, color = "#b8a8ff", fg = "#120d26", grabbed = False, won = False }
    , { id = 4, label = "nix", x = 474, y = 288, color = "#7ee7be", fg = "#0a2018", grabbed = False, won = False }
    , { id = 5, label = "tea", x = 546, y = 294, color = "#ffc482", fg = "#261405", grabbed = False, won = False }
    , { id = 6, label = "go", x = 222, y = 252, color = "#ffc482", fg = "#261405", grabbed = False, won = False }
    , { id = 7, label = "elm", x = 368, y = 248, color = "#7ee7be", fg = "#0a2018", grabbed = False, won = False }
    , { id = 8, label = "★", x = 508, y = 250, color = "#b8a8ff", fg = "#120d26", grabbed = False, won = False }
    ]


initialCreatures : List Creature
initialCreatures =
    let
        palette =
            [ "#b8a8ff", "#7ee7be", "#ffc482", "#8b75ff", "#5cdfea" ]

        colAt i =
            palette |> List.drop (modBy 5 i) |> List.head |> Maybe.withDefault "#b8a8ff"
    in
    List.range 0 3
        |> List.concatMap
            (\r ->
                List.range 0 7
                    |> List.map
                        (\c ->
                            let
                                idx =
                                    r * 8 + c
                            in
                            { id = idx
                            , x = 56 + toFloat c * 75 + toFloat (modBy 5 (idx * 3) - 2) * 5
                            , y = 54 + toFloat r * 76 + toFloat (modBy 5 (idx * 7) - 2) * 4
                            , size = 44 + toFloat (modBy 4 (idx * 5)) * 4
                            , color = colAt (idx + r * 2)
                            , bounce = 0
                            , dizzy = 0
                            , blink = 0
                            }
                        )
            )


initialRings : List SkyRing
initialRings =
    [ { id = 0, label = "4", x = 250, y = 115, baseY = 115, r = 28, color = "#b8a8ff", popped = 0 }
    , { id = 1, label = "0", x = 385, y = 175, baseY = 175, r = 30, color = "#7ee7be", popped = 0 }
    , { id = 2, label = "4", x = 520, y = 105, baseY = 105, r = 28, color = "#ffc482", popped = 0 }
    , { id = 3, label = "✦", x = 470, y = 245, baseY = 245, r = 24, color = "#b8a8ff", popped = 0 }
    ]


makeBall : Int -> Float -> Ball
makeBall seed startX =
    let
        col =
            [ "#f4f4f6", "#b8a8ff", "#7ee7be", "#ffc482" ] |> List.drop (modBy 4 seed) |> List.head |> Maybe.withDefault "#f4f4f6"

        dir =
            if modBy 2 seed == 0 then
                1

            else
                -1
    in
    { x = clamp (ballR + 12) (arenaW - ballR - 12) startX, y = paddleY - ballR - 6, vx = dir * (145 + toFloat (modBy 5 seed) * 18), vy = -255, color = col, trail = [] }


init : Model
init =
    { mode = ModeSmash
    , time = 0
    , seed = 1
    , bricks = initialBricks
    , balls = [ makeBall 0 (arenaW / 2) ]
    , sparks = []
    , paddleX = arenaW / 2
    , targetPaddleX = arenaW / 2
    , score = 0
    , combo = 0
    , bestCombo = 0
    , shake = 0
    , cleared = False
    , tiles = initialTiles
    , gravMode = GravZeroG
    , gravPointer = Nothing
    , diverX = arenaW / 2
    , diverY = arenaH / 2
    , targetDiverX = arenaW / 2
    , targetDiverY = arenaH / 2
    , relics = initialRelics
    , bubbles = initialBubbles
    , synthCells = initialSynthSet
    , synthStep = 0
    , synthAccum = 0
    , synthPlaying = True
    , synthMuted = False
    , clawX = 320
    , targetClawX = 320
    , clawY = 54
    , clawPhase = ClawIdle
    , capsules = initialCapsules
    , wonList = []
    , eyeX = arenaW / 2
    , eyeY = arenaH / 2
    , creatures = initialCreatures
    , speech = Nothing
    , aimX = 240
    , aimY = 150
    , planes = []
    , rings = initialRings
    , ringsPopped = 0
    , artTargetMouse = ( 0.5, 0.5 )
    , artSmoothMouse = ( 0.5, 0.5 )
    , artHovering = False
    , artPresence = 0
    , flares = []
    , nextFlareSlot = 0
    , artOverdrive = False
    }


isAnimating : Bool -> Model -> Bool
isAnimating motionPlaying model =
    case model.mode of
        ModeSynth ->
            motionPlaying && model.synthPlaying

        ModeClaw ->
            motionPlaying || model.clawPhase /= ClawIdle

        _ ->
            motionPlaying || not (List.isEmpty model.sparks) || not (List.isEmpty model.flares) || not (List.isEmpty model.planes)


addArtFlare : Float -> Float -> Model -> Model
addArtFlare nx ny model =
    let
        slot =
            modBy 8 model.nextFlareSlot

        fresh =
            { slot = slot, x = nx, y = ny, age = 0.0 }
    in
    { model
        | flares = fresh :: List.filter (\f -> f.slot /= slot) model.flares
        , nextFlareSlot = slot + 1
    }


launchPlaneFrom : Int -> Float -> Float -> Plane
launchPlaneFrom seed tx ty =
    let
        dx =
            tx - 64

        dy =
            ty - 258

        d =
            max 24 (sqrt (dx * dx + dy * dy))

        power =
            clamp 320 620 (d * 2.1)

        col =
            [ "#b8a8ff", "#7ee7be", "#ffc482", "#f4f4f6" ] |> List.drop (modBy 4 seed) |> List.head |> Maybe.withDefault "#b8a8ff"
    in
    { x = 64, y = 258, vx = (dx / d) * power, vy = (dy / d) * power, color = col, trail = [], age = 0 }


quipAt : Int -> String
quipAt idx =
    let
        qs =
            [ "not here!", "404?", "it ran left →", "check /blog!", "whoops", "boop!", "lost again?", "try home!" ]
    in
    qs |> List.drop (modBy (List.length qs) idx) |> List.head |> Maybe.withDefault "404!"


update : Msg -> Model -> ( Model, List Int )
update msg model =
    case msg of
        SetMode m ->
            ( { model | mode = m }, [] )

        -- Smash
        SmashMove normX ->
            ( { model | targetPaddleX = clamp (paddleW / 2 + 8) (arenaW - paddleW / 2 - 8) (normX * arenaW) }, [] )

        SmashSpawnBall ->
            if model.cleared then
                ( { model | bricks = initialBricks, balls = [ makeBall 0 (arenaW / 2) ], sparks = [], score = 0, combo = 0, bestCombo = 0, cleared = False }, [] )

            else if List.length model.balls >= 4 then
                ( model, [] )

            else
                ( { model | balls = makeBall model.seed model.paddleX :: model.balls, seed = model.seed + 1 }, [] )

        SmashReset ->
            ( { model | bricks = initialBricks, balls = [ makeBall 0 (arenaW / 2) ], sparks = [], score = 0, combo = 0, bestCombo = 0, cleared = False }, [] )

        -- Gravity
        GravMove nx ny ->
            ( { model | gravPointer = Just ( nx * arenaW, ny * arenaH ) }, [] )

        GravLeave ->
            ( { model | gravPointer = Nothing }, [] )

        GravBlast nx ny ->
            let
                bx =
                    nx * arenaW

                by =
                    ny * arenaH
            in
            ( { model
                | tiles =
                    List.map
                        (\t ->
                            let
                                dx =
                                    (t.x + t.w / 2) - bx

                                dy =
                                    (t.y + t.h / 2) - by

                                d =
                                    max 18 (sqrt (dx * dx + dy * dy))

                                force =
                                    min 520 (95000 / (d * d))
                            in
                            { t | vx = t.vx + (dx / d) * force, vy = t.vy + (dy / d) * force - 80, vrot = t.vrot + ((dx - dy) / d) * 220 }
                        )
                        model.tiles
              }
            , []
            )

        GravSetMode gm ->
            ( { model | gravMode = gm }, [] )

        GravExplode ->
            ( { model
                | gravMode = GravFall
                , tiles =
                    List.map
                        (\t ->
                            let
                                dx =
                                    (t.x + t.w / 2) - arenaW / 2

                                dy =
                                    (t.y + t.h / 2) - arenaH / 2

                                d =
                                    max 12 (sqrt (dx * dx + dy * dy))

                                boost =
                                    260 + toFloat (modBy 5 t.id) * 45
                            in
                            { t | vx = (dx / d) * boost, vy = (dy / d) * boost - 140, vrot = toFloat (modBy 9 t.id - 4) * 95 }
                        )
                        model.tiles
              }
            , []
            )

        -- Dive
        DiveMove nx ny ->
            ( { model | targetDiverX = clamp 20 (arenaW - 20) (nx * arenaW), targetDiverY = clamp 20 (arenaH - 20) (ny * arenaH) }, [] )

        DiveClick nx ny ->
            let
                cx =
                    nx * arenaW

                cy =
                    ny * arenaH

                nextRelics =
                    List.map
                        (\r ->
                            if not r.found && (r.x - cx) ^ 2 + (r.y - cy) ^ 2 <= 44 * 44 then
                                { r | found = True }

                            else
                                r
                        )
                        model.relics
            in
            ( { model | relics = nextRelics, targetDiverX = clamp 20 (arenaW - 20) cx, targetDiverY = clamp 20 (arenaH - 20) cy }, [] )

        DiveReset ->
            ( { model | relics = initialRelics }, [] )

        -- Synth
        SynthToggleCell col row ->
            let
                key =
                    ( col, row )
            in
            if Set.member key model.synthCells then
                ( { model | synthCells = Set.remove key model.synthCells }, [] )

            else
                ( { model | synthCells = Set.insert key model.synthCells }
                , if model.synthMuted then
                    []

                  else
                    [ row ]
                )

        SynthTogglePlay ->
            ( { model | synthPlaying = not model.synthPlaying }, [] )

        SynthToggleMute ->
            ( { model | synthMuted = not model.synthMuted }, [] )

        SynthPreset404 ->
            ( { model | synthCells = initialSynthSet, synthStep = 0, synthAccum = 0 }, [] )

        SynthRandom ->
            let
                nextSeed =
                    model.seed + 7

                genSet =
                    List.range 0 16
                        |> List.concatMap (\c -> List.range 0 6 |> List.filterMap (\r -> if modBy 11 (c * 7 + r * 13 + nextSeed * 3) < 3 then Just ( c, r ) else Nothing))
                        |> Set.fromList
            in
            ( { model | synthCells = genSet, seed = nextSeed }, [] )

        SynthClear ->
            ( { model | synthCells = Set.empty }, [] )

        -- Claw
        ClawMove normX ->
            case model.clawPhase of
                ClawIdle ->
                    ( { model | targetClawX = clamp 155 (arenaW - 44) (normX * arenaW) }, [] )

                _ ->
                    ( model, [] )

        ClawDrop ->
            case model.clawPhase of
                ClawIdle ->
                    ( { model | clawPhase = ClawDropping }, [ 4 ] )

                _ ->
                    ( model, [] )

        ClawReset ->
            ( { model | clawPhase = ClawIdle, clawX = 320, targetClawX = 320, clawY = 54, capsules = initialCapsules, wonList = [] }, [] )

        -- Eyes
        EyesMove nx ny ->
            ( { model | eyeX = nx * arenaW, eyeY = ny * arenaH }, [] )

        EyesPoke nx ny ->
            let
                px =
                    nx * arenaW

                py =
                    ny * arenaH

                nearest =
                    model.creatures |> List.sortBy (\c -> (c.x - px) ^ 2 + (c.y - py) ^ 2) |> List.head

                nextCreatures =
                    List.map
                        (\c ->
                            let
                                d =
                                    sqrt ((c.x - px) ^ 2 + (c.y - py) ^ 2)
                            in
                            if d < 125 then
                                { c | bounce = min 1.0 (c.bounce + (1 - d / 125) * 1.1), dizzy = if d < 46 then 1.4 else c.dizzy }

                            else
                                c
                        )
                        model.creatures
            in
            ( { model | creatures = nextCreatures, speech = Maybe.map (\c -> ( c.id, quipAt model.seed, 1.8 )) nearest, seed = model.seed + 1 }, [ modBy 5 model.seed ] )

        EyesWave ->
            ( { model | creatures = List.map (\c -> { c | bounce = 0.75 + toFloat (modBy 4 c.id) * 0.1, dizzy = 1.6 }) model.creatures, speech = Just ( 11, "whoaaa!!", 2.0 ), seed = model.seed + 1 }, [ 0, 2, 4 ] )

        -- Plane
        PlaneAim nx ny ->
            ( { model | aimX = nx * arenaW, aimY = ny * arenaH }, [] )

        PlaneLaunch nx ny ->
            let
                tx =
                    nx * arenaW

                ty =
                    ny * arenaH
            in
            ( { model | aimX = tx, aimY = ty, planes = launchPlaneFrom model.seed tx ty :: List.take 7 model.planes, seed = model.seed + 1 }, [ 3 ] )

        PlaneBarrage ->
            ( { model | planes = [ launchPlaneFrom model.seed 320 90, launchPlaneFrom (model.seed + 1) 420 140, launchPlaneFrom (model.seed + 2) 380 210 ] ++ List.take 5 model.planes, seed = model.seed + 3 }, [ 1, 3 ] )

        PlaneReset ->
            ( { model | planes = [], rings = initialRings, ringsPopped = 0 }, [] )

        -- WebGL Arts
        ArtMove nx ny ->
            ( { model | artTargetMouse = ( nx, 1 - ny ), artHovering = True }, [] )

        ArtLeave ->
            ( { model | artHovering = False }, [] )

        ArtPulse nx ny ->
            ( addArtFlare nx (1 - ny) { model | artTargetMouse = ( nx, 1 - ny ), artHovering = True }, [] )

        ArtBurst ->
            let
                ( fx, fy ) =
                    case modBy 4 model.nextFlareSlot of
                        0 -> ( 0.22, 0.68 )
                        1 -> ( 0.78, 0.34 )
                        2 -> ( 0.30, 0.28 )
                        _ -> ( 0.72, 0.72 )
            in
            ( addArtFlare fx fy model, [] )

        ArtToggleOverdrive ->
            ( { model | artOverdrive = not model.artOverdrive }, [] )


spawnSparks : Int -> Float -> Float -> String -> List Spark
spawnSparks seed cx cy color =
    List.range 0 6
        |> List.map
            (\i ->
                let
                    ang =
                        (toFloat i / 7.0) * 2 * pi + toFloat (modBy 11 (seed + i * 3)) * 0.25

                    spd =
                        75 + toFloat (modBy 5 (seed + i * 2)) * 32
                in
                { x = cx, y = cy, vx = cos ang * spd, vy = sin ang * spd - 40, color = color, life = 1.0 }
            )


tick : Bool -> Float -> Model -> ( Model, List Int )
tick motionEnabled dtMs model =
    if not motionEnabled then
        ( model, [] )

    else
        let
            dt =
                min 0.032 (dtMs / 1000)

            base =
                { model | time = model.time + dt }
        in
        case model.mode of
            ModeSmash ->
                ( tickSmash dt base, [] )

            ModeGravity ->
                ( tickGravity dt base, [] )

            ModeDive ->
                ( tickDive dt base, [] )

            ModeSynth ->
                tickSynth dt base

            ModeClaw ->
                tickClaw dt base

            ModeEyes ->
                ( tickEyes dt base, [] )

            ModePlane ->
                tickPlane dt base

            ModeBlackhole ->
                ( tickArt dt base, [] )

            ModeAurora ->
                ( tickArt dt base, [] )

            ModeWormhole ->
                ( tickArt dt base, [] )


tickArt : Float -> Model -> Model
tickArt rawDt model =
    let
        dt =
            rawDt
                * (if model.artOverdrive then
                    1.9

                   else
                    1.0
                  )

        ( tx, ty ) =
            model.artTargetMouse

        ( sx, sy ) =
            model.artSmoothMouse

        follow =
            1 - e ^ (-rawDt / 0.06)

        presRate =
            1 - e ^ (-rawDt / (if model.artHovering then 0.12 else 0.38))

        nextPres =
            model.artPresence + ((if model.artHovering then 1 else 0) - model.artPresence) * presRate
    in
    { model
        | time = model.time + (dt - rawDt)
        , artSmoothMouse = ( sx + (tx - sx) * follow, sy + (ty - sy) * follow )
        , artPresence = if nextPres < 0.002 && not model.artHovering then 0 else nextPres
        , flares = model.flares |> List.map (\f -> { f | age = f.age + dt }) |> List.filter (\f -> f.age < 2.6)
    }


tickSmash : Float -> Model -> Model
tickSmash dt model =
    let
        nextPaddleX =
            model.paddleX + (model.targetPaddleX - model.paddleX) * (1 - e ^ (-dt / 0.028))

        stepOneBall ball acc =
            let
                nx0 =
                    ball.x + ball.vx * dt

                ny0 =
                    ball.y + ball.vy * dt

                ( nx, vx1 ) =
                    if nx0 < ballR then
                        ( ballR, abs ball.vx )

                    else if nx0 > arenaW - ballR then
                        ( arenaW - ballR, -(abs ball.vx) )

                    else
                        ( nx0, ball.vx )

                ( ny, vy1 ) =
                    if ny0 < ballR then
                        ( ballR, abs ball.vy )

                    else
                        ( ny0, ball.vy )

                halfP =
                    paddleW / 2

                hitsPaddle =
                    vy1 > 0 && ny + ballR >= paddleY && ny - ballR <= paddleY + paddleH && nx >= nextPaddleX - halfP - ballR * 0.5 && nx <= nextPaddleX + halfP + ballR * 0.5

                paddleStep =
                    if hitsPaddle then
                        let
                            offset =
                                clamp -1 1 ((nx - nextPaddleX) / halfP)

                            speed =
                                min 420 (max 285 (sqrt (vx1 * vx1 + vy1 * vy1) * 1.015))

                            ang =
                                offset * 1.08
                        in
                        { vy = -(cos ang) * speed, vx = sin ang * speed, ny = paddleY - ballR - 0.5, hit = True }

                    else
                        { vy = vy1, vx = vx1, ny = ny, hit = False }

                checkBricks bricksLeft checked =
                    case bricksLeft of
                        [] ->
                            ( List.reverse checked, Nothing )

                        b :: rest ->
                            if not b.alive then
                                checkBricks rest (b :: checked)

                            else
                                let
                                    dx =
                                        nx - clamp b.x (b.x + b.w) nx

                                    dy =
                                        paddleStep.ny - clamp b.y (b.y + b.h) paddleStep.ny
                                in
                                if dx * dx + dy * dy <= ballR * ballR then
                                    ( List.reverse checked ++ ({ b | alive = False } :: rest), Just ( b, abs dx > abs dy ) )

                                else
                                    checkBricks rest (b :: checked)

                ( nextBricks, hitResult ) =
                    checkBricks acc.bricks []

                hitStep =
                    case hitResult of
                        Just ( b, flipX ) ->
                            let
                                newCombo =
                                    acc.combo + 1
                            in
                            { vx = if flipX then -paddleStep.vx else paddleStep.vx
                            , vy = if flipX then paddleStep.vy else -paddleStep.vy
                            , sparks = spawnSparks acc.seed (b.x + b.w / 2) (b.y + b.h / 2) b.color ++ acc.sparks
                            , score = acc.score + 10 * newCombo
                            , combo = newCombo
                            , shake = min 5.0 (acc.shake + 2.4)
                            , seed = acc.seed + 1
                            }

                        Nothing ->
                            { vx = paddleStep.vx, vy = paddleStep.vy, sparks = acc.sparks, score = acc.score, combo = if paddleStep.hit then 0 else acc.combo, shake = acc.shake, seed = acc.seed }

                fellOut =
                    paddleStep.ny - ballR > arenaH + 14

                updatedBall =
                    { ball | x = nx, y = paddleStep.ny, vx = hitStep.vx, vy = hitStep.vy, trail = ( nx, paddleStep.ny ) :: List.take 5 ball.trail }
            in
            { bricks = nextBricks
            , balls = if fellOut then acc.balls else updatedBall :: acc.balls
            , sparks = hitStep.sparks
            , score = hitStep.score
            , combo = hitStep.combo
            , bestCombo = max acc.bestCombo hitStep.combo
            , shake = hitStep.shake
            , seed = hitStep.seed
            }

        stepped =
            List.foldl stepOneBall { bricks = model.bricks, balls = [], sparks = model.sparks, score = model.score, combo = model.combo, bestCombo = model.bestCombo, shake = max 0 (model.shake - dt * 18), seed = model.seed } model.balls

        finalBalls =
            if List.isEmpty stepped.balls then
                [ makeBall stepped.seed nextPaddleX ]

            else
                List.reverse stepped.balls
    in
    { model
        | bricks = stepped.bricks
        , balls = finalBalls
        , sparks = stepped.sparks |> List.map (\s -> { s | x = s.x + s.vx * dt, y = s.y + s.vy * dt, vy = s.vy + 260 * dt, life = s.life - dt * 1.65 }) |> List.filter (\s -> s.life > 0) |> List.take 80
        , paddleX = nextPaddleX
        , score = stepped.score
        , combo = if List.isEmpty stepped.balls then 0 else stepped.combo
        , bestCombo = stepped.bestCombo
        , shake = stepped.shake
        , seed = stepped.seed + 1
        , cleared = (stepped.bricks |> List.filter .alive |> List.length) == 0
    }


tickGravity : Float -> Model -> Model
tickGravity dt model =
    let
        stepTile t =
            let
                ( ptrAx, ptrAy ) =
                    case model.gravPointer of
                        Just ( px, py ) ->
                            let
                                dx = (t.x + t.w / 2) - px
                                dy = (t.y + t.h / 2) - py
                                d = max 18 (sqrt (dx * dx + dy * dy))
                            in
                            if d < 110 then
                                let push = (1 - d / 110) * 680 in
                                ( (dx / d) * push, (dy / d) * push )
                            else
                                ( 0, 0 )
                        Nothing ->
                            ( 0, 0 )

                force =
                    case model.gravMode of
                        GravFall -> { ax = ptrAx, ay = 560 + ptrAy, damp = 0.992, snapRot = False }
                        GravZeroG -> { ax = ptrAx + sin (model.time * 0.9 + toFloat t.id) * 14, ay = ptrAy + cos (model.time * 0.8 + toFloat t.id) * 14, damp = 0.988, snapRot = False }
                        GravMagnet -> { ax = (t.homeX - t.x) * 34 + ptrAx * 0.5, ay = (t.homeY - t.y) * 34 + ptrAy * 0.5, damp = 0.84, snapRot = True }

                vx1 = (t.vx + force.ax * dt) * force.damp
                vy1 = (t.vy + force.ay * dt) * force.damp
                x1 = t.x + vx1 * dt
                y1 = t.y + vy1 * dt
                ( x2, vx2 ) = if x1 < 6 then ( 6, abs vx1 * 0.68 ) else if x1 + t.w > arenaW - 6 then ( arenaW - 6 - t.w, -(abs vx1) * 0.68 ) else ( x1, vx1 )
                ( y2, vy2, vrotFloor ) = if y1 < 6 then ( 6, abs vy1 * 0.65, t.vrot ) else if y1 + t.h > arenaH - 6 then ( arenaH - 6 - t.h, -(abs vy1) * 0.58, t.vrot * 0.82 ) else ( y1, vy1, t.vrot * 0.985 )
                ( nextRot, nextVrot ) = if force.snapRot then ( t.rot * 0.82, 0 ) else ( t.rot + vrotFloor * dt, vrotFloor )
            in
            { t | x = x2, y = y2, vx = vx2, vy = vy2, rot = nextRot, vrot = nextVrot }
    in
    { model | tiles = List.map stepTile model.tiles }


tickDive : Float -> Model -> Model
tickDive dt model =
    let
        follow =
            1 - e ^ (-dt / 0.06)
    in
    { model
        | diverX = model.diverX + (model.targetDiverX - model.diverX) * follow
        , diverY = model.diverY + (model.targetDiverY - model.diverY) * follow
        , bubbles = List.map (\b -> let by = b.y - b.speed * dt in { b | y = if by < -10 then arenaH + 10 else by }) model.bubbles
    }


tickSynth : Float -> Model -> ( Model, List Int )
tickSynth dt model =
    if not model.synthPlaying then
        ( model, [] )
    else
        let accum = model.synthAccum + dt in
        if accum >= 0.145 then
            let
                nextStep = modBy 17 (model.synthStep + 1)
                activeRows = if model.synthMuted then [] else List.range 0 6 |> List.filter (\r -> Set.member ( nextStep, r ) model.synthCells)
            in
            ( { model | synthStep = nextStep, synthAccum = accum - 0.145 }, activeRows )
        else
            ( { model | synthAccum = accum }, [] )


tickClaw : Float -> Model -> ( Model, List Int )
tickClaw dt model =
    case model.clawPhase of
        ClawIdle ->
            ( { model | clawX = model.clawX + (model.targetClawX - model.clawX) * (1 - e ^ (-dt / 0.05)) }, [] )

        ClawDropping ->
            let
                ny = model.clawY + 230 * dt
                hitCap = model.capsules |> List.filter (\c -> not c.won && abs (c.x - model.clawX) < 30 && abs (c.y - (ny + 22)) < 24) |> List.head
            in
            case hitCap of
                Just cap ->
                    ( { model | clawY = ny, clawPhase = ClawGrabbing 0.25, capsules = List.map (\c -> if c.id == cap.id then { c | grabbed = True } else c) model.capsules }, [ 2 ] )
                Nothing ->
                    if ny >= 274 then ( { model | clawY = 274, clawPhase = ClawGrabbing 0.25 }, [] ) else ( { model | clawY = ny }, [] )

        ClawGrabbing t ->
            ( { model | clawPhase = if t - dt <= 0 then ClawRising else ClawGrabbing (t - dt) }, [] )

        ClawRising ->
            let
                ny = max 54 (model.clawY - 200 * dt)
                syncCaps = List.map (\c -> if c.grabbed then { c | x = model.clawX, y = ny + 26 } else c) model.capsules
            in
            if ny <= 54 then
                ( { model | clawY = 54, capsules = syncCaps, clawPhase = if List.any .grabbed syncCaps then ClawCarrying else ClawIdle }, [] )
            else
                ( { model | clawY = ny, capsules = syncCaps }, [] )

        ClawCarrying ->
            let
                nx = max 76 (model.clawX - 240 * dt)
                syncCaps = List.map (\c -> if c.grabbed then { c | x = nx, y = model.clawY + 26 } else c) model.capsules
            in
            if nx <= 76 then
                let
                    wonNow = syncCaps |> List.filter .grabbed |> List.map .label
                    released = List.map (\c -> if c.grabbed then { c | grabbed = False, won = True } else c) syncCaps
                in
                ( { model | clawX = 76, targetClawX = 76, capsules = released, wonList = wonNow ++ model.wonList, clawPhase = ClawReleasing 0.35 }, [ 0, 2 ] )
            else
                ( { model | clawX = nx, capsules = syncCaps }, [] )

        ClawReleasing t ->
            ( { model | clawPhase = if t - dt <= 0 then ClawIdle else ClawReleasing (t - dt) }, [] )


tickEyes : Float -> Model -> Model
tickEyes dt model =
    { model
        | creatures =
            List.map
                (\c ->
                    { c
                        | bounce = max 0 (c.bounce - dt * 2.8)
                        , dizzy = max 0 (c.dizzy - dt * 1.1)
                        , blink = if sin (model.time * 0.8 + toFloat c.id * 2.3) > 0.992 then 1.0 else max 0 (c.blink - dt * 6.5)
                    }
                )
                model.creatures
        , speech =
            case model.speech of
                Just ( cid, txt, t ) -> if t - dt <= 0 then Nothing else Just ( cid, txt, t - dt )
                Nothing -> Nothing
    }


tickPlane : Float -> Model -> ( Model, List Int )
tickPlane dt model =
    let
        movedRings =
            List.map (\r -> { r | y = r.baseY + sin (model.time * 1.5 + toFloat r.id * 1.7) * 18, popped = max 0 (r.popped - dt * 1.2) }) model.rings

        stepPlane p acc =
            let
                vy1 = p.vy + 185 * dt
                vx1 = p.vx * (1 - 0.12 * dt)
                nx = p.x + vx1 * dt
                ny = p.y + vy1 * dt
                checkRing ring ( ringsAcc, poppedCount, notesAcc ) =
                    if ring.popped > 0.1 then
                        ( ring :: ringsAcc, poppedCount, notesAcc )
                    else if (nx - ring.x) ^ 2 + (ny - ring.y) ^ 2 <= (ring.r + 8) ^ 2 then
                        ( { ring | popped = 1.0 } :: ringsAcc, poppedCount + 1, modBy 5 ring.id :: notesAcc )
                    else
                        ( ring :: ringsAcc, poppedCount, notesAcc )
                ( nextRings, gotPop, gotNotes ) = List.foldr checkRing ( [], 0, [] ) acc.rings
                offscreen = nx > arenaW + 40 || nx < -40 || ny > arenaH + 40 || ny < -80 || p.age > 5.0
                updated = { p | x = nx, y = ny, vx = vx1, vy = vy1, trail = ( nx, ny ) :: List.take 16 p.trail, age = p.age + dt }
            in
            { planes = if offscreen then acc.planes else updated :: acc.planes, rings = nextRings, popped = acc.popped + gotPop, notes = gotNotes ++ acc.notes }

        stepped = List.foldl stepPlane { planes = [], rings = movedRings, popped = 0, notes = [] } model.planes
    in
    ( { model | planes = List.reverse stepped.planes, rings = stepped.rings, ringsPopped = model.ringsPopped + stepped.popped }, stepped.notes )


focusRing : String
focusRing =
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--page-fg)] focus-visible:ring-offset-4 focus-visible:ring-offset-[var(--page-bg)]"


onInternalLinkClick : msg -> Html.Attribute msg
onInternalLinkClick msg =
    Events.preventDefaultOn "click"
        (Decode.map4
            (\ctrl meta shift alt -> if ctrl || meta || shift || alt then Decode.fail "mod" else Decode.succeed ( msg, True ))
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
            (Decode.field "shiftKey" Decode.bool)
            (Decode.field "altKey" Decode.bool)
            |> Decode.andThen identity
        )


pointerXDecoder : (Float -> msg) -> Decode.Decoder msg
pointerXDecoder toMsg =
    Decode.map2 (\ox cw -> toMsg (clamp 0 1 (ox / max 1 cw)))
        (Decode.field "offsetX" Decode.float)
        (Decode.at [ "currentTarget", "clientWidth" ] Decode.float)


pointerXYDecoder : (Float -> Float -> msg) -> Decode.Decoder msg
pointerXYDecoder toMsg =
    Decode.map4 (\ox oy cw ch -> toMsg (clamp 0 1 (ox / max 1 cw)) (clamp 0 1 (oy / max 1 ch)))
        (Decode.field "offsetX" Decode.float)
        (Decode.field "offsetY" Decode.float)
        (Decode.at [ "currentTarget", "clientWidth" ] Decode.float)
        (Decode.at [ "currentTarget", "clientHeight" ] Decode.float)


flareSlot : Int -> List Flare -> Vec3
flareSlot slotIdx list =
    case List.filter (\f -> f.slot == slotIdx) list |> List.head of
        Just f -> vec3 f.x f.y f.age
        Nothing -> vec3 0.5 0.5 -1.0


-- ARENAS


viewSmashArena : Theme -> Model -> Html Msg
viewSmashArena theme model =
    let
        shakeX = if model.shake > 0.2 then sin (toFloat model.seed * 1.7) * model.shake else 0
        shakeY = if model.shake > 0.2 then cos (toFloat model.seed * 2.3) * model.shake * 0.7 else 0
        paddleFill = if theme == Dark then "#f4f4f6" else "#14141a"
    in
    svg [ SvgAttr.viewBox "0 0 640 340", SvgAttr.class "block w-full h-auto cursor-none touch-none select-none", Events.on "pointermove" (pointerXDecoder SmashMove), Events.on "pointerdown" (Decode.succeed SmashSpawnBall) ]
        [ g [ SvgAttr.transform ("translate(" ++ String.fromFloat shakeX ++ "," ++ String.fromFloat shakeY ++ ")") ]
            (List.map (\b -> if not b.alive then g [] [] else rect [ SvgAttr.x (String.fromFloat b.x), SvgAttr.y (String.fromFloat b.y), SvgAttr.width (String.fromFloat b.w), SvgAttr.height (String.fromFloat b.h), SvgAttr.rx "5", SvgAttr.fill b.color ] []) model.bricks
                ++ List.map (\s -> rect [ SvgAttr.x (String.fromFloat (s.x - 2.5)), SvgAttr.y (String.fromFloat (s.y - 2.5)), SvgAttr.width "5", SvgAttr.height "5", SvgAttr.rx "1.2", SvgAttr.fill s.color, SvgAttr.opacity (String.fromFloat (clamp 0 1 s.life)) ] []) model.sparks
                ++ List.map (\b -> g [] (List.indexedMap (\i ( tx, ty ) -> let frac = 1 - toFloat (i + 1) / 7.0 in circle [ SvgAttr.cx (String.fromFloat tx), SvgAttr.cy (String.fromFloat ty), SvgAttr.r (String.fromFloat (ballR * frac * 0.85)), SvgAttr.fill b.color, SvgAttr.opacity (String.fromFloat (frac * 0.32)) ] []) b.trail ++ [ circle [ SvgAttr.cx (String.fromFloat b.x), SvgAttr.cy (String.fromFloat b.y), SvgAttr.r (String.fromFloat ballR), SvgAttr.fill (if b.color == "#f4f4f6" && theme == Light then "#14141a" else b.color) ] [] ])) model.balls
                ++ [ rect [ SvgAttr.x (String.fromFloat (model.paddleX - paddleW / 2)), SvgAttr.y (String.fromFloat paddleY), SvgAttr.width (String.fromFloat paddleW), SvgAttr.height (String.fromFloat paddleH), SvgAttr.rx "5.5", SvgAttr.fill paddleFill ] [] ]
            )
        ]


viewGravityArena : Model -> Html Msg
viewGravityArena model =
    svg [ SvgAttr.viewBox "0 0 640 340", SvgAttr.class "block w-full h-auto cursor-crosshair touch-none select-none", Events.on "pointermove" (pointerXYDecoder GravMove), Events.on "pointerleave" (Decode.succeed GravLeave), Events.on "pointerdown" (pointerXYDecoder GravBlast) ]
        (List.map (\t -> rect [ SvgAttr.x (String.fromFloat t.x), SvgAttr.y (String.fromFloat t.y), SvgAttr.width (String.fromFloat t.w), SvgAttr.height (String.fromFloat t.h), SvgAttr.rx "5", SvgAttr.fill t.color, SvgAttr.transform ("rotate(" ++ String.fromFloat t.rot ++ " " ++ String.fromFloat (t.x + t.w / 2) ++ " " ++ String.fromFloat (t.y + t.h / 2) ++ ")") ] []) model.tiles
            ++ (case model.gravPointer of
                    Just ( px, py ) -> [ circle [ SvgAttr.cx (String.fromFloat px), SvgAttr.cy (String.fromFloat py), SvgAttr.r "36", SvgAttr.fill "none", SvgAttr.stroke "var(--callout-note-bg)", SvgAttr.strokeWidth "1", SvgAttr.strokeDasharray "4 4", SvgAttr.opacity "0.45" ] [] ]
                    Nothing -> []
               )
        )


viewDiveArena : Model -> Html Msg
viewDiveArena model =
    let
        depthM = round (12 + (model.diverY / arenaH) * 28)
    in
    svg [ SvgAttr.viewBox "0 0 640 340", SvgAttr.class "block w-full h-auto cursor-crosshair touch-none select-none", Events.on "pointermove" (pointerXYDecoder DiveMove), Events.on "pointerdown" (pointerXYDecoder DiveClick) ]
        [ defs []
            [ radialGradient [ SvgAttr.id "dive-beam", SvgAttr.cx (String.fromFloat (model.diverX / arenaW)), SvgAttr.cy (String.fromFloat (model.diverY / arenaH)), SvgAttr.r "0.30" ]
                [ stop [ SvgAttr.offset "0%", SvgAttr.stopColor "#7ee7be", SvgAttr.stopOpacity "0.26" ] []
                , stop [ SvgAttr.offset "55%", SvgAttr.stopColor "#8b75ff", SvgAttr.stopOpacity "0.09" ] []
                , stop [ SvgAttr.offset "100%", SvgAttr.stopColor "#050711", SvgAttr.stopOpacity "0" ] []
                ]
            ]
        , rect [ SvgAttr.x "0", SvgAttr.y "0", SvgAttr.width "640", SvgAttr.height "340", SvgAttr.fill "#060913" ] []
        , path [ SvgAttr.d "M0 305 Q120 278 240 296 T480 288 T640 302 L640 340 L0 340 Z", SvgAttr.fill "#0c1224" ] []
        , rect [ SvgAttr.x "0", SvgAttr.y "0", SvgAttr.width "640", SvgAttr.height "340", SvgAttr.fill "url(#dive-beam)" ] []
        , g [] (List.map (\b -> circle [ SvgAttr.cx (String.fromFloat (b.x + sin (model.time * 1.4 + b.phase) * 7)), SvgAttr.cy (String.fromFloat b.y), SvgAttr.r (String.fromFloat b.r), SvgAttr.fill "none", SvgAttr.stroke "#7ee7be", SvgAttr.strokeWidth "1", SvgAttr.opacity "0.28" ] []) model.bubbles)
        , g []
            (List.map
                (\r ->
                    let
                        dist = sqrt ((r.x - model.diverX) ^ 2 + (r.y - model.diverY) ^ 2)
                        vis = if r.found then 1.0 else clamp 0.04 1.0 (1.0 - (dist - 35) / 110)
                        bob = sin (model.time * 2.2 + toFloat r.id * 1.4) * 4
                    in
                    g [ SvgAttr.transform ("translate(" ++ String.fromFloat r.x ++ "," ++ String.fromFloat (r.y + bob) ++ ")"), SvgAttr.opacity (String.fromFloat vis) ]
                        [ circle [ SvgAttr.cx "0", SvgAttr.cy "0", SvgAttr.r "16", SvgAttr.fill r.color, SvgAttr.opacity "0.2" ] []
                        , rect [ SvgAttr.x "-12", SvgAttr.y "-12", SvgAttr.width "24", SvgAttr.height "24", SvgAttr.rx "7", SvgAttr.fill r.color ] []
                        , text_ [ SvgAttr.x "0", SvgAttr.y "4.5", SvgAttr.textAnchor "middle", SvgAttr.fontFamily "var(--font-mono)", SvgAttr.fontSize "12", SvgAttr.fontWeight "700", SvgAttr.fill "#0b0d18" ] [ Svg.text r.label ]
                        ]
                )
                model.relics
            )
        , circle [ SvgAttr.cx (String.fromFloat model.diverX), SvgAttr.cy (String.fromFloat model.diverY), SvgAttr.r "5", SvgAttr.fill "#7ee7be" ] []
        , text_ [ SvgAttr.x "16", SvgAttr.y "24", SvgAttr.fontFamily "var(--font-mono)", SvgAttr.fontSize "10.5", SvgAttr.fill "#7ee7be", SvgAttr.opacity "0.75" ] [ Svg.text ("depth · -" ++ String.fromInt depthM ++ "m") ]
        ]


viewSynthArena : Model -> Html Msg
viewSynthArena model =
    let
        originX = (arenaW - (17 * 33 - 5)) / 2
        originY = (arenaH - (7 * 31 - 5)) / 2
        colColor col = if col < 5 then "#b8a8ff" else if col < 11 then "#7ee7be" else "#ffc482"
    in
    svg [ SvgAttr.viewBox "0 0 640 340", SvgAttr.class "block w-full h-auto select-none" ]
        (rect [ SvgAttr.x (String.fromFloat (originX + toFloat model.synthStep * 33 - 2)), SvgAttr.y (String.fromFloat (originY - 6)), SvgAttr.width "32", SvgAttr.height (String.fromFloat (7 * 31 + 7)), SvgAttr.rx "8", SvgAttr.fill "var(--callout-note-bg)", SvgAttr.opacity "0.10" ] []
            :: (List.range 0 16
                    |> List.concatMap
                        (\c ->
                            List.range 0 6
                                |> List.map
                                    (\r ->
                                        let
                                            isOn = Set.member ( c, r ) model.synthCells
                                            isHead = c == model.synthStep && model.synthPlaying
                                            fillCol = if isOn then colColor c else if isHead then "var(--tab-bg)" else "var(--surface-2)"
                                        in
                                        rect [ SvgAttr.x (String.fromFloat (originX + toFloat c * 33)), SvgAttr.y (String.fromFloat (originY + toFloat r * 31)), SvgAttr.width "28", SvgAttr.height "26", SvgAttr.rx "6", SvgAttr.fill fillCol, SvgAttr.class "cursor-pointer", Events.onClick (SynthToggleCell c r) ] []
                                    )
                        )
               )
        )


viewClawArena : Model -> Html Msg
viewClawArena model =
    let
        isClosed = case model.clawPhase of
            ClawGrabbing _ -> True
            ClawRising -> True
            ClawCarrying -> True
            _ -> False
        spread = if isClosed then 11 else 22
        cx = model.clawX
        cy = model.clawY
    in
    svg [ SvgAttr.viewBox "0 0 640 340", SvgAttr.class "block w-full h-auto cursor-ew-resize touch-none select-none", Events.on "pointermove" (pointerXDecoder ClawMove), Events.on "pointerdown" (Decode.succeed ClawDrop) ]
        ([ rect [ SvgAttr.x "20", SvgAttr.y "18", SvgAttr.width "600", SvgAttr.height "6", SvgAttr.rx "3", SvgAttr.fill "var(--tab-bg)" ] []
         , rect [ SvgAttr.x "24", SvgAttr.y "215", SvgAttr.width "104", SvgAttr.height "110", SvgAttr.rx "14", SvgAttr.fill "var(--surface-2)", SvgAttr.stroke "var(--page-line)", SvgAttr.strokeWidth "1.5" ] []
         , text_ [ SvgAttr.x "76", SvgAttr.y "266", SvgAttr.textAnchor "middle", SvgAttr.fontFamily "var(--font-mono)", SvgAttr.fontSize "10", SvgAttr.fill "var(--page-subtle)" ] [ Svg.text "prize chute" ]
         , text_ [ SvgAttr.x "76", SvgAttr.y "284", SvgAttr.textAnchor "middle", SvgAttr.fontFamily "var(--font-mono)", SvgAttr.fontSize "11", SvgAttr.fill "var(--callout-note-bg)" ] [ Svg.text (String.fromInt (List.length model.wonList) ++ " / 9") ]
         , rect [ SvgAttr.x "140", SvgAttr.y "318", SvgAttr.width "480", SvgAttr.height "6", SvgAttr.rx "3", SvgAttr.fill "var(--tab-bg)" ] []
         ]
            ++ List.map (\c -> if c.won then g [] [] else g [ SvgAttr.transform ("translate(" ++ String.fromFloat c.x ++ "," ++ String.fromFloat c.y ++ ")") ] [ rect [ SvgAttr.x "-24", SvgAttr.y "-18", SvgAttr.width "48", SvgAttr.height "36", SvgAttr.rx "12", SvgAttr.fill c.color ] [], text_ [ SvgAttr.x "0", SvgAttr.y "4", SvgAttr.textAnchor "middle", SvgAttr.fontFamily "var(--font-mono)", SvgAttr.fontSize "11", SvgAttr.fontWeight "600", SvgAttr.fill c.fg ] [ Svg.text c.label ] ]) model.capsules
            ++ [ line [ SvgAttr.x1 (String.fromFloat cx), SvgAttr.y1 "24", SvgAttr.x2 (String.fromFloat cx), SvgAttr.y2 (String.fromFloat cy), SvgAttr.stroke "var(--page-subtle)", SvgAttr.strokeWidth "2" ] []
               , rect [ SvgAttr.x (String.fromFloat (cx - 18)), SvgAttr.y "13", SvgAttr.width "36", SvgAttr.height "16", SvgAttr.rx "5", SvgAttr.fill "var(--page-fg)" ] []
               , circle [ SvgAttr.cx (String.fromFloat cx), SvgAttr.cy (String.fromFloat cy), SvgAttr.r "6", SvgAttr.fill "var(--page-fg)" ] []
               , polyline [ SvgAttr.points (String.fromFloat (cx - 4) ++ "," ++ String.fromFloat (cy + 3) ++ " " ++ String.fromFloat (cx - spread) ++ "," ++ String.fromFloat (cy + 18) ++ " " ++ String.fromFloat (cx - spread + 7) ++ "," ++ String.fromFloat (cy + 32)), SvgAttr.fill "none", SvgAttr.stroke "var(--page-fg)", SvgAttr.strokeWidth "3", SvgAttr.strokeLinecap "round", SvgAttr.strokeLinejoin "round" ] []
               , polyline [ SvgAttr.points (String.fromFloat (cx + 4) ++ "," ++ String.fromFloat (cy + 3) ++ " " ++ String.fromFloat (cx + spread) ++ "," ++ String.fromFloat (cy + 18) ++ " " ++ String.fromFloat (cx + spread - 7) ++ "," ++ String.fromFloat (cy + 32)), SvgAttr.fill "none", SvgAttr.stroke "var(--page-fg)", SvgAttr.strokeWidth "3", SvgAttr.strokeLinecap "round", SvgAttr.strokeLinejoin "round" ] []
               ]
        )


viewEyesArena : Model -> Html Msg
viewEyesArena model =
    let
        viewCreature c =
            let
                jumpY = -(sin (c.bounce * pi)) * 18
                dx = model.eyeX - c.x
                dy = model.eyeY - (c.y + jumpY)
                ang = if c.dizzy > 0 then model.time * 14 + toFloat c.id else atan2 dy dx
                look = min 4.2 (sqrt (dx * dx + dy * dy) / 28)
                px = cos ang * look
                py = sin ang * look
                half = c.size / 2
                eyeH = max 1.2 (9.5 * (1 - c.blink * 0.88))
            in
            g [ SvgAttr.transform ("translate(" ++ String.fromFloat c.x ++ "," ++ String.fromFloat (c.y + jumpY) ++ ")") ]
                [ rect [ SvgAttr.x (String.fromFloat -half), SvgAttr.y (String.fromFloat -half), SvgAttr.width (String.fromFloat c.size), SvgAttr.height (String.fromFloat c.size), SvgAttr.rx "14", SvgAttr.fill c.color ] []
                , rect [ SvgAttr.x "-13", SvgAttr.y (String.fromFloat (-2 - eyeH / 2)), SvgAttr.width "10.5", SvgAttr.height (String.fromFloat eyeH), SvgAttr.rx "5", SvgAttr.fill "#ffffff" ] []
                , rect [ SvgAttr.x "2.5", SvgAttr.y (String.fromFloat (-2 - eyeH / 2)), SvgAttr.width "10.5", SvgAttr.height (String.fromFloat eyeH), SvgAttr.rx "5", SvgAttr.fill "#ffffff" ] []
                , if c.blink < 0.6 then
                    g [] [ circle [ SvgAttr.cx (String.fromFloat (-7.75 + px)), SvgAttr.cy (String.fromFloat (-2 + py)), SvgAttr.r "3.2", SvgAttr.fill "#0e0e14" ] [], circle [ SvgAttr.cx (String.fromFloat (7.75 + px)), SvgAttr.cy (String.fromFloat (-2 + py)), SvgAttr.r "3.2", SvgAttr.fill "#0e0e14" ] [] ]
                  else g [] []
                , if c.bounce > 0.25 || c.dizzy > 0.2 then
                    circle [ SvgAttr.cx "0", SvgAttr.cy "10", SvgAttr.r "3", SvgAttr.fill "#0e0e14" ] []
                  else
                    path [ SvgAttr.d "M -4 9 Q 0 13 4 9", SvgAttr.fill "none", SvgAttr.stroke "#0e0e14", SvgAttr.strokeWidth "1.8", SvgAttr.strokeLinecap "round" ] []
                ]

        speechBubble =
            case model.speech of
                Just ( cid, txt, _ ) ->
                    case model.creatures |> List.filter (\c -> c.id == cid) |> List.head of
                        Just c ->
                            [ g [ SvgAttr.transform ("translate(" ++ String.fromFloat (clamp 70 (arenaW - 70) c.x) ++ "," ++ String.fromFloat (max 28 (c.y - c.size / 2 - 18)) ++ ")") ]
                                [ rect [ SvgAttr.x "-48", SvgAttr.y "-13", SvgAttr.width "96", SvgAttr.height "24", SvgAttr.rx "9", SvgAttr.fill "var(--page-fg)" ] []
                                , text_ [ SvgAttr.x "0", SvgAttr.y "3", SvgAttr.textAnchor "middle", SvgAttr.fontFamily "var(--font-mono)", SvgAttr.fontSize "10.5", SvgAttr.fontWeight "600", SvgAttr.fill "var(--page-bg)" ] [ Svg.text txt ]
                                ]
                            ]
                        Nothing -> []
                Nothing -> []
    in
    svg [ SvgAttr.viewBox "0 0 640 340", SvgAttr.class "block w-full h-auto cursor-pointer touch-none select-none", Events.on "pointermove" (pointerXYDecoder EyesMove), Events.on "pointerdown" (pointerXYDecoder EyesPoke) ]
        (List.map viewCreature model.creatures ++ speechBubble)


viewPlaneArena : Model -> Html Msg
viewPlaneArena model =
    svg [ SvgAttr.viewBox "0 0 640 340", SvgAttr.class "block w-full h-auto cursor-crosshair touch-none select-none", Events.on "pointermove" (pointerXYDecoder PlaneAim), Events.on "pointerdown" (pointerXYDecoder PlaneLaunch) ]
        ([ line [ SvgAttr.x1 "64", SvgAttr.y1 "258", SvgAttr.x2 (String.fromFloat (64 + (model.aimX - 64) * 0.45)), SvgAttr.y2 (String.fromFloat (258 + (model.aimY - 258) * 0.45)), SvgAttr.stroke "var(--page-subtle)", SvgAttr.strokeWidth "1.5", SvgAttr.strokeDasharray "4 5", SvgAttr.opacity "0.65" ] []
         , circle [ SvgAttr.cx "64", SvgAttr.cy "258", SvgAttr.r "14", SvgAttr.fill "var(--tab-bg)" ] []
         , polygon [ SvgAttr.points "72,258 56,252 59,258 56,264", SvgAttr.fill "var(--callout-note-bg)" ] []
         ]
            ++ List.map (\r -> g [ SvgAttr.transform ("translate(" ++ String.fromFloat r.x ++ "," ++ String.fromFloat r.y ++ ") scale(" ++ String.fromFloat (1 + r.popped * 0.6) ++ ")"), SvgAttr.opacity (String.fromFloat (if r.popped > 0 then 1 - r.popped else 0.95)) ] [ circle [ SvgAttr.cx "0", SvgAttr.cy "0", SvgAttr.r (String.fromFloat r.r), SvgAttr.fill "none", SvgAttr.stroke r.color, SvgAttr.strokeWidth "3", SvgAttr.strokeDasharray "6 4" ] [], text_ [ SvgAttr.x "0", SvgAttr.y "5", SvgAttr.textAnchor "middle", SvgAttr.fontFamily "var(--font-mono)", SvgAttr.fontSize "14", SvgAttr.fontWeight "700", SvgAttr.fill r.color ] [ Svg.text r.label ] ]) model.rings
            ++ List.map (\p -> g [] [ polyline [ SvgAttr.points (p.trail |> List.map (\( tx, ty ) -> String.fromFloat tx ++ "," ++ String.fromFloat ty) |> String.join " "), SvgAttr.fill "none", SvgAttr.stroke p.color, SvgAttr.strokeWidth "1.8", SvgAttr.strokeDasharray "3 5", SvgAttr.opacity "0.55" ] [], g [ SvgAttr.transform ("translate(" ++ String.fromFloat p.x ++ "," ++ String.fromFloat p.y ++ ") rotate(" ++ String.fromFloat (atan2 p.vy p.vx * (180 / pi)) ++ ")") ] [ polygon [ SvgAttr.points "14,0 -10,-8 -6,0 -10,8", SvgAttr.fill p.color ] [], line [ SvgAttr.x1 "-6", SvgAttr.y1 "0", SvgAttr.x2 "14", SvgAttr.y2 "0", SvgAttr.stroke "#0e0e14", SvgAttr.strokeWidth "1" ] [] ] ]) model.planes
        )


viewArtArena : Float -> Theme -> Model -> Html Msg
viewArtArena artMode theme model =
    let
        ( mx, my ) = model.artSmoothMouse
    in
    div [ Attr.class "relative w-full aspect-[640/340]" ]
        [ WebGL.toHtmlWith
            [ WebGL.alpha False ]
            [ Attr.width 520
            , Attr.height 276
            , Attr.attribute "role" "img"
            , Attr.attribute "aria-label" "Interactive Bayer-dithered generative WebGL art"
            , Attr.class "block w-full h-full object-cover pixel-crisp cursor-crosshair touch-none select-none"
            , Events.on "pointermove" (pointerXYDecoder ArtMove)
            , Events.on "pointerleave" (Decode.succeed ArtLeave)
            , Events.on "pointerdown" (pointerXYDecoder ArtPulse)
            ]
            [ WebGL.entity
                artVertexShader
                artFragmentShader
                artQuadMesh
                { uTime = model.time
                , uResolution = vec2 520 276
                , uMouse = vec2 mx my
                , uPresence = model.artPresence
                , uFlare0 = flareSlot 0 model.flares
                , uFlare1 = flareSlot 1 model.flares
                , uFlare2 = flareSlot 2 model.flares
                , uFlare3 = flareSlot 3 model.flares
                , uFlare4 = flareSlot 4 model.flares
                , uFlare5 = flareSlot 5 model.flares
                , uFlare6 = flareSlot 6 model.flares
                , uFlare7 = flareSlot 7 model.flares
                , uArtMode = artMode
                , uOverdrive = if model.artOverdrive then 1.0 else 0.0
                , uIsLight = Theme.isLightFloat theme
                }
            ]
        , if artMode < 0.5 then
            div [ Attr.class "pointer-events-none absolute inset-0 flex flex-col items-center justify-center text-center" ]
                [ span [ Attr.class "font-display font-semibold text-xl text-[#f4f4f6] light:text-[#120d26]" ] [ text "404" ]
                , span [ Attr.class "font-mono text-[9.5px] tracking-[0.16em] text-[#b8a8ff]/80 light:text-[#443299]/80" ] [ text "event horizon" ]
                ]
          else
            text ""
        ]


view :
    { toMsg : Msg -> msg
    , onBackHome : msg
    , onOpenBlog : msg
    , onToggleTheme : msg
    , onToggleMotion : msg
    , theme : Theme
    , motionPlaying : Bool
    , currentYear : String
    }
    -> String
    -> Model
    -> Html msg
view cfg missingPath model =
    let
        modePill target label =
            button
                [ Attr.type_ "button"
                , Events.onClick (cfg.toMsg (SetMode target))
                , Attr.class
                    ("px-2.5 py-1 btn-squircle font-mono text-[10.5px] cursor-pointer transition-colors duration-150 "
                        ++ (if model.mode == target then
                                "bg-[var(--tab-bg)] text-[var(--page-fg)] font-medium"
                            else
                                "bg-[var(--surface-2)] hover:bg-[var(--tab-bg)]/60 text-[var(--page-subtle)] hover:text-[var(--page-fg)]"
                           )
                        ++ " "
                        ++ focusRing
                    )
                ]
                [ text label ]

        ( headline, hintText, modeControls ) =
            case model.mode of
                ModeSmash ->
                    ( "Page not found — might as well smash it."
                    , "move pointer to steer · click arena to launch extra balls"
                    , [ button [ Attr.type_ "button", Events.onClick (cfg.toMsg SmashSpawnBall), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] cursor-pointer " ++ focusRing) ] [ text ("+ ball (" ++ String.fromInt (List.length model.balls) ++ "/4)") ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg SmashReset), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[var(--surface-2)] hover:bg-[var(--tab-bg)] font-mono text-xs text-[var(--page-muted)] hover:text-[var(--page-fg)] cursor-pointer " ++ focusRing) ] [ text "reset" ]
                      ]
                    )

                ModeGravity ->
                    let
                        gBtn target lbl =
                            button [ Attr.type_ "button", Events.onClick (cfg.toMsg (GravSetMode target)), Attr.class ("px-2.5 py-1.5 btn-squircle font-mono text-xs cursor-pointer " ++ (if model.gravMode == target then "bg-[var(--page-fg)] text-[var(--page-bg)] font-medium" else "bg-[var(--surface-2)] text-[var(--page-muted)] hover:text-[var(--page-fg)]")) ] [ text lbl ]
                    in
                    ( "Oops — we dropped the 404."
                    , "move pointer to push tiles · click anywhere for a shockwave"
                    , [ gBtn GravZeroG "zero-g", gBtn GravFall "gravity", gBtn GravMagnet "magnet", button [ Attr.type_ "button", Events.onClick (cfg.toMsg GravExplode), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] cursor-pointer " ++ focusRing) ] [ text "explode" ] ]
                    )

                ModeDive ->
                    ( "Lost below sea level."
                    , "sweep your dive beam in the dark · click glowing relics to collect"
                    , [ button [ Attr.type_ "button", Events.onClick (cfg.toMsg DiveReset), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[var(--surface-2)] hover:bg-[var(--tab-bg)] font-mono text-xs text-[var(--page-muted)] hover:text-[var(--page-fg)] cursor-pointer " ++ focusRing) ] [ text "hide relics again" ] ]
                    )

                ModeSynth ->
                    ( "404, but it slaps."
                    , "click cells to paint a melody · pentatonic marimba loop"
                    , [ button [ Attr.type_ "button", Events.onClick (cfg.toMsg SynthTogglePlay), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[var(--page-fg)] text-[var(--page-bg)] font-mono text-xs font-medium cursor-pointer " ++ focusRing) ] [ text (if model.synthPlaying then "stop" else "play") ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg SynthToggleMute), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[var(--surface-2)] font-mono text-xs text-[var(--page-muted)] cursor-pointer " ++ focusRing) ] [ text (if model.synthMuted then "unmute" else "mute") ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg SynthPreset404), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[#8b75ff]/12 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] cursor-pointer " ++ focusRing) ] [ text "404" ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg SynthRandom), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[var(--surface-2)] font-mono text-xs text-[var(--page-muted)] cursor-pointer " ++ focusRing) ] [ text "random" ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg SynthClear), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[var(--surface-2)] font-mono text-xs text-[var(--page-muted)] cursor-pointer " ++ focusRing) ] [ text "clear" ]
                      ]
                    )

                ModeClaw ->
                    ( "Lost & Found 404 — grab a page."
                    , "move pointer to position crane · click anywhere to drop the claw"
                    , [ button [ Attr.type_ "button", Events.onClick (cfg.toMsg ClawDrop), Attr.class ("px-3 py-1.5 btn-squircle bg-[var(--callout-note-bg)] text-[var(--callout-note-fg)] font-mono text-xs font-medium cursor-pointer " ++ focusRing) ] [ text "drop claw" ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg ClawReset), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[var(--surface-2)] font-mono text-xs text-[var(--page-muted)] cursor-pointer " ++ focusRing) ] [ text "refill" ]
                      ]
                    )

                ModeEyes ->
                    ( "Nobody here has seen that page."
                    , "move around and watch them follow · click to poke & make them dizzy"
                    , [ button [ Attr.type_ "button", Events.onClick (cfg.toMsg EyesWave), Attr.class ("px-3 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] cursor-pointer " ++ focusRing) ] [ text "poke all" ] ]
                    )

                ModePlane ->
                    ( "404 airmail — fly through the rings."
                    , "aim with your pointer · click to launch origami paper planes"
                    , [ button [ Attr.type_ "button", Events.onClick (cfg.toMsg PlaneBarrage), Attr.class ("px-3 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] cursor-pointer " ++ focusRing) ] [ text "launch 3x" ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg PlaneReset), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[var(--surface-2)] font-mono text-xs text-[var(--page-muted)] cursor-pointer " ++ focusRing) ] [ text "reset" ]
                      ]
                    )

                ModeBlackhole ->
                    ( "Pulled past the event horizon."
                    , "click anywhere to drop glowing matter into the accretion disk"
                    , [ button [ Attr.type_ "button", Events.onClick (cfg.toMsg ArtBurst), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[#8b75ff]/12 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] cursor-pointer " ++ focusRing) ] [ text "pulse" ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg ArtToggleOverdrive), Attr.class ("px-2.5 py-1.5 btn-squircle font-mono text-xs cursor-pointer " ++ (if model.artOverdrive then "bg-[var(--callout-note-bg)] text-[var(--callout-note-fg)] font-medium" else "bg-[var(--surface-2)] text-[var(--page-muted)]")) ] [ text (if model.artOverdrive then "overdrive · on" else "overdrive") ]
                      ]
                    )

                ModeAurora ->
                    ( "Lost under the bayer aurora."
                    , "move pointer to ripple the curtains · click for solar flares"
                    , [ button [ Attr.type_ "button", Events.onClick (cfg.toMsg ArtBurst), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[#8b75ff]/12 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] cursor-pointer " ++ focusRing) ] [ text "solar flare" ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg ArtToggleOverdrive), Attr.class ("px-2.5 py-1.5 btn-squircle font-mono text-xs cursor-pointer " ++ (if model.artOverdrive then "bg-[var(--callout-note-bg)] text-[var(--callout-note-fg)] font-medium" else "bg-[var(--surface-2)] text-[var(--page-muted)]")) ] [ text (if model.artOverdrive then "storm · on" else "storm") ]
                      ]
                    )

                ModeWormhole ->
                    ( "Wrong turn in hyperspace."
                    , "move pointer to steer the tunnel · click to fire warp rings"
                    , [ button [ Attr.type_ "button", Events.onClick (cfg.toMsg ArtBurst), Attr.class ("px-2.5 py-1.5 btn-squircle bg-[#8b75ff]/12 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] cursor-pointer " ++ focusRing) ] [ text "warp ring" ]
                      , button [ Attr.type_ "button", Events.onClick (cfg.toMsg ArtToggleOverdrive), Attr.class ("px-2.5 py-1.5 btn-squircle font-mono text-xs cursor-pointer " ++ (if model.artOverdrive then "bg-[var(--callout-note-bg)] text-[var(--callout-note-fg)] font-medium" else "bg-[var(--surface-2)] text-[var(--page-muted)]")) ] [ text (if model.artOverdrive then "hyperdrive · on" else "hyperdrive") ]
                      ]
                    )

        arenaHtml =
            case model.mode of
                ModeSmash -> viewSmashArena cfg.theme model |> Html.map cfg.toMsg
                ModeGravity -> viewGravityArena model |> Html.map cfg.toMsg
                ModeDive -> viewDiveArena model |> Html.map cfg.toMsg
                ModeSynth -> viewSynthArena model |> Html.map cfg.toMsg
                ModeClaw -> viewClawArena model |> Html.map cfg.toMsg
                ModeEyes -> viewEyesArena model |> Html.map cfg.toMsg
                ModePlane -> viewPlaneArena model |> Html.map cfg.toMsg
                ModeBlackhole -> viewArtArena 0.0 cfg.theme model |> Html.map cfg.toMsg
                ModeAurora -> viewArtArena 1.0 cfg.theme model |> Html.map cfg.toMsg
                ModeWormhole -> viewArtArena 2.0 cfg.theme model |> Html.map cfg.toMsg
    in
    div [ Attr.class "flex flex-col pointer-events-auto space-y-5 py-3 sm:py-5" ]
        [ div [ Attr.class "flex flex-wrap items-center justify-between gap-3" ]
            [ div [ Attr.class "flex items-center gap-2.5" ]
                [ span [ Attr.class "inline-flex items-stretch h-[21px] font-mono text-[10.5px] tracking-[0.12em]" ]
                    [ span [ Attr.class "inline-flex items-center pl-2.5 pr-1.5 leading-none font-medium", Attr.style "background-color" "var(--callout-note-bg)", Attr.style "color" "var(--callout-note-fg)" ] [ text "404" ]
                    , span [ Attr.class "inline-flex items-stretch", Attr.style "color" "var(--callout-note-bg)" ] [ ditherTailSvg ]
                    ]
                , span [ Attr.class "font-mono text-xs text-[var(--page-subtle)] truncate max-w-[50vw]" ] [ text missingPath ]
                ]
            , span [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)]" ] [ text "10 concepts · pick your favorite" ]
            ]
        , div [ Attr.class "flex flex-wrap items-center gap-1.5" ]
            [ modePill ModeSmash "smash"
            , modePill ModeGravity "gravity"
            , modePill ModeDive "dive"
            , modePill ModeSynth "synth"
            , modePill ModeClaw "claw"
            , modePill ModeEyes "eyes"
            , modePill ModePlane "planes"
            , span [ Attr.class "mx-1 text-[var(--page-subtle)] font-mono text-[10px]" ] [ text "·" ]
            , modePill ModeBlackhole "blackhole"
            , modePill ModeAurora "aurora"
            , modePill ModeWormhole "wormhole"
            ]
        , div [ Attr.class "relative box-squircle bg-[var(--surface-1)] overflow-hidden" ]
            [ arenaHtml ]
        , div [ Attr.class "flex flex-wrap items-center justify-between gap-3" ]
            [ div [ Attr.class "space-y-1" ]
                [ h1 [ Attr.class "font-display font-semibold text-xl sm:text-2xl tracking-[-0.025em] text-[var(--page-fg)]" ] [ text headline ]
                , p [ Attr.class "font-mono text-[11px] text-[var(--page-subtle)]" ] [ text hintText ]
                ]
            , div [ Attr.class "flex flex-wrap items-center gap-1.5" ] modeControls
            ]
        , div [ Attr.class "flex flex-wrap items-center gap-2.5" ]
            [ a [ Attr.href "/", onInternalLinkClick cfg.onBackHome, Attr.class ("group relative overflow-hidden inline-flex items-center gap-x-1.5 px-3.5 py-1.5 btn-squircle bg-[var(--code-bg)] font-mono text-xs font-medium text-[var(--page-fg)] hover:text-white light:hover:text-[#0c0a14] transition-colors duration-200 " ++ focusRing) ]
                [ span [ Attr.class "pointer-events-none absolute inset-x-0 bottom-0 h-[2px] group-hover:h-full og-grainient opacity-75 group-hover:opacity-100 transition-[height,opacity] duration-250 ease-out" ] []
                , span [ Attr.class "relative z-10" ] [ text "← portfolio" ]
                ]
            , a [ Attr.href "/blog", onInternalLinkClick cfg.onOpenBlog, Attr.class ("inline-flex items-center px-3 py-1.5 btn-squircle bg-[#8b75ff]/12 hover:bg-[#8b75ff]/22 font-mono text-xs text-[var(--callout-note-bg)] light:text-[#443299] transition-colors duration-150 " ++ focusRing) ]
                [ text "blog" ]
            ]
        , div [ Attr.class "pt-4 border-t border-[var(--page-line)] flex items-center justify-between font-mono text-[11px] text-[var(--page-subtle)]" ]
            [ span [] [ text "portforio.samouly.fun" ]
            , div [ Attr.class "flex items-center gap-x-4" ]
                [ button [ Attr.type_ "button", Events.onClick cfg.onToggleTheme, Attr.class ("text-[var(--page-muted)] hover:text-[var(--page-fg)] transition-colors cursor-pointer rounded-xs " ++ focusRing) ] [ text (if cfg.theme == Dark then "light" else "dark") ]
                , button [ Attr.type_ "button", Events.onClick cfg.onToggleMotion, Attr.class ("text-[var(--page-subtle)] hover:text-[var(--page-fg)] transition-colors cursor-pointer rounded-xs " ++ focusRing) ] [ text (if cfg.motionPlaying then "pause" else "play") ]
                , span [ Attr.class "tabular-nums" ] [ text ("© " ++ cfg.currentYear) ]
                ]
            ]
        ]


ditherTailSvg : Html msg
ditherTailSvg =
    svg [ SvgAttr.viewBox "0 0 6 6", SvgAttr.preserveAspectRatio "none", SvgAttr.class "block w-4 h-full -ml-px shrink-0", Attr.attribute "shape-rendering" "crispEdges", Attr.attribute "aria-hidden" "true" ]
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



-- SHARED BAYER-DITHERED WEBGL ART SHADER (0 = BLACKHOLE, 1 = AURORA, 2 = WORMHOLE)


type alias ArtVertex =
    { position : Vec2 }


artQuadMesh : Mesh ArtVertex
artQuadMesh =
    WebGL.triangles [ ( ArtVertex (vec2 -1 -1), ArtVertex (vec2 3 -1), ArtVertex (vec2 -1 3) ) ]


type alias ArtUniforms =
    { uTime : Float
    , uResolution : Vec2
    , uMouse : Vec2
    , uPresence : Float
    , uFlare0 : Vec3
    , uFlare1 : Vec3
    , uFlare2 : Vec3
    , uFlare3 : Vec3
    , uFlare4 : Vec3
    , uFlare5 : Vec3
    , uFlare6 : Vec3
    , uFlare7 : Vec3
    , uArtMode : Float
    , uOverdrive : Float
    , uIsLight : Float
    }


artVertexShader : Shader ArtVertex ArtUniforms { vUv : Vec2 }
artVertexShader =
    [glsl|
        attribute vec2 position;
        varying vec2 vUv;
        void main() {
            vUv = position * 0.5 + 0.5;
            gl_Position = vec4(position, 0.0, 1.0);
        }
    |]


artFragmentShader : Shader {} ArtUniforms { vUv : Vec2 }
artFragmentShader =
    [glsl|
        precision highp float;

        varying vec2 vUv;

        uniform float uTime;
        uniform vec2 uResolution;
        uniform vec2 uMouse;
        uniform float uPresence;
        uniform vec3 uFlare0;
        uniform vec3 uFlare1;
        uniform vec3 uFlare2;
        uniform vec3 uFlare3;
        uniform vec3 uFlare4;
        uniform vec3 uFlare5;
        uniform vec3 uFlare6;
        uniform vec3 uFlare7;
        uniform float uArtMode;
        uniform float uOverdrive;
        uniform float uIsLight;

        float hash21(vec2 p) {
            p = fract(p * vec2(234.34, 435.345));
            p += dot(p, p + 34.23);
            return fract(p.x * p.y);
        }

        float noise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            f = f * f * (3.0 - 2.0 * f);
            return mix(
                mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
                mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
                f.y
            );
        }

        float fbm(vec2 p) {
            float v = 0.0;
            float a = 0.54;
            for (int i = 0; i < 4; i++) {
                v += a * noise(p);
                p = p * 2.04 + vec2(3.7, 1.9);
                a *= 0.5;
            }
            return v;
        }

        float bayer2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
        float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
        float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer2(a); }

        vec2 rot2(vec2 v, float a) {
            float c = cos(a);
            float s = sin(a);
            return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
        }

        vec3 palette(float t, vec3 bg) {
            vec3 c1 = vec3(0.098, 0.118, 0.365);
            vec3 c2 = vec3(0.282, 0.212, 0.720);
            vec3 c3 = vec3(0.478, 0.388, 0.960);
            vec3 c4 = vec3(0.678, 0.580, 1.000);
            vec3 c5 = vec3(0.494, 0.906, 0.745);
            vec3 c6 = vec3(0.980, 0.968, 1.000);
            float s = clamp(t, 0.0, 1.0) * 6.0;
            if (s < 1.0) return mix(bg, c1, s);
            if (s < 2.0) return mix(c1, c2, s - 1.0);
            if (s < 3.0) return mix(c2, c3, s - 2.0);
            if (s < 4.0) return mix(c3, c4, s - 3.0);
            if (s < 5.0) return mix(c4, c5, s - 4.0);
            return mix(c5, c6, s - 5.0);
        }

        void addFlare(vec3 fl, vec2 p, float aspect, float isSpiral, inout float glow, inout float surge) {
            float age = fl.z;
            if (age < 0.0 || age >= 2.6) return;
            vec2 origin = vec2((fl.x - 0.5) * aspect, fl.y - 0.5);
            float life = age / 2.6;
            if (isSpiral > 0.5) {
                for (int k = 0; k < 3; k++) {
                    float tT = max(0.0, life - float(k) * 0.04);
                    vec2 pos = rot2(origin * (1.0 - pow(tT, 1.3) * 0.94), pow(tT, 1.15) * 6.4);
                    glow += exp(-length(p - pos) * (15.0 + float(k) * 3.0)) * (1.0 - float(k) * 0.25) * (1.0 - life);
                }
                float r = length(p);
                glow += exp(-pow((r - (0.17 + max(0.0, life - 0.45) * 0.75)) / 0.07, 2.0)) * (1.0 - life) * 0.48;
                surge += exp(-pow((life - 0.75) / 0.2, 2.0)) * 0.7;
            } else {
                float d = length(p - origin);
                float ring = exp(-pow((d - life * 1.15) / 0.08, 2.0)) * (1.0 - life);
                glow += ring * 0.85;
                surge += ring * 0.5;
            }
        }

        void main() {
            vec2 cell = floor(gl_FragCoord.xy);
            vec2 uv = (cell + 0.5) / uResolution;
            float aspect = uResolution.x / uResolution.y;
            vec2 pRaw = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
            vec2 mRaw = vec2((uMouse.x - 0.5) * aspect, uMouse.y - 0.5);

            float flareGlow = 0.0;
            float surge = uOverdrive * 0.65;
            float spiralMode = uArtMode < 0.5 ? 1.0 : 0.0;
            addFlare(uFlare0, pRaw, aspect, spiralMode, flareGlow, surge);
            addFlare(uFlare1, pRaw, aspect, spiralMode, flareGlow, surge);
            addFlare(uFlare2, pRaw, aspect, spiralMode, flareGlow, surge);
            addFlare(uFlare3, pRaw, aspect, spiralMode, flareGlow, surge);
            addFlare(uFlare4, pRaw, aspect, spiralMode, flareGlow, surge);
            addFlare(uFlare5, pRaw, aspect, spiralMode, flareGlow, surge);
            addFlare(uFlare6, pRaw, aspect, spiralMode, flareGlow, surge);
            addFlare(uFlare7, pRaw, aspect, spiralMode, flareGlow, surge);

            vec3 darkBg = vec3(0.0196, 0.0196, 0.0196);
            vec3 lightBg = vec3(0.961, 0.957, 0.941);
            vec3 bg = mix(darkBg, lightBg, uIsLight);

            float intensity = 0.0;
            vec3 col = bg;

            if (uArtMode < 0.5) {
                // 0. SEAMLESS VIOLET BLACK HOLE
                vec2 p = rot2(pRaw, -0.15);
                float r = length(p);
                float horizonR = 0.165;
                vec2 mDiff = pRaw - mRaw;
                float mWake = uPresence * exp(-length(mDiff) * 7.0);
                vec2 mSwirl = vec2(-mDiff.y, mDiff.x) * mWake * 0.18;

                vec2 diskP = vec2(p.x, p.y * 4.2) + mSwirl * vec2(0.8, 1.8);
                float diskR = length(diskP);
                vec2 twisted = rot2(diskP, (2.6 / (diskR + 0.18)) - uTime * (0.85 + 0.48 / (diskR + 0.24)));
                float filA = fbm(twisted * 5.2 + vec2(uTime * 0.12, -uTime * 0.09));
                float filB = fbm(twisted * 10.5 - vec2(uTime * 0.18, uTime * 0.14));
                float streaks = smoothstep(0.16, 0.90, 0.62 * filA + 0.38 * filB);
                float doppler = 0.62 + 0.52 * smoothstep(-0.55, 0.55, -p.x);
                float disk = (exp(-pow((diskR - 0.34) / 0.20, 2.0)) * smoothstep(horizonR * 0.9, horizonR + 0.045, diskR)
                    + exp(-pow((diskR - 0.46) / 0.38, 2.0)) * smoothstep(horizonR, horizonR + 0.14, diskR) * 0.42) * (0.34 + 0.94 * streaks) * doppler;

                float archR = abs(r - (horizonR + 0.056));
                float einstein = exp(-archR * 19.0) * (0.38 + 0.62 * abs(p.y) / max(r, 0.001)) * (0.48 + 0.78 * fbm(rot2(p, -uTime * 0.45) * 7.5)) * doppler;
                float photon = exp(-abs(r - (horizonR + 0.007)) * 68.0) * (1.28 + surge * 0.35);
                float jet = exp(-pow(p.x / (0.024 + abs(p.y) * 0.085), 2.0)) * exp(-r * 2.5) * smoothstep(horizonR * 0.95, horizonR + 0.12, abs(p.y)) * (0.20 + surge * 0.75);

                vec2 sGrid = (p * (1.0 - 0.056 / (r + 0.028))) * 24.0;
                float sSeed = hash21(floor(sGrid));
                float stars = step(0.962, sSeed) * smoothstep(0.13, 0.025, length(fract(sGrid) - 0.5)) * smoothstep(horizonR + 0.03, horizonR + 0.2, r);

                float frontDisk = smoothstep(0.012, -0.042, p.y) * disk * 0.96;
                float shadow = smoothstep(horizonR - 0.008, horizonR + 0.01, r);
                intensity = clamp((disk + einstein + photon + jet + flareGlow + stars + mWake * 0.22) * shadow + frontDisk, 0.0, 1.0);
                col = palette(clamp(0.14 + intensity * 0.72 + photon * 0.28, 0.0, 1.0), bg);
            } else if (uArtMode < 1.5) {
                // 1. BAYER AURORA CURTAINS
                float mPull = uPresence * exp(-abs(pRaw.x - mRaw.x) * 3.5) * 0.18;
                float curtain1 = sin(pRaw.x * 3.2 + uTime * 0.65 + fbm(vec2(pRaw.x * 2.4, uTime * 0.22)) * 3.8 + mPull);
                float band1 = exp(-pow((pRaw.y - curtain1 * 0.22 - 0.04) / 0.18, 2.0));
                float rays1 = fbm(vec2(pRaw.x * 11.0 + uTime * 0.25, pRaw.y * 2.0 - uTime * 0.45));

                float curtain2 = cos(pRaw.x * 2.4 - uTime * 0.5 + fbm(vec2(pRaw.x * 1.9 + 5.0, uTime * 0.18)) * 3.2);
                float band2 = exp(-pow((pRaw.y - curtain2 * 0.26 + 0.08) / 0.22, 2.0));
                float rays2 = fbm(vec2(pRaw.x * 8.5 - uTime * 0.18, pRaw.y * 1.8 - uTime * 0.32));

                vec2 sGrid = pRaw * 26.0;
                float sSeed = hash21(floor(sGrid));
                float stars = step(0.96, sSeed) * smoothstep(0.13, 0.02, length(fract(sGrid) - 0.5)) * (0.4 + 0.6 * sin(uTime * 2.2 + sSeed * 40.0));

                float aurora = (band1 * (0.35 + 0.95 * rays1) + band2 * (0.3 + 0.85 * rays2) * 0.75) * (1.0 + surge * 0.45);
                intensity = clamp(aurora + flareGlow + stars * 0.7, 0.0, 1.0);
                col = palette(clamp(0.28 + uv.y * 0.45 + rays1 * 0.32 + flareGlow * 0.2, 0.0, 1.0), bg);
            } else {
                // 2. HYPERSPACE BAYER WORMHOLE TUNNEL
                vec2 steer = mRaw * (0.35 * uPresence);
                vec2 p = pRaw - steer;
                float r = max(length(p), 0.015);
                float depth = 0.65 / r + uTime * (1.35 + surge * 0.9);
                vec2 twist = rot2(p / r, depth * 0.55 - uTime * 0.4);
                float walls = fbm(vec2(twist.x * 3.4, depth * 1.8));
                float rings = 0.5 + 0.5 * sin(depth * 7.5 + walls * 3.0);
                float ribs = smoothstep(0.25, 0.92, 0.55 * walls + 0.45 * rings);
                float tunnelMask = smoothstep(0.05, 0.32, r);
                intensity = clamp(ribs * tunnelMask * (0.78 + 0.35 * smoothstep(0.15, 0.7, r)) + flareGlow, 0.0, 1.0);
                col = palette(clamp(fract(depth * 0.12) * 0.65 + intensity * 0.45, 0.0, 1.0), bg);
            }

            if (uIsLight > 0.5) {
                col = mix(vec3(0.28, 0.20, 0.72), vec3(0.09, 0.06, 0.24), clamp(intensity * 0.85, 0.0, 1.0));
            }

            float thr = bayer8(cell);
            float dens = floor(intensity * 5.0 + thr) / 5.0;
            if (dens <= 0.018) {
                gl_FragColor = vec4(bg, 1.0);
            } else {
                vec3 raw = mix(bg, col, clamp(dens, 0.0, 1.0));
                vec3 quant = clamp(floor(raw * 6.0 + (thr - 0.5)) / 6.0, 0.0, 1.0);
                gl_FragColor = vec4(quant, 1.0);
            }
        }
    |]
