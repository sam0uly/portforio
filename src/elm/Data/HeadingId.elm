module Data.HeadingId exposing (HeadingId, decoder, fromString, toString)

import Json.Decode as Decode exposing (Decoder)


type HeadingId
    = HeadingId String


fromString : String -> Maybe HeadingId
fromString raw =
    let
        trimmed =
            String.trim raw
    in
    if String.isEmpty trimmed then
        Nothing

    else
        Just (HeadingId trimmed)


toString : HeadingId -> String
toString (HeadingId value) =
    value


decoder : Decoder HeadingId
decoder =
    Decode.string
        |> Decode.andThen
            (\raw ->
                case fromString raw of
                    Just headingId ->
                        Decode.succeed headingId

                    Nothing ->
                        Decode.fail "HeadingId cannot be empty"
            )
