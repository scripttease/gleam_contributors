import gleam/dynamic.{type DecodeError, type Dynamic}

/// Erlang library for datetime
@external(erlang, "calendar", "universal_time")
pub fn now() -> #(Int, Int, Int)

@external(erlang, "iso8601", "format")
pub fn iso_format(date: #(Int, Int, Int)) -> String

// Converts response json to datetime string.
pub fn decode_iso_datetime(
  payload: Dynamic,
) -> Result(String, List(DecodeError)) {
  payload
  |> dynamic.field(
    "data",
    dynamic.field(
      "repository",
      dynamic.field(
        "release",
        dynamic.field(
          "tag",
          dynamic.field(
            "target",
            dynamic.field("committedDate", dynamic.string),
          ),
        ),
      ),
    ),
  )
}
