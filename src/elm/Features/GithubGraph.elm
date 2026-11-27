module Features.GithubGraph exposing
    ( Day
    , Model
    , Msg
    , PrFilter(..)
    , PullRequest
    , Stats
    , fetchStats
    , hasData
    , init
    , update
    , view
    , viewDesktopPrWing
    , viewMobilePrOverlay
    , viewPrPanel
    )

import Data.Theme as Theme exposing (Theme(..))
import Effects.TocWingMorph as TocWingMorph
import Html exposing (Html, a, button, div, nav, span, text)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Json.Decode as Decode
import Svg exposing (Svg, defs, g, path, pattern, rect, svg, text_)
import Svg.Attributes as SvgAttr
import Svg.Events as SvgEvents
import Svg.Lazy as SvgLazy


type PrFilter
    = FilterAll
    | FilterMerged
    | FilterOpen


type alias Day =
    { date : String
    , count : Int
    , level : Int
    }


type alias PullRequest =
    { number : Int
    , title : String
    , url : String
    , state : String
    , repo : String
    , date : String
    , additions : Int
    , deletions : Int
    }


type alias Stats =
    { username : String
    , profileUrl : String
    , orgs : List String
    , totalContributions : Int
    , commits : Int
    , prs : Int
    , stars : Int
    , weeks : List (List Day)
    , recentPrs : List PullRequest
    }


type alias HoveredCell =
    { col : Int
    , row : Int
    , day : Day
    }


type alias Model =
    { stats : Stats
    , hovered : Maybe HoveredCell
    , lastHovered : Maybe HoveredCell
    , hoverLevel : Maybe Int
    , pinnedLevel : Maybe Int
    , prFilter : PrFilter
    }


type Msg
    = GotStats (Result Http.Error Stats)
    | HoverCell Int Int Day
    | LeaveGrid
    | HoverLevel (Maybe Int)
    | TogglePinLevel Int
    | SetPrFilter PrFilter


init : ( Model, Cmd Msg )
init =
    ( { stats = emptyStats
      , hovered = Nothing
      , lastHovered = Nothing
      , hoverLevel = Nothing
      , pinnedLevel = Nothing
      , prFilter = FilterAll
      }
    , fetchStats
    )


fetchStats : Cmd Msg
fetchStats =
    Http.get
        { url = "/github-stats.json"
        , expect = Http.expectJson GotStats decodeStats
        }


hasData : Model -> Bool
hasData model =
    not (List.isEmpty model.stats.weeks)


update : Msg -> Model -> Model
update msg model =
    case msg of
        GotStats (Ok rawStats) ->
            { model | stats = { rawStats | weeks = recomputeLevels rawStats.weeks } }

        GotStats (Err _) ->
            model

        HoverCell col row day ->
            let
                cell =
                    { col = col, row = row, day = day }
            in
            { model | hovered = Just cell, lastHovered = Just cell }

        LeaveGrid ->
            { model | hovered = Nothing }

        HoverLevel maybeLevel ->
            { model | hoverLevel = maybeLevel }

        TogglePinLevel lvl ->
            let
                nextLevel =
                    if model.pinnedLevel == Just lvl then
                        Nothing

                    else
                        Just lvl
            in
            { model | pinnedLevel = nextLevel }

        SetPrFilter filter ->
            { model | prFilter = filter }


emptyStats : Stats
emptyStats =
    { username = "sam0uly"
    , profileUrl = "https://github.com/sam0uly"
    , orgs = []
    , totalContributions = 0
    , commits = 0
    , prs = 0
    , stars = 0
    , weeks = []
    , recentPrs = []
    }


recomputeLevels : List (List Day) -> List (List Day)
recomputeLevels weeks =
    let
        nonZero =
            weeks
                |> List.concat
                |> List.filterMap
                    (\day ->
                        if day.count > 0 then
                            Just day.count

                        else
                            Nothing
                    )
                |> List.sort

        n =
            List.length nonZero

        atQuantile q =
            let
                idx =
                    clamp 0 (max 0 (n - 1)) (floor (toFloat n * q))
            in
            nonZero
                |> List.drop idx
                |> List.head
                |> Maybe.withDefault 1

        t1 =
            atQuantile 0.3

        t2 =
            max (t1 + 1) (atQuantile 0.6)

        t3 =
            max (t2 + 1) (atQuantile 0.85)

        levelFor count =
            if count <= 0 then
                0

            else if count <= t1 then
                1

            else if count <= t2 then
                2

            else if count <= t3 then
                3

            else
                4
    in
    if n == 0 then
        weeks

    else
        List.map
            (List.map (\day -> { day | level = levelFor day.count }))
            weeks


decodeDay : Decode.Decoder Day
decodeDay =
    Decode.map3 Day
        (Decode.field "date" Decode.string)
        (Decode.field "count" Decode.int)
        (Decode.oneOf
            [ Decode.field "level" Decode.int
            , Decode.succeed 0
            ]
        )


decodePullRequest : Decode.Decoder PullRequest
decodePullRequest =
    Decode.map8 PullRequest
        (Decode.field "number" Decode.int)
        (Decode.field "title" Decode.string)
        (Decode.field "url" Decode.string)
        (Decode.field "state" Decode.string)
        (Decode.field "repo" Decode.string)
        (Decode.field "date" Decode.string)
        (Decode.field "additions" Decode.int)
        (Decode.field "deletions" Decode.int)


decodeStats : Decode.Decoder Stats
decodeStats =
    Decode.map8
        (\username profileUrl orgs totalContributions commits prs stars weeks ->
            \recentPrs ->
                { username = username
                , profileUrl = profileUrl
                , orgs = orgs
                , totalContributions = totalContributions
                , commits = commits
                , prs = prs
                , stars = stars
                , weeks = weeks
                , recentPrs = recentPrs
                }
        )
        (Decode.field "username" Decode.string)
        (Decode.field "profileUrl" Decode.string)
        (Decode.field "orgs" (Decode.list Decode.string))
        (Decode.field "totalContributions" Decode.int)
        (Decode.field "commits" Decode.int)
        (Decode.field "prs" Decode.int)
        (Decode.field "stars" Decode.int)
        (Decode.field "weeks" (Decode.list (Decode.list decodeDay)))
        |> Decode.andThen
            (\cont ->
                Decode.oneOf
                    [ Decode.field "recentPrs" (Decode.list decodePullRequest)
                    , Decode.succeed []
                    ]
                    |> Decode.map cont
            )



