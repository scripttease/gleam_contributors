import gleam/dynamic/decode.{type Decoder}

/// Erlang library for datetime
@external(erlang, "calendar", "universal_time")
pub fn now() -> #(Int, Int, Int)

@external(erlang, "iso8601", "format")
pub fn iso_format(date: #(Int, Int, Int)) -> String

// Converts response json to datetime string.
pub fn decode_iso_datetime() -> Decoder(String) {
  decode.at(
    ["data", "repository", "release", "tag", "target", "committedDate"],
    decode.string,
  )
}
