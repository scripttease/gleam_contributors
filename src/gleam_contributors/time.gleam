import gleam/dynamic.{Dynamic}

/// Erlang library for datetime
pub external fn now() -> tuple(Int, Int, Int) =
  "calendar" "universal_time"

pub external fn iso_format(tuple(Int, Int, Int)) -> String =
  "iso8601" "format"

// Converts response json to datetime string.
pub fn decode_iso_datetime(payload: Dynamic) -> Result(String, String) {
  try data = dynamic.field(payload, "data")
  try repo = dynamic.field(data, "repository")
  try release = dynamic.field(repo, "release")
  try tag = dynamic.field(release, "tag")
  try target = dynamic.field(tag, "target")
  try dynamic_date = dynamic.field(target, "committedDate")
  try date = dynamic.string(dynamic_date)
  Ok(date)
}
