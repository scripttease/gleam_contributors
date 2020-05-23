// to add lib open rebar.config, add the deps
import gleam/result
import gleam/dynamic.{Dynamic}
import gleam/httpc.{Text}
import gleam/http.{Post}
import gleam/map
import gleam/string
import gleam/list
import gleam/int

pub external type OkAtom

pub external fn debug_print(anything) -> OkAtom =
  "erlang" "display"

pub external fn print(String) -> OkAtom =
  "io" "fwrite"

pub type Application {
  GleamContributors
}
pub external fn start_application_and_deps(Application) -> OkAtom =
  "application" "ensure_all_started"

external fn encode_json(a) -> String =
  "jsone" "encode"

pub fn query_sponsors(cursor: String, num_results: String) -> String {

  // let num_results_string = int.to_string(num_results)

  string.concat([
"{
  user(login: \"lpil\") {
    sponsorshipsAsMaintainer(after: \"", cursor, "\", first: ", num_results, ") {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        sponsorEntity {
          ... on User {
            name
            url
            avatarUrl
            websiteUrl
          }
          ... on Organization {
            name
            avatarUrl
            websiteUrl
          }
        }
        tier {
          monthlyPriceInCents
        }
      }
    }
  }
}"
  ])
}

pub fn do_stuff(token, cursor, num_results) {
  debug_print(start_application_and_deps(GleamContributors))

  let query = query_sponsors(cursor, num_results)

  let json = map.from_list([tuple("query", query)]) 

//   "{
//   user(login: \"lpil\") {
//     sponsorshipsAsMaintainer(after: \"Ng\", first: 2) {
//       pageInfo {
//         hasNextPage
//         endCursor
//       }
//       nodes {
//         sponsorEntity {
//           ... on User {
//             name
//             url
//             avatarUrl
//             websiteUrl
//           }
//           ... on Organization {
//             name
//             avatarUrl
//             websiteUrl
//           }
//         }
//         tier {
//           monthlyPriceInCents
//         }
//       }
//     }
//   }
// }")])

  let result = httpc.request(
    method: Post,
    url: "https://api.github.com/graphql",
    headers: [tuple("Authorization", string.append("bearer ",token)), tuple("User-Agent", "gleam contributors")],
    body: Text("application/json", encode_json(json)),
  )

  case result {
    Ok(response) -> print(response.body)
    Error(e) -> {
      debug_print(e)
      print("There was an error :(\n")
    }
  }

  // let rest_args = string.join(test_io, "\n")

  // print("\n")
  // print(rest_args)
  print("\n")
}

pub fn main(args: List(String)) {
  case args {
    [token, cursor, num_results] -> do_stuff(token, cursor, num_results)
    _ -> {
      print("Usage: _buildfilename $TOKEN $CURSOR $NUM")
      print("\n")
    }
  }
}

// would be better to use try_decode but its a thruple...
external fn decode_json_from_string(String) -> Dynamic =
  "jsone" "decode"


pub type Sponsor {
  Sponsor(
    name: String,
    github: String,
    avatar: String,
    website: Result(String, Nil),
    cents: Int,
  )
}

// Decode the Sponsor section of the JSON (List of hashmaps)
pub fn decode_sponsor(json_obj: Dynamic) -> Result(Sponsor, String) {
  try entity = dynamic.field(json_obj, "sponsorEntity")

  try dynamic_name = dynamic.field(entity, "name")
  try name = dynamic.string(dynamic_name)

  try dynamic_avatar = dynamic.field(entity, "avatarUrl")
  try avatar = dynamic.string(dynamic_avatar)

  try dynamic_github = dynamic.field(entity, "url")
  try github = dynamic.string(dynamic_github)

  try dynamic_website = dynamic.field(entity, "websiteUrl")
  let website = dynamic.string(dynamic_website)
    |> result.map_error(fn(_) { Nil })

  try tier = dynamic.field(json_obj, "tier")
  try dynamic_cents = dynamic.field(tier, "monthlyPriceInCents")
  try cents = dynamic.int(dynamic_cents)

  Ok(Sponsor(name: name, github: github, avatar: avatar, website: website, cents: cents))
}

// api call to get first page
// to see if there is a cursor in the data ie a next page or nothing
pub type Sponsorspage {
  Sponsorspage(
    nextpage_cursor: Result(String, Nil),
    sponsor_list: List(Sponsor),
  )
}

// a result is like an option. error is string.
// todo put the parse_sponsors in main?
pub fn parse_sponsors(sponsors_json: String) -> Result(Sponsorspage, String) {
  let res = decode_json_from_string(sponsors_json)
  try data = dynamic.field(res, "data")
  try user = dynamic.field(data, "user")
  try spons = dynamic.field(user, "sponsorshipsAsMaintainer")
  try page = dynamic.field(spons, "pageInfo")

  try dynamic_nextpage = dynamic.field(page, "hasNextPage")
  try nextpage = dynamic.bool(dynamic_nextpage)

  let cursor = case nextpage {
    False -> Error(Nil)
    True -> dynamic.field(page, "endCursor")
      |> result.then(dynamic.string)
      |> result.map_error(fn(_) { Nil })
  }

  try nodes = dynamic.field(spons, "nodes")
  try sponsors = dynamic.list(nodes, decode_sponsor)

  Ok(Sponsorspage(nextpage_cursor: cursor, sponsor_list: sponsors))
}

pub type Contributor {
  Contributor(
    name: String,
    github: String,
    // could include avatarURl and websiteUrl if required
  )
}

pub type Contributorspage {
  Contributorspage(
    nextpage_cursor: Result(String, Nil),
    contributor_list: List(Contributor),
  )
}