-- PURE ELM FORMATTING


formatInt : Int -> String
formatInt n =
    let
        isNeg =
            n < 0

        digits =
            String.fromInt (abs n)

        insertCommas chars acc count =
            case chars of
                [] ->
                    acc

                c :: rest ->
                    if count > 0 && modBy 3 count == 0 then
                        insertCommas rest (c :: ',' :: acc) (count + 1)

                    else
                        insertCommas rest (c :: acc) (count + 1)

        formatted =
            digits
                |> String.toList
                |> List.reverse
                |> (\rev -> insertCommas rev [] 0)
                |> String.fromList
    in
    if isNeg then
        "-" ++ formatted

    else
        formatted


formatCompact : Int -> String
formatCompact n =
    if n >= 10000 then
        let
            tenths =
                round (toFloat n / 100.0)

            whole =
                tenths // 10

            frac =
                modBy 10 tenths
        in
        if frac == 0 then
            String.fromInt whole ++ "k"

        else
            String.fromInt whole ++ "." ++ String.fromInt frac ++ "k"

    else
        formatInt n


monthShort : String -> String
monthShort mm =
    case mm of
        "01" ->
            "Jan"

        "02" ->
            "Feb"

        "03" ->
            "Mar"

        "04" ->
            "Apr"

        "05" ->
            "May"

        "06" ->
            "Jun"

        "07" ->
            "Jul"

        "08" ->
            "Aug"

        "09" ->
            "Sep"

        "10" ->
            "Oct"

        "11" ->
            "Nov"

        "12" ->
            "Dec"

        _ ->
            ""


formatDateIso : String -> String
formatDateIso iso =
    let
        year =
            String.slice 0 4 iso

        month =
            monthShort (String.slice 5 7 iso)

        dayNum =
            String.slice 8 10 iso
                |> String.toInt
                |> Maybe.map String.fromInt
                |> Maybe.withDefault ""
    in
    if String.isEmpty month || String.isEmpty dayNum then
        iso

    else
        month ++ " " ++ dayNum ++ ", " ++ year


formatShortDate : String -> String
formatShortDate iso =
    let
        month =
            monthShort (String.slice 5 7 iso)

        dayNum =
            String.slice 8 10 iso
                |> String.toInt
                |> Maybe.map String.fromInt
                |> Maybe.withDefault ""
    in
    if String.isEmpty month || String.isEmpty dayNum then
        iso

    else
        month ++ " " ++ dayNum


shortRepoName : String -> String
shortRepoName full =
    case List.reverse (String.split "/" full) of
        name :: _ ->
            name

        [] ->
            full



-- VIOLET SITE PALETTE


levelColor : Theme -> Int -> String
levelColor theme level =
    case theme of
        Dark ->
            case level of
                0 ->
                    "rgba(255, 255, 255, 0.05)"

                1 ->
                    "#211b38"

                2 ->
                    "#443778"

                3 ->
                    "#7966d4"

                _ ->
                    "#c2b4ff"

        Light ->
            case level of
                0 ->
                    "rgba(14, 14, 18, 0.06)"

                1 ->
                    "#e4dffb"

                2 ->
                    "#beb2f5"

                3 ->
                    "#7b66d6"

                _ ->
                    "#443299"


squirclePath11 : String
squirclePath11 =
    "M 5.5 0 C 10.4 0 11 0.6 11 5.5 C 11 10.4 10.4 11 5.5 11 C 0.6 11 0 10.4 0 5.5 C 0 0.6 0.6 0 5.5 0 Z"


squirclePath10 : String
squirclePath10 =
    "M 5 0 C 9.45 0 10 0.55 10 5 C 10 9.45 9.45 10 5 10 C 0.55 10 0 9.45 0 5 C 0 0.55 0.55 0 5 0 Z"


monthLabels : List (List Day) -> List ( Int, String )
monthLabels weeks =
    let
        step idx week ( prevMonth, lastCol, acc ) =
            case List.head week of
                Nothing ->
                    ( prevMonth, lastCol, acc )

                Just firstDay ->
                    let
                        mm =
                            String.slice 5 7 firstDay.date
                    in
                    if mm /= prevMonth && (idx - lastCol >= 3 || List.isEmpty acc) then
                        ( mm, idx, ( idx, monthShort mm ) :: acc )

                    else
                        ( mm, lastCol, acc )

        ( _, _, collected ) =
            List.foldl
                (\( idx, week ) state -> step idx week state)
                ( "", -10, [] )
                (List.indexedMap Tuple.pair weeks)
    in
    List.reverse collected


focusRing : String
focusRing =
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--page-fg)] focus-visible:ring-offset-4 focus-visible:ring-offset-[var(--page-bg)]"



-- MAIN GRAPH VIEW


view :
    { toMsg : Msg -> msg
    , onTogglePrWing : msg
    , prWingOpen : Bool
    , prBtnCoverage : Float
    }
    -> Theme
    -> Model
    -> Html msg
view config theme model =
    let
        stats =
            model.stats
    in
    if List.isEmpty stats.weeks then
        text ""

    else
        let
            starsExact =
                formatInt stats.stars

            orgsHint =
                if List.isEmpty stats.orgs then
                    starsExact ++ " stars"

                else
                    starsExact
                        ++ " stars across @"
                        ++ stats.username
                        ++ " & "
                        ++ String.join ", " stats.orgs
        in
        div [ Attr.class "min-w-0 space-y-3.5" ]
            [ div [ Attr.class "flex flex-wrap items-center justify-between gap-x-4 gap-y-2" ]
                [ div [ Attr.class "flex flex-wrap items-baseline gap-x-5 gap-y-1.5 font-mono text-[12.5px]" ]
                    [ viewStatItem (formatInt stats.commits) "commits" (formatInt stats.commits ++ " commits in the last 12 months")
                    , viewStatItem (formatInt stats.prs) "PRs" (formatInt stats.prs ++ " pull requests authored")
                    , viewStatItem (formatCompact stats.stars) "stars" orgsHint
                    ]
                , viewCheckPrsButton config.onTogglePrWing config.prWingOpen config.prBtnCoverage
                ]
            , viewCalendarSvg config.toMsg theme stats.weeks model
            , div [ Attr.class "flex items-center justify-end font-mono text-[11.5px] text-[var(--page-subtle)]" ]
                [ viewLegend config.toMsg theme stats model ]
            ]


