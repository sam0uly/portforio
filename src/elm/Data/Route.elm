module Data.Route exposing (Route(..), fromPath, toPath)

import Data.Slug as Slug exposing (Slug)


type Route
    = Home
    | BlogIndex
    | BlogPost Slug
    | ComponentsIndex
    | ComponentDetail Slug
    | OgImagesRoute
    | NotFoundRoute String


fromPath : String -> Route
fromPath raw =
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
    if String.isEmpty cleaned then
        Home

    else if cleaned == "og-images" then
        OgImagesRoute

    else if cleaned == "blog" then
        BlogIndex

    else if String.startsWith "blog/" cleaned then
        case Slug.fromString (String.dropLeft 5 cleaned) of
            Just slug ->
                BlogPost slug

            Nothing ->
                NotFoundRoute ("/" ++ cleaned)

    else if cleaned == "components" then
        ComponentsIndex

    else if String.startsWith "components/" cleaned then
        case Slug.fromString (String.dropLeft 11 cleaned) of
            Just slug ->
                ComponentDetail slug

            Nothing ->
                NotFoundRoute ("/" ++ cleaned)

    else
        NotFoundRoute ("/" ++ cleaned)


toPath : Route -> String
toPath route =
    case route of
        Home ->
            "/"

        BlogIndex ->
            "/blog"

        BlogPost slug ->
            "/blog/" ++ Slug.toString slug

        ComponentsIndex ->
            "/components"

        ComponentDetail slug ->
            "/components/" ++ Slug.toString slug

        OgImagesRoute ->
            "/og-images"

        NotFoundRoute raw ->
            if String.startsWith "/" raw then
                raw

            else
                "/" ++ raw
