module TocWingMorph exposing
    ( Model
    , init
    , isAnimating
    , progress
    , setOpen
    , tick
    , wingClipPath
    , wingPath
    )


type alias Model =
    { value : Float
    , velocity : Float
    , target : Float
    }


openStiffness : Float
openStiffness =
    300


openDamping : Float
openDamping =
    26.5


closeStiffness : Float
closeStiffness =
    360


closeDamping : Float
closeDamping =
    38


settleThreshold : Float
settleThreshold =
    0.0008


wingWidth : Float
wingWidth =
    216


wingHeight : Float
wingHeight =
    384


filletMax : Float
filletMax =
    24


radiusMax : Float
radiusMax =
    28


cornerSteps : Int
cornerSteps =
    10


init : Bool -> Bool -> Model
init _ initiallyOpen =
    let
        v =
            if initiallyOpen then
                1.0

            else
                0.0
    in
    { value = v
    , velocity = 0.0
    , target = v
    }


setOpen : Bool -> Bool -> Model -> Model
setOpen prefersReduced isOpen model =
    let
        nextTarget =
            if isOpen then
                1.0

            else
                0.0
    in
    if prefersReduced then
        { value = nextTarget, velocity = 0.0, target = nextTarget }

    else if model.target == nextTarget then
        model

    else
        { model | target = nextTarget }


isAnimating : Model -> Bool
isAnimating model =
    abs (model.value - model.target) >= settleThreshold
        || abs model.velocity >= settleThreshold


progress : Model -> Float
progress model =
    clamp 0.0 1.08 model.value


tick : Float -> Model -> Model
tick dtMs model =
    if not (isAnimating model) then
        { model | value = model.target, velocity = 0.0 }

    else
        let
            dt =
                clamp 0.001 0.05 (dtMs / 1000.0)

            subSteps =
                max 1 (ceiling (dt / 0.004))

            h =
                dt / toFloat subSteps

            ( k, c ) =
                if model.target < 0.5 then
                    ( closeStiffness, closeDamping )

                else
                    ( openStiffness, openDamping )

            stepLoop remaining val vel =
                if remaining <= 0 then
                    ( val, vel )

                else
                    let
                        accel =
                            -k * (val - model.target) - c * vel

                        nextVel =
                            vel + accel * h

                        nextVal =
                            val + nextVel * h
                    in
                    stepLoop (remaining - 1) nextVal nextVel

            ( finalVal, finalVel ) =
                stepLoop subSteps model.value model.velocity
        in
        if abs (finalVal - model.target) < settleThreshold && abs finalVel < settleThreshold then
            { model | value = model.target, velocity = 0.0 }

        else
            { model | value = finalVal, velocity = finalVel }


fmt : Float -> String
fmt val =
    String.fromFloat (toFloat (round (val * 100)) / 100)


pt : Float -> Float -> String
pt x y =
    fmt x ++ " " ++ fmt y


concaveFillet : Float -> Float -> Float -> Float -> Float -> Float -> String
concaveFillet x0 y0 cx cy x1 y1 =
    let
        k =
            0.62

        cp1x =
            x0 + (cx - x0) * k

        cp1y =
            y0 + (cy - y0) * k

        cp2x =
            x1 + (cx - x1) * k

        cp2y =
            y1 + (cy - y1) * k
    in
    "C " ++ pt cp1x cp1y ++ ", " ++ pt cp2x cp2y ++ ", " ++ pt x1 y1


squircleCorner : Float -> Float -> Float -> Float -> Int -> List String
squircleCorner cx cy rx ry quadrant =
    if rx < 0.05 || ry < 0.05 then
        []

    else
        let
            ( sx, sy ) =
                case quadrant of
                    0 ->
                        ( 1, -1 )

                    1 ->
                        ( 1, 1 )

                    2 ->
                        ( -1, 1 )

                    _ ->
                        ( -1, -1 )

            isOdd =
                modBy 2 quadrant == 1

            stepPoint i =
                let
                    t =
                        (toFloat i / toFloat cornerSteps) * (pi / 2)

                    ( u, v ) =
                        if isOdd then
                            ( cos t, sin t )

                        else
                            ( sin t, cos t )
                in
                "L " ++ pt (cx + sx * rx * sqrt u) (cy + sy * ry * sqrt v)
        in
        List.map stepPoint (List.range 1 cornerSteps)


wingClipPath : Float -> Maybe String
wingClipPath rawProgress =
    let
        e =
            clamp 0.0 1.08 rawProgress
    in
    if e >= 0.98 then
        Nothing

    else
        let
            w =
                wingWidth * e

            h =
                8.0 + (wingHeight - 8.0) * e

            leftInset =
                max 0.0 (wingWidth - w)

            vertInset =
                max 0.0 ((wingHeight - h) / 2.0)

            r =
                min radiusMax (min (w * 0.5) (h * 0.45))
        in
        Just
            ("inset("
                ++ fmt vertInset
                ++ "px 0px "
                ++ fmt vertInset
                ++ "px "
                ++ fmt leftInset
                ++ "px round "
                ++ fmt r
                ++ "px 0px 0px "
                ++ fmt r
                ++ "px)"
            )


wingPath : Float -> String
wingPath rawProgress =
    let
        e =
            clamp 0.0 1.08 rawProgress
    in
    if e < 0.002 then
        ""

    else
        let
            w =
                wingWidth * e

            minH =
                8.0

            h =
                minH + (wingHeight - minH) * e

            cy =
                filletMax + wingHeight / 2.0

            topY =
                cy - h / 2.0

            botY =
                cy + h / 2.0

            seamX =
                wingWidth

            leftX =
                seamX - w

            fx =
                min filletMax (w * 0.5)

            fy =
                min filletMax (max 4.0 (w * 1.4))

            rx =
                min radiusMax (max 0.0 (w - fx))

            ry =
                min radiusMax (h * 0.5)

            botJoin =
                if fx > 0.15 && fy > 0.15 then
                    [ concaveFillet seamX (botY + fy) seamX botY (seamX - fx) botY ]

                else
                    [ "L " ++ pt seamX botY ]

            topJoin =
                if fx > 0.15 && fy > 0.15 then
                    [ "L " ++ pt (seamX - fx) topY
                    , concaveFillet (seamX - fx) topY seamX topY seamX (topY - fy)
                    ]

                else
                    [ "L " ++ pt seamX topY ]

            segments =
                [ "M " ++ pt (seamX + 1) (botY + fy)
                , "L " ++ pt seamX (botY + fy)
                ]
                    ++ botJoin
                    ++ [ "L " ++ pt (leftX + rx) botY ]
                    ++ squircleCorner (leftX + rx) (botY - ry) rx ry 2
                    ++ [ "L " ++ pt leftX (topY + ry) ]
                    ++ squircleCorner (leftX + rx) (topY + ry) rx ry 3
                    ++ topJoin
                    ++ [ "L " ++ pt (seamX + 1) (topY - fy)
                       , "Z"
                       ]
        in
        String.join " " segments
