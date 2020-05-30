// to add lib open rebar.config, add the deps
import gleam/result
import gleam/dynamic.{Dynamic}
import gleam/httpc.{Text, Response}
import gleam/http.{Post}
import gleam/map
import gleam/string
import gleam/set.{Set}
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

// Type required to see if there is a cursor in the data and a next page. If so, another API request is required
pub type Sponsorspage {
  Sponsorspage(
    nextpage_cursor: Result(String, Nil),
    sponsor_list: List(Sponsor),
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

pub fn list_sponsor_to_list_string(
  sponsors_list: List(Sponsor),
) -> List(String) {
  list.map(
    sponsors_list,
    fn(sponsor: Sponsor) {
      string.concat(["[", sponsor.name, "]", "(", sponsor.github, ")"])
    },
  )
  |> //TODO add lowercase sort
  list.sort(string.compare)
}

pub fn filter_sponsors(lst: List(Sponsor), dollars) -> List(Sponsor) {
  let cents = dollars * 100
  list.filter(lst, fn(sponsor: Sponsor) { sponsor.cents >= cents })
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
  sponsor_list: List(Sponsor),
) -> Result(List(Sponsor), String) {
  let query = construct_sponsor_query(cursor, option.None)

  try response_json = call_api(token, query)
  try sponsorpage = parse_sponsors(response_json)

  // the extract sponsors fn should be taking a sponsor_list not sponsorpage? Is this overwriting?
  let sponsor_list = list.append(sponsor_list, sponsorpage.sponsor_list)

  case sponsorpage.nextpage_cursor {
    Ok(cursor) -> {
      let cursor_opt = option.Some(cursor)
      call_api_for_sponsors(token, cursor_opt, sponsor_list)
    }
    _ -> Ok(sponsor_list)
  }
}

// handles command line stdin
pub fn parse_args(
  args: List(String),
) -> Result(tuple(String, String, String), String) {
  case args {
    [
      token,
      from_version,
      to_version,
    ] -> Ok(tuple(token, from_version, to_version))
    _ -> Error(
      "Usage: _buildfilename $TOKEN $FROM_VESRION $TO_VESRION \n version in format v0.3.0",
    )
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

// Can this actually be null here?
pub fn construct_release_query(version: String) -> String {
  let use_version = string.concat(["\"", version, "\""])

  string.concat(
    [
      "{
  repository(name: \"gleam\", owner: \"gleam-lang\") {
    release(tagName: ",
      use_version,
      ") {
      tag {
        target {
          ... on Commit {
            committedDate
          }
        }
      }
    }
  }
}",
    ],
  )
}

pub fn parse_datetime(json: String) -> Result(String, String) {
  let res = decode_json_from_string(json)
  try data = dynamic.field(res, "data")
  try repo = dynamic.field(data, "repository")
  try release = dynamic.field(repo, "release")
  try tag = dynamic.field(release, "tag")
  try target = dynamic.field(tag, "target")
  try dynamic_date = dynamic.field(target, "committedDate")
  try date = dynamic.string(dynamic_date)

  Ok(date)
}

// For this query to get datetimes they CANNOT be null in the API call
pub fn api_release_datetimes(
  token: String,
  from_version: String,
  to_version: String,
) -> Result(tuple(String, String), String) {
  let query_from = construct_release_query(from_version)
  let query_to = construct_release_query(to_version)

  try response_json = call_api(token, query_from)
  try from_datetime = parse_datetime(response_json)

  try response_json = call_api(token, query_to)
  try to_datetime = parse_datetime(response_json)

  Ok(tuple(from_datetime, to_datetime))
}

//TODO org gleam-experiments!!!
//TODO from_version and to_v.. should be from_datetime...
//TODO so this needs to call the api...
pub fn construct_contributor_query(
  cursor: Option(String),
  from_date: String,
  to_date: String,
  count: Option(String),
) -> String {
  // of use in tests, otherwise 100 results
  let use_cursor = case cursor {
    option.Some(cursor) -> string.concat(["\"", cursor, "\""])
    _ -> "null"
  }

  let use_from_date = string.concat(["\"", from_date, "\""])
  let use_to_date = string.concat(["\"", to_date, "\""])

  // let use_to_date = case to_date {
  //   option.Some(to_date) -> string.concat(["\"", to_date, "\""])
  //   _ -> "null"
  // }
  let use_count = case count {
    option.Some(count) -> count
    _ -> "100"
  }

  string.concat(
    [
      "{
  repository(owner: \"gleam-lang\", name: \"gleam\") {
    object(expression: \"master\") {
      ... on Commit {
        history(since: ",
      use_from_date,
      ", until: ",
      use_to_date,
      ", after: ",
      use_cursor,
      ", first: ",
      use_count,
      ") {
          totalCount
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            author {
              name
              user {
                login
                url
              }
            }
          }
        }
      }
    }
  }
}",
    ],
  )
}

pub fn decode_contributor(json_obj: Dynamic) -> Result(Contributor, String) {
  try author = dynamic.field(json_obj, "author")
  try dynamic_name = dynamic.field(author, "name")
  try user = dynamic.field(author, "user")
  try dynamic_github = dynamic.field(user, "url")

  try name = dynamic.string(dynamic_name)
  try github = dynamic.string(dynamic_github)

  Ok(Contributor(name: name, github: github))
}

pub fn parse_contributors(
  response_json: String,
) -> Result(Contributorspage, String) {
  let res = decode_json_from_string(response_json)
  try data = dynamic.field(res, "data")
  try repo = dynamic.field(data, "repository")
  try object = dynamic.field(repo, "object")
  try history = dynamic.field(object, "history")
  try pageinfo = dynamic.field(history, "pageInfo")

  try dynamic_nextpage = dynamic.field(pageinfo, "hasNextPage")
  try nextpage = dynamic.bool(dynamic_nextpage)

  let cursor = case nextpage {
    False -> Error(Nil)
    True -> dynamic.field(pageinfo, "endCursor")
      |> result.then(dynamic.string)
      |> result.map_error(fn(_) { Nil })
  }

  try nodes = dynamic.field(history, "nodes")
  // make fn decode_contributor
  try contributors = dynamic.list(nodes, decode_contributor)

  Ok(Contributorspage(nextpage_cursor: cursor, contributor_list: contributors))
}

pub fn remove_duplicates(slist: List(String)) -> Set(String) {
  list.fold(
    over: slist,
    from: set.new(),
    with: fn(elem, acc) { set.insert(acc, elem) },
  )
}

//TODO can change to 'record' if give lists same field name
pub fn list_contributor_to_list_string(lst: List(Contributor)) -> List(String) {
  let initial_list = list.map(
    lst,
    fn(contributor: Contributor) {
      string.concat(["[", contributor.name, "](", contributor.github, ")"])
    },
  )
  //add string compare lowercase
  //TODO can the filter and sort be handled later or is here best? TODO separate them out
  let sorted = list.sort(initial_list, string.compare)

  remove_duplicates(sorted)
  |> set.to_list
}

pub fn call_api_for_contributors(
  token: String,
  from: String,
  to: String,
  // from_version: Option(String),
  // to_version: Option(String),
  cursor: Option(String),
  contributor_list: List(Contributor),
) -> Result(List(Contributor), String) {
  //get from and to dates from version numbers
  // let datetimes = api_release_datetimes(token, from_version, to_version)
  // let use_from = case datetimes {
  //   Ok(tuple(from, to)) -> from
  //   _ -> "null"
  // }
  // let use_to = case datetimes {
  //   Ok(tuple(from, to)) -> to
  //   _ -> "null"
  // }
  //construct contributors query
  let query = construct_contributor_query(cursor, from, to, option.None)

  try response_json = call_api(token, query)

  //parse response to query 
  try contributorpage = parse_contributors(response_json)

  let contributor_list = list.append(
    contributor_list,
    contributorpage.contributor_list,
  )

  case contributorpage.nextpage_cursor {
    Ok(cursor) -> {
      let cursor_opt = option.Some(cursor)
      call_api_for_contributors(token, from, to, cursor_opt, contributor_list)
    }
    _ -> Ok(contributor_list)
  }
}

pub fn combine_and_sort_lists_to_string(
  sponsors: List(String),
  contributors: List(String),
) -> String {
  let combo = list.append(sponsors, contributors)
  let filtered = set.to_list(set.from_list(combo))
  //TODO seperate and test ???
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  let sorted_filtered = list.sort(filtered, case_insensitive_string_compare)

  let estring = ""
  let string_combo = list.fold(
    sorted_filtered,
    estring,
    fn(elem, acc) {
      acc
      |> string.append("\n")
      |> string.append(elem)
    },
  )
  io.print("String combo")
  io.print(string_combo)
  string_combo
}

pub fn filter_sort(lst: List(String)) -> List(String) {
  let filtered = set.to_list(set.from_list(lst))
  //TODO seperate and test ???
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  list.sort(filtered, case_insensitive_string_compare)
}

pub fn to_output_string(lst: List(String)) -> String {
  let estring = ""
  let string_out = list.fold(
    lst,
    estring,
    fn(elem, acc) {
      acc
      |> string.append("\n")
      |> string.append(elem)
    },
  )
  string_out
}

// Entrypoint fn for Erlang escriptize. Must be called `main`. Takes a
// List(String) formed of whitespace seperated commands to stdin.
// Top level, handles error-handling
pub fn main(args: List(String)) -> Nil {
  // try returns early so we need a let block, otherwise the fn would need t return the result for the try, rather than nil. All of the trys in the let block must have the same error (fail) type for this reason.
  let result = {
    // Parses command line arguments
    try tuple(token, from_version, to_version) = parse_args(args)
    // From and to dates from version numbers
    try datetimes = api_release_datetimes(token, from_version, to_version)
    let tuple(from, to) = datetimes
    // Calls API for Sponsors. Returns List(String) if Ok.
    try sponsors = call_api_for_sponsors(token, option.None, [])
    // Calls API for Contributors. Returns List(String) if Ok.
    try contributors = call_api_for_contributors(
      token,
      from,
      to,
      option.None,
      [],
    )
    // TODO extract filter and sort logic from these initial lists
    let str_lst_contributors = list_contributor_to_list_string(contributors)
    //TODO URGENT Add arg here for filtering by amount
    let str_lst_sponsors = list_sponsor_to_list_string(sponsors)
    let str_sponsors_contributors = to_output_string(
      filter_sort(list.append(str_lst_sponsors, str_lst_contributors)),
    )
    //TODO filter sponsor list here. Contruct fn to return the avatar as well as name and url in the required format
    //Construct format to generate this output format as a string and append it to the existing output string
    //TODO this and a case for each api so see what fails?
    Ok(str_sponsors_contributors)
  }

  case result {
    Ok(str_sponsors_contributors) -> {
      io.print(str_sponsors_contributors)
      io.println("Done!")
    }
    Error(e) -> io.println(e)
  }
}
