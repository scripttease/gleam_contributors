// to add lib open rebar.config, add the deps
import gleam/result
import gleam/dynamic.{Dynamic}

external fn decode_json_from_string(String) -> Dynamic =
  "jsone" "decode"

pub fn hello_world() -> String {
  "Hello, from gleam_contributors!"
}

pub type Sponsor {
  Sponsor(name: String)
}

pub fn decode_sponsor(json_obj: Dynamic) ->  Result(Sponsor, String) {
  try entity = dynamic.field(json_obj, "sponsorEntity")
  try dynamic_name = dynamic.field(entity, "name")
  try name = dynamic.string(dynamic_name)

  // try tier = dynamic.field(json_obj, "tier")
  Ok(Sponsor(name: name))
}
// api call to get first page

// to see if there is a cursor in the data ie a next page or nothing
pub type Sponsorspage { 
  Sponsorspage( nextpage_cursor: Result(String, Nil),
                sponsor_list: List(Sponsor),
                )
}

// a result is like an option. error is string.
pub fn parse(sponsors_json: String) -> Result(Sponsorspage, String) {
  let res = decode_json_from_string(sponsors_json)
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

  try nodes = dynamic.field(spons, "nodes")
  try sponsors = dynamic.list(nodes, decode_sponsor)

  Ok(Sponsorspage(nextpage_cursor: cursor, sponsor_list: sponsors))
}
