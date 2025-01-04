import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/io
import gleam/json
import gleam/option.{type Option}
import gleam/result

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
  let decoder =
    dynamic.decode2(
      Contributor,
      dynamic.any([
        dynamic.field("name", dynamic.string),
        dynamic.field("login", dynamic.string),
      ]),
      dynamic.any([
        dynamic.field("url", dynamic.optional(dynamic.string)),
        fn(_) { Ok(option.None) },
      ]),
    )
  let decoder = dynamic.field("author", dynamic.field("user", decoder))
  decoder(json_obj)
}

/// Converts response json into Gleam type. Represents one page of contributors
pub fn decode_page(
  response_json: String,
) -> Result(Contributorspage, json.DecodeError) {
  let decoder = fn(data) {
    use repo <- result.try(dynamic.field(
      "data",
      dynamic.field("repository", Ok),
    )(data))

    case dynamic.field("history", Ok)(repo) {
      Ok(history) -> {
        use pageinfo <- result.try(dynamic.field("pageInfo", Ok)(history))
        use nextpage <- result.try(dynamic.field("hasNextPage", dynamic.bool)(
          pageinfo,
        ))

        let cursor = case nextpage {
          False -> Error(Nil)
          True ->
            dynamic.field("endCursor", dynamic.string)(pageinfo)
            |> result.map_error(fn(_) { Nil })
        }
        use contributors <- result.try(dynamic.field(
          "nodes",
          dynamic.list(of: decode),
        )(history))

        Ok(Contributorspage(
          nextpage_cursor: cursor,
          contributor_list: contributors,
        ))
      }
      Error(_) -> {
        Ok(Contributorspage(nextpage_cursor: Error(Nil), contributor_list: []))
      }
    }
  }

  json.decode(response_json, decoder)
}
