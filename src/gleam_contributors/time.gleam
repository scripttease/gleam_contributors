import gleam/dynamic.{DecodeError, Dynamic}

/// Erlang library for datetime
pub external fn now() -> #(Int, Int, Int) =
  "calendar" "universal_time"

pub external fn iso_format(#(Int, Int, Int)) -> String =
  "iso8601" "format"

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