viewStatItem : String -> String -> String -> Html msg
viewStatItem value label tooltip =
    span
        [ Attr.title tooltip
        , Attr.class "inline-flex items-baseline gap-x-1.5"
        ]
        [ span [ Attr.class "font-medium text-[var(--page-fg)] tabular-nums" ] [ text value ]
        , span [ Attr.class "text-[var(--page-subtle)]" ] [ text label ]
        ]


bayer8Thresholds : List ( Int, Int, Float )
bayer8Thresholds =
    let
        fract v =
            v - toFloat (floor v)

        bayer2 fx fy =
            let
                ax =
                    toFloat (floor fx)

                ay =
                    toFloat (floor fy)
            in
            fract (ax * 0.5 + ay * ay * 0.75)

        bayer4 fx fy =
            bayer2 (0.5 * fx) (0.5 * fy) * 0.25 + bayer2 fx fy

        bayer8 fx fy =
            bayer4 (0.5 * fx) (0.5 * fy) * 0.25 + bayer2 fx fy
    in
    List.range 0 7
        |> List.concatMap
            (\y ->
                List.range 0 7
                    |> List.map (\x -> ( x, y, bayer8 (toFloat x) (toFloat y) ))
            )


textBayerMaskStyles : Float -> List (Html.Attribute msg)
textBayerMaskStyles coverage =
    if coverage <= 0.004 then
        []

    else if coverage >= 0.999 then
        [ Attr.style "opacity" "0" ]

    else
        let
            visibleRects =
                bayer8Thresholds
                    |> List.filterMap
                        (\( x, y, thr ) ->
                            if thr > coverage - 0.004 then
                                Just
                                    ("%3Crect x='"
                                        ++ String.fromInt (x * 2)
                                        ++ "' y='"
                                        ++ String.fromInt (y * 2)
                                        ++ "' width='2' height='2' fill='white'/%3E"
                                    )

                            else
                                Nothing
                        )
                    |> String.concat

            svgUri =
                "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' shape-rendering='crispEdges'%3E"
                    ++ visibleRects
                    ++ "%3C/svg%3E\")"
        in
        [ Attr.style "-webkit-mask-image" svgUri
        , Attr.style "mask-image" svgUri
        , Attr.style "-webkit-mask-repeat" "repeat"
        , Attr.style "mask-repeat" "repeat"
        , Attr.style "-webkit-mask-size" "16px 16px"
        , Attr.style "mask-size" "16px 16px"
        ]


viewCheckPrsButton : msg -> Bool -> Float -> Html msg
viewCheckPrsButton onToggle isOpen coverage =
    let
        railClass =
            if isOpen then
                "pointer-events-none absolute inset-x-0 bottom-0 h-full og-grainient opacity-100 transition-[height,opacity] duration-250 ease-out"

            else
                "pointer-events-none absolute inset-x-0 bottom-0 h-[2px] group-hover:h-full og-grainient opacity-75 group-hover:opacity-100 transition-[height,opacity] duration-250 ease-out"

        textClass =
            if isOpen then
                "text-white light:text-[#0c0a14]"

            else
                "text-[var(--page-fg)] hover:text-white light:hover:text-[#0c0a14]"
    in
    button
        [ Attr.id "pr-wing-toggle"
        , Attr.type_ "button"
        , Events.onClick onToggle
        , Attr.attribute "aria-expanded"
            (if isOpen then
                "true"

             else
                "false"
            )
        , Attr.class ("group relative overflow-hidden inline-flex items-center gap-x-1.5 px-3 py-1.5 btn-squircle bg-[var(--code-bg)] font-mono text-[11px] font-medium transition-colors duration-200 cursor-pointer " ++ textClass ++ " " ++ focusRing)
        ]
        [ span [ Attr.class railClass, Attr.attribute "aria-hidden" "true" ] []
        , span
            (Attr.class "relative z-10 inline-flex items-center gap-x-1.5 leading-none"
                :: textBayerMaskStyles coverage
            )
            [ text
                (if isOpen then
                    "Close PRs"

                 else
                    "Check PRs"
                )
            , span
                [ Attr.class
                    ("inline-block transition-transform duration-150 "
                        ++ (if isOpen then
                                ""

                            else
                                "group-hover:translate-x-0.5"
                           )
                    )
                , Attr.attribute "aria-hidden" "true"
                ]
                [ text
                    (if isOpen then
                        "×"

                     else
                        "→"
                    )
                ]
            ]
        ]


