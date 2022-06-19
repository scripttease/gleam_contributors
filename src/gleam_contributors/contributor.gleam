import gleam/result
import gleam/option.{Option}
import gleam/dynamic.{DecodeError, Dynamic}
import gleam_contributors/json

pub type Contributor {
  Contributor(name: String, github: Option(String))
}

// Could include avatarURl and websiteUrl if required
pub type Contributorspage {
  Contributorspage(
    nextpage_cursor: Result(String, Nil),
    contributor_list: List(Contributor),
  )
}

// This is still parsing the response json into Gleam types, see
// parse_contributors, but it is the contributor section only. To make the parse
// function more readable
pub fn decode(json_obj: Dynamic) -> Result(Contributor, List(DecodeError)) {
  json_obj
  |> dynamic.decode2(
    Contributor,
    dynamic.field("author", dynamic.field("name", dynamic.string)),
    dynamic.field(
      "author",
      dynamic.field(
        "user",
        dynamic.any([
          dynamic.field("url", dynamic.optional(dynamic.string)),
          fn(_) { Ok(option.None) },
        ]),
      ),
    ),
  )
}

/// Converts response json into Gleam type. Represents one page of contributors
pub fn decode_page(
  response_json: String,
) -> Result(Contributorspage, List(DecodeError)) {
  let res = json.decode(response_json)

  try history =
    res
    |> dynamic.field(
      "data",
      dynamic.field(
        "repository",
        dynamic.field("object", dynamic.field("history", Ok)),
      ),
    )

  try pageinfo = dynamic.field("pageInfo", Ok)(history)
  try nextpage = dynamic.field("hasNextPage", dynamic.bool)(pageinfo)

  let cursor = case nextpage {
    False -> Error(Nil)
    True ->
      dynamic.field("endCursor", dynamic.string)(pageinfo)
      |> result.map_error(fn(_) { Nil })
  }
  try contributors = dynamic.field("nodes", dynamic.list(of: decode))(history)

  Ok(Contributorspage(nextpage_cursor: cursor, contributor_list: contributors))
}
