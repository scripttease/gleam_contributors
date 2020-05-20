// to add lib open rebar.config, add the deps
import gleam/result
import gleam/dynamic.{Dynamic}

external fn decode_json_from_string(String) -> Dynamic =
  "jsone" "decode"

pub fn hello_world() -> String {
  "Hello, from gleam_contributors!"
}

// api call to get first page

// to see if there is a cursor in the data ie a next page or nothing
pub type Sponsorspage { 
  Sponsorspage(nextpage_cursor: Result(String, Nil))
}

// a result is like an option. error is string.
pub fn parse(sponsors: String) -> Result(Sponsorspage, String) {
  let res = decode_json_from_string(sponsors)
  try data = dynamic.field(res, "data")
  try user = dynamic.field(data, "user")
  try spons = dynamic.field(user, "sponsorshipsAsMaintainer")
  try page = dynamic.field(spons, "pageInfo")

  try dynamic_nextpage = dynamic.field(page, "hasNextPage")
  try nextpage = dynamic.bool(dynamic_nextpage)

  let cursor = case nextpage {
    False -> Error(Nil)
    True -> {
      dynamic.field(page, "endCursor")
      |> result.then(dynamic.string)
      |> result.map_error(fn(_) { Nil })


    }
  }
  Ok(Sponsorspage(nextpage_cursor: cursor))
}