viewCalendarSvg : (Msg -> msg) -> Theme -> List (List Day) -> Model -> Html msg
viewCalendarSvg toMsg theme weeks model =
    let
        cell =
            11.0

        gap =
            2.5

        step =
            cell + gap

        topPad =
            16.0

        pad =
            2.0

        weekCount =
            List.length weeks

        totalW =
            max 1.0 (toFloat weekCount * step - gap + pad * 2.0)

        totalH =
            topPad + 7.0 * step - gap + pad

        fmtCoord v =
            String.fromFloat (toFloat (round (v * 10)) / 10)

        activeCell =
            model.hovered

        activeLevel =
            case model.hoverLevel of
                Just lvl ->
                    Just lvl

                Nothing ->
                    model.pinnedLevel

        activeMonthCol =
            activeCell
                |> Maybe.andThen
                    (\h ->
                        monthLabels weeks
                            |> List.filter (\( c, _ ) -> c <= h.col)
                            |> List.reverse
                            |> List.head
                            |> Maybe.map Tuple.first
                    )

        months =
            monthLabels weeks
                |> List.map
                    (\( col, label ) ->
                        let
                            isCurrentMonth =
                                activeMonthCol == Just col
                        in
                        text_
                            [ SvgAttr.x (fmtCoord (pad + toFloat col * step))
                            , SvgAttr.y "10.5"
                            , SvgAttr.fill
                                (if isCurrentMonth then
                                    "var(--page-fg)"

                                 else
                                    "var(--page-subtle)"
                                )
                            , SvgAttr.fontSize "10"
                            , SvgAttr.fontFamily "var(--font-mono)"
                            , Attr.style "transition" "fill 160ms ease"
                            ]
                            [ Svg.text label ]
                    )

        cellsLayer =
            SvgLazy.lazy4 viewCalendarCells toMsg theme weeks activeLevel

        colBand =
            let
                cellAllowed =
                    case ( activeLevel, activeCell ) of
                        ( Nothing, Just h ) ->
                            Just h

                        ( Just lvl, Just h ) ->
                            if h.day.level == lvl then
                                Just h

                            else
                                Nothing

                        _ ->
                            Nothing

                anchorCell =
                    case cellAllowed of
                        Just h ->
                            Just h

                        Nothing ->
                            model.lastHovered

                bandX =
                    case anchorCell of
                        Just h ->
                            pad + toFloat h.col * step - 1.25

                        Nothing ->
                            pad - 1.25

                bandOpacity =
                    if cellAllowed /= Nothing then
                        "1"

                    else
                        "0"

                bandFill =
                    case theme of
                        Dark ->
                            "rgba(194, 180, 255, 0.05)"

                        Light ->
                            "rgba(68, 50, 153, 0.06)"
            in
            rect
                [ SvgAttr.x "0"
                , SvgAttr.y (fmtCoord (topPad - 1.5))
                , SvgAttr.width (fmtCoord step)
                , SvgAttr.height (fmtCoord (7.0 * step - gap + 3.0))
                , SvgAttr.rx "3"
                , SvgAttr.fill bandFill
                , SvgAttr.class "gh-col-band"
                , Attr.style "transform" ("translateX(" ++ fmtCoord bandX ++ "px)")
                , Attr.style "opacity" bandOpacity
                , Attr.style "pointer-events" "none"
                ]
                []

        focusReticle =
            let
                cellAllowed =
                    case ( activeLevel, activeCell ) of
                        ( Nothing, Just h ) ->
                            Just h

                        ( Just lvl, Just h ) ->
                            if h.day.level == lvl then
                                Just h

                            else
                                Nothing

                        _ ->
                            Nothing

                anchorCell =
                    case cellAllowed of
                        Just h ->
                            Just h

                        Nothing ->
                            model.lastHovered

                ( rx, ry ) =
                    case anchorCell of
                        Just h ->
                            ( pad + toFloat h.col * step, topPad + toFloat h.row * step )

                        Nothing ->
                            ( pad, topPad )

                rOpacity =
                    if cellAllowed /= Nothing then
                        "1"

                    else
                        "0"
            in
            g
                [ SvgAttr.class "gh-reticle"
                , Attr.style "transform" ("translate(" ++ fmtCoord rx ++ "px, " ++ fmtCoord ry ++ "px)")
                , Attr.style "opacity" rOpacity
                , Attr.style "pointer-events" "none"
                ]
                [ path
                    [ SvgAttr.d squirclePath11
                    , SvgAttr.fill "none"
                    , SvgAttr.stroke "var(--page-fg)"
                    , SvgAttr.strokeWidth "1.35"
                    ]
                    []
                ]
    in
    div
        [ Attr.class "relative [contain:layout_style]"
        , Events.onMouseLeave (toMsg LeaveGrid)
        ]
        [ viewHoverTooltip theme totalW totalH step pad topPad model.hovered model.lastHovered activeLevel
        , div [ Attr.class "overflow-x-auto pb-1 -mx-1 px-1" ]
            [ svg
                [ SvgAttr.viewBox ("0 0 " ++ fmtCoord totalW ++ " " ++ fmtCoord totalH)
                , SvgAttr.class "block w-full min-w-[580px] sm:min-w-0 h-auto select-none overflow-visible"
                , Attr.attribute "role" "img"
                , Attr.attribute "aria-label" "GitHub contribution graph over the last 12 months"
                ]
                ((colBand :: months) ++ [ cellsLayer, focusReticle ])
            ]
        ]


viewHoverTooltip : Theme -> Float -> Float -> Float -> Float -> Float -> Maybe HoveredCell -> Maybe HoveredCell -> Maybe Int -> Html msg
viewHoverTooltip theme totalW totalH step pad topPad hovered lastHovered activeLevel =
    let
        allowedHovered =
            case ( activeLevel, hovered ) of
                ( Nothing, Just h ) ->
                    Just h

                ( Just lvl, Just h ) ->
                    if h.day.level == lvl then
                        Just h

                    else
                        Nothing

                _ ->
                    Nothing

        isVisible =
            allowedHovered /= Nothing

        displayCell =
            case allowedHovered of
                Just h ->
                    Just h

                Nothing ->
                    lastHovered
    in
    case displayCell of
        Nothing ->
            text ""

        Just h ->
            let
                cellCenterX =
                    pad + toFloat h.col * step + 5.5

                cellTopY =
                    topPad + toFloat h.row * step

                leftPct =
                    clamp 6.0 94.0 ((cellCenterX / totalW) * 100.0)

                topPct =
                    (cellTopY / totalH) * 100.0

                shiftX =
                    if leftPct < 18.0 then
                        "-15%"

                    else if leftPct > 82.0 then
                        "-85%"

                    else
                        "-50%"

                transformVal =
                    if isVisible then
                        "translate(" ++ shiftX ++ ", calc(-100% - 10px)) scale(1)"

                    else
                        "translate(" ++ shiftX ++ ", calc(-100% - 4px)) scale(0.96)"

                countEl =
                    if h.day.count == 0 then
                        span [ Attr.class "font-medium text-[var(--page-muted)] tabular-nums" ] [ text "0" ]

                    else
                        span [ Attr.class "font-semibold text-[var(--page-fg)] tabular-nums" ]
                            [ text (String.fromInt h.day.count) ]

                swatchFill =
                    levelColor theme h.day.level

                shortDate =
                    case String.split "-" h.day.date of
                        [ yyyy, mm, dd ] ->
                            let
                                dayStr =
                                    String.toInt dd
                                        |> Maybe.map String.fromInt
                                        |> Maybe.withDefault dd
                            in
                            monthShort mm ++ " " ++ dayStr ++ ", " ++ String.right 2 yyyy

                        _ ->
                            h.day.date
            in
            div
                [ Attr.class "gh-tooltip-track pointer-events-none select-none absolute inset-0 z-30"
                , Attr.style "transform" ("translate3d(" ++ String.fromFloat leftPct ++ "%, " ++ String.fromFloat topPct ++ "%, 0)")
                , Attr.style "opacity"
                    (if isVisible then
                        "1"

                     else
                        "0"
                    )
                ]
                [ div
                    [ Attr.class "gh-tooltip-pill absolute top-0 left-0 box-squircle inline-flex items-center gap-1.5 px-2.5 py-1.5 bg-[var(--tab-bg)] shadow-[0_8px_24px_rgba(0,0,0,0.45)] font-mono text-[11px] leading-none whitespace-nowrap"
                    , Attr.style "transform" transformVal
                    ]
                    [ svg
                        [ SvgAttr.viewBox "0 0 10 10"
                        , SvgAttr.class "block size-[9px] shrink-0"
                        , Attr.attribute "aria-hidden" "true"
                        ]
                        [ path
                            [ SvgAttr.d squirclePath10
                            , SvgAttr.fill swatchFill
                            ]
                            []
                        ]
                    , countEl
                    , span [ Attr.class "text-[var(--page-subtle)]", Attr.attribute "aria-hidden" "true" ] [ text "·" ]
                    , span [ Attr.class "text-[10.5px] text-[var(--page-muted)] tabular-nums" ]
                        [ text shortDate ]
                    ]
                ]


