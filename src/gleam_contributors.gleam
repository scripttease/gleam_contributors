// to add lib open rebar.config, add the deps
import gleam/result
import gleam/dynamic.{Dynamic}
import gleam/httpc.{Text, Response}
import gleam/http.{Post}
import gleam/map
import gleam/string
import gleam/list
import gleam/int
import gleam/io
import gleam/option.{Option}

pub external type OkAtom

// Naming the application for Erlang to start processes required in app, such as
// inets. Will convert Camel to Snake case.
pub type Application {
  GleamContributors
}

//Erlang module Application fn ensure_all_started, see above
pub external fn start_application_and_deps(Application) -> OkAtom =
  "application" "ensure_all_started"

//Erlang library for json encoding
external fn encode_json(a) -> String =
  "jsone" "encode"

//Creates type to interrogate response to sponsor query
pub type Sponsor {
  Sponsor(
    name: String,
    github: String,
    avatar: String,
    website: Result(String, Nil),
    cents: Int,
  )
}

// TODO logic for api call to get first page then next...
// Type required to see if there is a cursor in the data and a next page. If so, another API request is required
pub type Sponsorspage {
  Sponsorspage(
    nextpage_cursor: Result(String, Nil),
    sponsor_list: List(Sponsor),
  )
}

//concatenates query params into query
pub fn query_sponsors(cursor: String, num_results: String) -> String {
  string.concat(
    [
      "{
  user(login: \"lpil\") {
    sponsorshipsAsMaintainer(after: \"",
      cursor,
      "\", first: ",
      num_results,
      ") {
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
}",
    ],
  )
}

//concatenates optional query params into query
pub fn construct_sponsor_query(
  cursor: Option(String),
  num_results: Option(String),
) -> String {
  let use_cursor = case cursor {
    option.Some(cursor) -> string.concat(["\"", cursor, "\""])
    _ -> "null"
  }

  let use_num_results = case num_results {
    option.Some(num_results) -> num_results
    _ -> "100"
  }

  string.concat(
    [
      "{
  user(login: \"lpil\") {
    sponsorshipsAsMaintainer(after: ",
      use_cursor,
      ", first: ",
      use_num_results,
      ") {
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
}",
    ],
  )
}

//TODO fn that maps over sponsor_list and extracts into a sortable datatype, then sorts then converst to string (or iodata?) the relevant info.
// something like map.sponsor_list ( list.append(sponsor.name) )
//ideally takes a List(Sponsors) and returns a List(String), that is sorted, then a string?
pub fn extract_sponsors(page: Sponsorspage) -> List(String) {
  list.map(
    page.sponsor_list,
    fn(sponsor: Sponsor) {
      string.concat(["[", sponsor.name, "]", "(", sponsor.github, ")"])
    },
  )
  |> list.sort(string.compare)
}

pub fn extract_sponsors_500c(page: Sponsorspage) -> List(String) {
  let upto_500_list = list.filter(
    page.sponsor_list,
    fn(sponsor: Sponsor) { sponsor.cents <= 500 },
  )

  list.map(
    upto_500_list,
    fn(sponsor: Sponsor) {
      string.concat(["[", sponsor.name, "]", "(", sponsor.github, ")"])
    },
  )
  |> list.sort(string.compare)
}

// would be better to use try_decode but its a thruple...
// TODO convert to try_decode OR check for valid json response.
external fn decode_json_from_string(String) -> Dynamic =
  "jsone" "decode"

// Decode sponsor section of the response JSON (List of hashmaps)
// uses dynamic module.
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

  Ok(
    Sponsor(
      name: name,
      github: github,
      avatar: avatar,
      website: website,
      cents: cents,
    ),
  )
}

// TODO call this fn.
// Takes response json string and reurns a Sponsorspage by extracting values using the dynamic module. 
pub fn parse_sponsors(sponsors_json: String) -> Result(Sponsorspage, String) {
  let res = decode_json_from_string(sponsors_json)
  try data = dynamic.field(res, "data")
  try user = dynamic.field(data, "user")
  try spons = dynamic.field(user, "sponsorshipsAsMaintainer")
  try page = dynamic.field(spons, "pageInfo")

  try dynamic_nextpage = dynamic.field(page, "hasNextPage")
  try nextpage = dynamic.bool(dynamic_nextpage)

  // TODO should this be an error? Give an error msg?
  let cursor = case nextpage {
    False -> Error(Nil)
    True -> dynamic.field(page, "endCursor")
      |> // only returns if result(Ok(_))
      result.then(dynamic.string)
      |> // only called if there is no nextpage, ie result -> Error(Nil)
      result.map_error(fn(_) { Nil })
  }

  try nodes = dynamic.field(spons, "nodes")
  try sponsors = dynamic.list(nodes, decode_sponsor)

  Ok(Sponsorspage(nextpage_cursor: cursor, sponsor_list: sponsors))
}

pub fn call_api(token: String, query: String) -> Result(String, String) {
  io.debug(start_application_and_deps(GleamContributors))

  let json = map.from_list([tuple("query", query)])

  let result = httpc.request(
    method: Post,
    url: "https://api.github.com/graphql",
    headers: [
      tuple("Authorization", string.append("bearer ", token)),
      tuple("User-Agent", "gleam contributors"),
    ],
    body: Text("application/json", encode_json(json)),
  )
  let response = case result {
    Ok(response) -> {
      io.println(response.body)
      Ok(response.body)
    }
    Error(e) -> {
      io.debug(e)
      Error("There was an error during the POST request :(\n")
    }
  }
  response
}

pub fn call_api_for_sponsors(
  token: String,
  cursor: Option(String),
  sponsor_list_md: List(String),
) -> Result(List(String), String) {
  let query = construct_sponsor_query(cursor, option.None)
  try response_json = call_api(token, query)
  try sponsorpage = parse_sponsors(response_json)
  let sponsor_list_md = list.append(
    sponsor_list_md,
    extract_sponsors(sponsorpage),
  )

  case sponsorpage.nextpage_cursor {
    Ok(cursor) -> {
      let cursor_opt = option.Some(cursor)
      call_api_for_sponsors(token, cursor_opt, sponsor_list_md)
    }
    _ -> Ok(sponsor_list_md)
  }
}

//TODO rename this
// takes API token, cursor and num_results from stdin (when it is called by fn `main`) and constructs a query, converts it to json and makes a POST request to the Github API.)
//TODO seperate concerns so only calls API 
// OkAtom is return value for print to stdout
// TODO Do_stuff needs to work for contribs query too. doesn't need to have query or cursor in command line these should  be added by the sponsorpage and another query made if required.
// therefor the only USER required input should be the date of the previous release
// other fns will need to be able to call it with other inputs thogh such as diff repo names and diff queries.
// In fact the api call just needs the token in the command line. 
// other fns may need diff args to construct their queries.
pub fn do_stuff(token: String, cursor: String, num_results: String) -> Nil {
  io.debug(start_application_and_deps(GleamContributors))

  let query = query_sponsors(cursor, num_results)

  let json = map.from_list([tuple("query", query)])

  let result = httpc.request(
    method: Post,
    url: "https://api.github.com/graphql",
    headers: [
      tuple("Authorization", string.append("bearer ", token)),
      tuple("User-Agent", "gleam contributors"),
    ],
    body: Text("application/json", encode_json(json)),
  )

  // let sponsor_list = parse_sponsors(result.body)
  // Prints response or error to stdout
  case result {
    // Ok(response) -> print(parse_sponsors(response.body))
    // Ok(response) -> print(sponsor_list)
    // TODO create fn to turn parse_sponsors(result.body) into a string so can print to stdout. Order by 5, 10, 20, 50+
    // TODO combine the sponsors with contributors add that to the string to print out. Sort alphabetically.
    Ok(response) -> io.println(response.body)
    Error(e) -> {
      io.debug(e)
      io.println("There was an error during the POST request :(")
    }
  }

  io.print("\n")
}

pub fn parse_args(
  args: List(String),
) -> Result(tuple(String, String, String), String) {
  case args {
    [token, cursor, num_results] -> Ok(tuple(token, cursor, num_results))
    _ -> Error("Usage: _buildfilename $TOKEN $CURSOR $NUM")
  }
}

// Entrypoint fn for Erlang escriptize. Must be called `main`. Takes a
// List(String) formed of whitespace seperated commands to stdin.
// Top level, returns Result and handles error-handling
pub fn main(args: List(String)) -> Nil {
  let result = {
    try tuple(token, _cursor, _num_results) = parse_args(args)
    // let stuff = do_stuff(token, cursor, num_results)
    // Ok(stuff)
    try stuff = call_api_for_sponsors(token, option.None, [])
    Ok(stuff)
  }
  // Implement all fn calls here.
  // try json = get_sponsors_from_api(token, cursor)
  // try sponsorspage = parse_sponsors_api_body(json)
  case result {
    Ok(stuff) -> {
      io.debug(stuff)
      io.println("Done!")
    }
    Error(e) -> io.println(e)
  }
}

pub type Contributor {
  Contributor(name: String, github: String)
}

// could include avatarURl and websiteUrl if required
pub type Contributorspage {
  Contributorspage(
    nextpage_cursor: Result(String, Nil),
    contributor_list: List(Contributor),
  )
}
