module Data.Slug exposing (Slug, decoder, default, fromString, toString)

import Json.Decode as Decode exposing (Decoder)


type Slug
    = Slug String


default : Slug
default =
    Slug "post"


fromString : String -> Maybe Slug
fromString raw =
    let
        trimmed =
            String.trim raw
    in
    if String.isEmpty trimmed || String.contains "/" trimmed then
        Nothing

    else
        Just (Slug trimmed)


toString : Slug -> String
toString (Slug value) =
    value


decoder : Decoder Slug
decoder =
    Decode.string
        |> Decode.andThen
            (\raw ->
                case fromString raw of
                    Just slug ->
                        Decode.succeed slug

                    Nothing ->
                        Decode.fail ("Invalid post slug: " ++ raw)
            )