viewCalendarCells : (Msg -> msg) -> Theme -> List (List Day) -> Maybe Int -> Svg msg
viewCalendarCells toMsg theme weeks activeLevel =
    let
        cell =
            11.0

        gap =
            2.5

        step =
            cell + gap

        topPad =
            16.0

        pad =
            2.0

        fmtCoord v =
            String.fromFloat (toFloat (round (v * 10)) / 10)

        renderCell col rowOffset row day =
            let
                actualRow =
                    row + rowOffset

                xPos =
                    pad + toFloat col * step

                yPos =
                    topPad + toFloat actualRow * step

                fillClr =
                    levelColor theme day.level

                cellOpacity =
                    case activeLevel of
                        Just lvl ->
                            if day.level == lvl then
                                "1"

                            else
                                "0.18"

                        Nothing ->
                            "1"
            in
            g
                [ SvgAttr.transform ("translate(" ++ fmtCoord xPos ++ ", " ++ fmtCoord yPos ++ ")")
                , SvgEvents.onMouseOver (toMsg (HoverCell col actualRow day))
                ]
                [ rect
                    [ SvgAttr.x "-1.25"
                    , SvgAttr.y "-1.25"
                    , SvgAttr.width (fmtCoord step)
                    , SvgAttr.height (fmtCoord step)
                    , SvgAttr.fill "transparent"
                    ]
                    []
                , path
                    [ SvgAttr.d squirclePath11
                    , SvgAttr.fill fillClr
                    , SvgAttr.class "gh-cell"
                    , Attr.style "opacity" cellOpacity
                    , Attr.style "pointer-events" "none"
                    ]
                    []
                ]
    in
    weeks
        |> List.indexedMap
            (\col week ->
                let
                    dayCount =
                        List.length week

                    rowOffset =
                        if col == 0 && dayCount < 7 then
                            7 - dayCount

                        else
                            0
                in
                List.indexedMap (renderCell col rowOffset) week
            )
        |> List.concat
        |> g []


viewLegend : (Msg -> msg) -> Theme -> Stats -> Model -> Html msg
viewLegend toMsg theme stats model =
    let
        activeLevel =
            case model.hoverLevel of
                Just lvl ->
                    Just lvl

                Nothing ->
                    model.pinnedLevel

        levelSummary =
            case activeLevel of
                Just lvl ->
                    let
                        matching =
                            stats.weeks
                                |> List.concat
                                |> List.filter (\d -> d.level == lvl)

                        days =
                            List.length matching
                    in
                    span [ Attr.class "mr-2 text-[var(--page-muted)] tabular-nums" ]
                        [ text
                            (if lvl == 0 then
                                formatInt days ++ " quiet days"

                             else
                                formatInt days ++ " days"
                            )
                        ]

                Nothing ->
                    text ""
    in
    div
        [ Attr.class "inline-flex items-center gap-x-2"
        , Events.onMouseLeave (toMsg (HoverLevel Nothing))
        ]
        [ levelSummary
        , div [ Attr.class "box-squircle inline-flex items-center gap-x-1 px-2.5 py-1 bg-[var(--tab-bg)]/65" ]
            ([ span [ Attr.class "mr-1 text-[10.5px]" ] [ text "Less" ] ]
                ++ List.map
                    (\lvl ->
                        let
                            isSelected =
                                activeLevel == Just lvl

                            isDimmed =
                                activeLevel /= Nothing && not isSelected
                        in
                        button
                            [ Attr.type_ "button"
                            , Events.onMouseEnter (toMsg (HoverLevel (Just lvl)))
                            , Events.onClick (toMsg (TogglePinLevel lvl))
                            , Attr.attribute "aria-label" ("Filter intensity level " ++ String.fromInt lvl)
                            , Attr.attribute "aria-pressed"
                                (if model.pinnedLevel == Just lvl then
                                    "true"

                                 else
                                    "false"
                                )
                            , Attr.class
                                ("p-0.5 cursor-pointer rounded-xs transition-transform duration-150 "
                                    ++ (if isSelected then
                                            "scale-125"

                                        else
                                            "hover:scale-115"
                                       )
                                    ++ " "
                                    ++ focusRing
                                )
                            , Attr.style "opacity"
                                (if isDimmed then
                                    "0.35"

                                 else
                                    "1"
                                )
                            ]
                            [ svg
                                [ SvgAttr.viewBox "0 0 10 10"
                                , SvgAttr.class "block size-[11px] shrink-0"
                                , Attr.attribute "aria-hidden" "true"
                                ]
                                [ path
                                    [ SvgAttr.d squirclePath10
                                    , SvgAttr.fill (levelColor theme lvl)
                                    ]
                                    []
                                ]
                            ]
                    )
                    [ 0, 1, 2, 3, 4 ]
                ++ [ span [ Attr.class "ml-1 text-[10.5px]" ] [ text "More" ] ]
            )
        ]



-- DESKTOP RIGHT PR WING (264x440 MIRROR OF TOC WING)


viewDesktopPrWing :
    { toMsg : Msg -> msg
    , onClose : msg
    }
    -> Float
    -> List (Html.Attribute msg)
    -> Html msg
    -> Model
    -> Html msg
viewDesktopPrWing config morphProgress tintStyle overlayHtml model =
    let
        stats =
            model.stats

        e =
            clamp 0.0 1.08 morphProgress

        isVisible =
            e > 0.002

        isInteractive =
            e > 0.7

        contentAlpha =
            clamp 0.0 1.0 ((e - 0.55) / 0.42)

        slidePx =
            (1.0 - contentAlpha) * -10.0

        clipStyle =
            case TocWingMorph.rightWingClipPath e of
                Just clipVal ->
                    [ Attr.style "clip-path" clipVal ]

                Nothing ->
                    []

        pathD =
            TocWingMorph.rightWingPath e

        filteredPrs =
            filterPullRequests model.prFilter stats.recentPrs
    in
    if not isVisible then
        text ""

    else
        div
            ([ Attr.id "desktop-pr-wing"
             , Attr.attribute "data-grainient-shield" "true"
             , Attr.attribute "aria-label" "Recent pull requests"
             , Attr.attribute "aria-hidden"
                (if isInteractive then
                    "false"

                 else
                    "true"
                )
             , Attr.class
                ("hidden xl:flex flex-col absolute left-full top-1/2 -translate-y-1/2 h-[440px] w-[264px] z-[5] text-[var(--page-bg)] select-text "
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
                [ SvgAttr.viewBox "0 0 264 488"
                , SvgAttr.class "pointer-events-none select-none absolute left-0 -top-6 w-[264px] h-[488px] overflow-visible z-0 [filter:drop-shadow(8px_10px_20px_var(--wing-shadow-color))]"
                , Attr.style "opacity" (String.fromFloat (clamp 0.0 1.0 (e / 0.14)))
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
                ([ Attr.id "pr-wing-inner"
                 , Attr.class "relative z-10 isolate flex-1 min-h-0 flex flex-col pr-wing-squircle"
                 , Attr.style "opacity" (String.fromFloat contentAlpha)
                 , Attr.style "transform" ("translate3d(" ++ String.fromFloat slidePx ++ "px, 0, 0)")
                 ]
                    ++ clipStyle
                )
                [ div [ Attr.class "relative z-20 flex items-center justify-between gap-x-2 px-4 pt-3.5 pb-2" ]
                    [ div [ Attr.class "inline-flex items-stretch h-[19px] font-mono text-[10px] tracking-[0.08em]" ]
                        [ span
                            [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none font-medium"
                            , Attr.style "background-color" "var(--callout-note-bg)"
                            , Attr.style "color" "var(--callout-note-fg)"
                            ]
                            [ text ("PRs · " ++ formatInt stats.prs) ]
                        , span
                            [ Attr.class "inline-flex items-stretch"
                            , Attr.style "color" "var(--callout-note-bg)"
                            ]
                            [ ditherTailSvg ]
                        ]
                    , button
                        [ Attr.type_ "button"
                        , Events.onClick config.onClose
                        , Attr.attribute "aria-label" "Close pull requests panel"
                        , Attr.class ("inline-flex items-center justify-center size-6 rounded-xs text-[var(--page-subtle)] hover:text-[var(--page-fg)] transition-colors duration-150 cursor-pointer " ++ focusRing)
                        ]
                        [ closeIcon ]
                    ]
                , div [ Attr.class "relative z-20 px-4 pb-2" ]
                    [ viewSlidingTabs config.toMsg model.prFilter ]
                , div [ Attr.class "relative flex-1 min-h-0 flex flex-col" ]
                    [ nav
                        [ Attr.class "scroll-clean relative z-0 flex-1 min-h-0 overflow-y-auto overscroll-contain px-4 pt-2 pb-6 space-y-2.5"
                        , Attr.attribute "aria-label" "Recent pull requests list"
                        ]
                        (if List.isEmpty filteredPrs then
                            [ div [ Attr.class "font-mono text-[11px] text-[var(--page-subtle)] py-4" ]
                                [ text "No matching public PRs." ]
                            ]

                         else
                            List.map viewPrCard filteredPrs
                        )
                    , div
                        ([ Attr.attribute "aria-hidden" "true"
                         , Attr.class "pointer-events-none select-none absolute inset-x-0 top-0 h-5 z-20 pblur"
                         ]
                            ++ tintStyle
                        )
                        [ Html.node "i" [] [], Html.node "i" [] [] ]
                    , div
                        ([ Attr.attribute "aria-hidden" "true"
                         , Attr.class "pointer-events-none select-none absolute inset-x-0 bottom-0 h-6 z-20 pblur pblur-bottom"
                         ]
                            ++ tintStyle
                        )
                        [ Html.node "i" [] [], Html.node "i" [] [] ]
                    ]
                , div [ Attr.class "relative z-20 shrink-0 px-4 py-2.5 border-t border-[var(--page-line)]" ]
                    [ a
                        [ Attr.href ("https://github.com/pulls?q=is%3Apr+author%3A" ++ stats.username)
                        , Attr.target "_blank"
                        , Attr.rel "noopener noreferrer"
                        , Attr.class ("inline-flex items-center gap-x-1 font-mono text-[11px] text-[var(--page-subtle)] hover:text-[var(--page-fg)] transition-colors duration-150 " ++ focusRing)
                        ]
                        [ text ("All " ++ formatInt stats.prs ++ " on GitHub ↗") ]
                    ]
                , overlayHtml
                ]
            ]


viewPrPanel : { toMsg : Msg -> msg } -> Model -> Html msg
viewPrPanel config model =
    let
        stats =
            model.stats

        filteredPrs =
            filterPullRequests model.prFilter stats.recentPrs
    in
    div
        [ Attr.attribute "data-local-scroll" "true"
        , Attr.class "relative isolate w-full max-w-sm h-[360px] box-squircle bg-[var(--page-bg)] flex flex-col"
        ]
        [ div [ Attr.class "relative z-20 flex items-center justify-between gap-x-2 px-4 pt-3.5 pb-2" ]
            [ div [ Attr.class "inline-flex items-stretch h-[19px] font-mono text-[10px] tracking-[0.08em]" ]
                [ span
                    [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none font-medium"
                    , Attr.style "background-color" "var(--callout-note-bg)"
                    , Attr.style "color" "var(--callout-note-fg)"
                    ]
                    [ text ("PRs · " ++ formatInt stats.prs) ]
                , span
                    [ Attr.class "inline-flex items-stretch"
                    , Attr.style "color" "var(--callout-note-bg)"
                    ]
                    [ ditherTailSvg ]
                ]
            , span [ Attr.class "font-mono text-[10.5px] text-[var(--page-subtle)] tabular-nums" ]
                [ text (String.fromInt (List.length filteredPrs) ++ " shown") ]
            ]
        , div [ Attr.class "relative z-20 px-4 pb-2" ]
            [ viewSlidingTabs config.toMsg model.prFilter ]
        , div [ Attr.class "relative flex-1 min-h-0 flex flex-col" ]
            [ nav
                [ Attr.class "scroll-clean relative z-0 flex-1 min-h-0 overflow-y-auto overscroll-contain px-4 pt-2 pb-6 space-y-2.5"
                , Attr.attribute "aria-label" "Recent pull requests list"
                ]
                (if List.isEmpty filteredPrs then
                    [ div [ Attr.class "font-mono text-[11px] text-[var(--page-subtle)] py-4" ]
                        [ text "No matching public PRs." ]
                    ]

                 else
                    List.map viewPrCard filteredPrs
                )
            , div
                [ Attr.attribute "aria-hidden" "true"
                , Attr.class "pointer-events-none select-none absolute inset-x-0 top-0 h-5 z-20 pblur"
                ]
                [ Html.node "i" [] [], Html.node "i" [] [] ]
            , div
                [ Attr.attribute "aria-hidden" "true"
                , Attr.class "pointer-events-none select-none absolute inset-x-0 bottom-0 h-6 z-20 pblur pblur-bottom"
                ]
                [ Html.node "i" [] [], Html.node "i" [] [] ]
            ]
        , div [ Attr.class "relative z-20 shrink-0 px-4 py-2.5 border-t border-[var(--page-line)]" ]
            [ a
                [ Attr.href ("https://github.com/pulls?q=is%3Apr+author%3A" ++ stats.username)
                , Attr.target "_blank"
                , Attr.rel "noopener noreferrer"
                , Attr.class ("inline-flex items-center gap-x-1 font-mono text-[11px] text-[var(--page-subtle)] hover:text-[var(--page-fg)] transition-colors duration-150 " ++ focusRing)
                ]
                [ text ("All " ++ formatInt stats.prs ++ " on GitHub ↗") ]
            ]
        ]



-- MOBILE PR OVERLAY (MIRRORS MOBILE TOC OVERLAY)


viewMobilePrOverlay :
    { toMsg : Msg -> msg
    , onClose : msg
    }
    -> Bool
    -> List (Html.Attribute msg)
    -> Model
    -> Html msg
viewMobilePrOverlay config isOpen tintStyle model =
    if not isOpen then
        text ""

    else
        let
            stats =
                model.stats

            filteredPrs =
                filterPullRequests model.prFilter stats.recentPrs
        in
        div
            [ Attr.id "mobile-pr-overlay"
            , Attr.class "xl:hidden absolute inset-x-0 top-0 z-25 pl-5 pr-7 sm:px-10 pt-2 pb-3 pointer-events-auto"
            ]
            [ div
                ([ Attr.class "pointer-events-none select-none absolute inset-x-0 top-0 -bottom-8 z-0 sheet-squircle-shape pblur pblur-toc-open" ]
                    ++ tintStyle
                )
                [ Html.node "i" [] [], Html.node "i" [] [] ]
            , div
                [ Attr.class "relative z-10" ]
                [ div [ Attr.class "flex items-center justify-between gap-x-3 py-2" ]
                    [ span [ Attr.class "shrink-0 inline-flex items-stretch h-[19px] font-mono text-[10px] tracking-[0.08em]" ]
                        [ span
                            [ Attr.class "inline-flex items-center pl-2 pr-1.5 leading-none font-medium"
                            , Attr.style "background-color" "var(--callout-note-bg)"
                            , Attr.style "color" "var(--callout-note-fg)"
                            ]
                            [ text ("PRs · " ++ formatInt stats.prs) ]
                        , span
                            [ Attr.class "inline-flex items-stretch"
                            , Attr.style "color" "var(--callout-note-bg)"
                            ]
                            [ ditherTailSvg ]
                        ]
                    , div [ Attr.class "w-[168px]" ]
                        [ viewSlidingTabs config.toMsg model.prFilter ]
                    , button
                        [ Attr.type_ "button"
                        , Events.onClick config.onClose
                        , Attr.attribute "aria-label" "Close pull requests panel"
                        , Attr.class ("inline-flex items-center justify-center min-h-9 min-w-9 rounded-xs text-[var(--page-subtle)] hover:text-[var(--page-fg)] transition-colors duration-150 cursor-pointer " ++ focusRing)
                        ]
                        [ closeIcon ]
                    ]
                , nav
                    [ Attr.class "toc-nav-fade scroll-clean mt-1 max-h-[34dvh] overflow-y-auto overscroll-contain pt-1 pb-5 space-y-2.5"
                    , Attr.attribute "aria-label" "Recent pull requests list"
                    ]
                    (if List.isEmpty filteredPrs then
                        [ div [ Attr.class "font-mono text-xs text-[var(--page-subtle)] py-3" ]
                            [ text "No matching public PRs." ]
                        ]

                     else
                        List.map viewPrCard filteredPrs
                    )
                , div [ Attr.class "pt-2 border-t border-[var(--page-line)]" ]
                    [ a
                        [ Attr.href ("https://github.com/pulls?q=is%3Apr+author%3A" ++ stats.username)
                        , Attr.target "_blank"
                        , Attr.rel "noopener noreferrer"
                        , Attr.class ("inline-flex items-center gap-x-1 font-mono text-[11px] text-[var(--page-subtle)] hover:text-[var(--page-fg)] transition-colors duration-150 " ++ focusRing)
                        ]
                        [ text ("All " ++ formatInt stats.prs ++ " on GitHub ↗") ]
                    ]
                ]
            ]


filterPullRequests : PrFilter -> List PullRequest -> List PullRequest
filterPullRequests filter prs =
    case filter of
        FilterAll ->
            prs

        FilterMerged ->
            List.filter (\pr -> pr.state == "MERGED") prs

        FilterOpen ->
            List.filter (\pr -> pr.state == "OPEN") prs


viewSlidingTabs : (Msg -> msg) -> PrFilter -> Html msg
viewSlidingTabs toMsg active =
    let
        activeIdx =
            case active of
                FilterAll ->
                    0

                FilterMerged ->
                    1

                FilterOpen ->
                    2

        slideTransform =
            "translate3d(" ++ String.fromInt (activeIdx * 100) ++ "%, 0, 0)"
    in
    div
        [ Attr.class "relative grid grid-cols-3 p-0.5 btn-squircle bg-[var(--code-bg)] font-mono text-[10.5px]"
        , Attr.attribute "role" "tablist"
        , Attr.attribute "aria-label" "Filter pull requests"
        ]
        (div
            [ Attr.attribute "aria-hidden" "true"
            , Attr.class "pointer-events-none absolute top-0.5 bottom-0.5 left-0.5 w-[calc((100%-4px)/3)] btn-squircle bg-[var(--tab-bg)] transition-transform duration-200 ease-[cubic-bezier(0.22,1,0.36,1)]"
            , Attr.style "transform" slideTransform
            ]
            []
            :: List.map
                (\( flt, label ) ->
                    let
                        isActive =
                            flt == active
                    in
                    button
                        [ Attr.type_ "button"
                        , Attr.attribute "role" "tab"
                        , Attr.attribute "aria-selected"
                            (if isActive then
                                "true"

                             else
                                "false"
                            )
                        , Events.onClick (toMsg (SetPrFilter flt))
                        , Attr.class
                            ("relative z-10 py-1 text-center transition-colors duration-150 cursor-pointer rounded-xs "
                                ++ (if isActive then
                                        "text-[var(--page-fg)] font-medium"

                                    else
                                        "text-[var(--page-subtle)] hover:text-[var(--page-fg)]"
                                   )
                                ++ " "
                                ++ focusRing
                            )
                        ]
                        [ text label ]
                )
                [ ( FilterAll, "All" )
                , ( FilterMerged, "Merged" )
                , ( FilterOpen, "Open" )
                ]
        )


viewPrCard : PullRequest -> Html msg
viewPrCard pr =
    let
        ( stateColor, stateLabel ) =
            case pr.state of
                "MERGED" ->
                    ( "var(--callout-note-bg)", "Merged" )

                "OPEN" ->
                    ( "var(--callout-tip-bg)", "Open" )

                _ ->
                    ( "var(--page-subtle)", "Closed" )

        totalDelta =
            max 1 (pr.additions + pr.deletions)

        addPct =
            clamp 8.0 92.0 ((toFloat pr.additions / toFloat totalDelta) * 100.0)
    in
    a
        [ Attr.href pr.url
        , Attr.target "_blank"
        , Attr.rel "noopener noreferrer"
        , Attr.title (pr.repo ++ " #" ++ String.fromInt pr.number ++ " (" ++ stateLabel ++ ")")
        , Attr.class ("group block py-2 border-b border-[var(--page-line)] last:border-b-0 space-y-1.5 rounded-xs " ++ focusRing)
        ]
        [ div [ Attr.class "flex items-center justify-between gap-x-1.5 font-mono text-[10.5px]" ]
            [ div [ Attr.class "flex items-center gap-x-1.5 min-w-0" ]
                [ span
                    [ Attr.class "inline-block size-1.5 rounded-full shrink-0"
                    , Attr.style "background-color" stateColor
                    ]
                    []
                , span [ Attr.class "text-[var(--page-muted)] group-hover:text-[var(--page-fg)] transition-colors duration-150 truncate" ]
                    [ text (shortRepoName pr.repo) ]
                , span [ Attr.class "text-[var(--page-subtle)] tabular-nums shrink-0" ]
                    [ text ("#" ++ String.fromInt pr.number) ]
                ]
            , span [ Attr.class "text-[var(--page-subtle)] tabular-nums shrink-0" ]
                [ text (formatShortDate pr.date) ]
            ]
        , div [ Attr.class "text-[12px] leading-[1.38] text-[var(--page-fg)]/85 group-hover:text-[var(--page-fg)] transition-colors duration-150 line-clamp-2" ]
            [ text pr.title ]
        , div [ Attr.class "flex items-center gap-x-2 pt-0.5" ]
            [ div [ Attr.class "flex-1 h-[2.5px] rounded-full overflow-hidden bg-[var(--page-line)] flex" ]
                [ div
                    [ Attr.class "h-full"
                    , Attr.style "width" (String.fromFloat addPct ++ "%")
                    , Attr.style "background-color" "var(--callout-tip-bg)"
                    ]
                    []
                , div
                    [ Attr.class "h-full flex-1"
                    , Attr.style "background-color" "var(--callout-warn-bg)"
                    ]
                    []
                ]
            , span [ Attr.class "font-mono text-[10px] tabular-nums text-[var(--page-subtle)] shrink-0" ]
                [ span [ Attr.style "color" "var(--callout-tip-bg)" ] [ text ("+" ++ formatCompact pr.additions) ]
                , text " "
                , span [ Attr.style "color" "var(--callout-warn-bg)" ] [ text ("-" ++ formatCompact pr.deletions) ]
                ]
            ]
        ]


ditherTailSvg : Html msg
ditherTailSvg =
    svg
        [ SvgAttr.viewBox "0 0 6 6"
        , SvgAttr.preserveAspectRatio "none"
        , SvgAttr.class "block w-3.5 h-full -ml-px shrink-0"
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


closeIcon : Html msg
closeIcon =
    svg
        [ SvgAttr.viewBox "0 0 14 14"
        , SvgAttr.fill "none"
        , SvgAttr.class "size-3.5"
        , Attr.attribute "aria-hidden" "true"
        ]
        [ path
            [ SvgAttr.d "M3.5 3.5L10.5 10.5M10.5 3.5L3.5 10.5"
            , SvgAttr.stroke "currentColor"
            , SvgAttr.strokeWidth "1.4"
            , SvgAttr.strokeLinecap "round"
            ]
            []
        ]
