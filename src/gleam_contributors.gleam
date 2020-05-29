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

  // the extract sponsors fn should be taking a sponsor_list not sponsorpage? Is this overwriting?
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
//TODO BROKEN this version is null and it cant be...
pub fn construct_release_query(version: String) -> String {
  let use_version = string.concat(["\"", version, "\""])

  //   _ -> "null"
  // }
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

  //TODO where do these come from is this the problem??
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
  let dupes = list.fold(
    over: slist,
    from: set.new(),
    with: fn(elem, acc) { set.insert(acc, elem) },
  )
  // io.debug("input list")
  // io.debug(slist)
  // io.debug("dupes")
  // io.debug(dupes)
  dupes
}

pub fn extract_contributors(page: Contributorspage) -> List(String) {
  let initial_list = list.map(
    page.contributor_list,
    fn(contributor: Contributor) {
      string.concat(["[", contributor.name, "](", contributor.github, ")"])
    },
  )
  let sorted = list.sort(initial_list, string.compare)

  let filtered = remove_duplicates(sorted)
  let filter_sorted_contribs = set.to_list(filtered)

  // io.debug("Filtered and Sorted Contributors")
  // io.debug(filter_sorted_contribs)
  filter_sorted_contribs
}

pub fn call_api_for_contributors(
  token: String,
  from: String,
  to: String,
  // from_version: Option(String),
  // to_version: Option(String),
  cursor: Option(String),
  contributor_list_md: List(String),
) -> Result(List(String), String) {
  //construct contributors query
  let query = construct_contributor_query(cursor, from, to, option.None)

  try response_json = call_api(token, query)

  //parse response to query 
  try contributorpage = parse_contributors(response_json)

  let contributor_list_md = list.append(
    contributor_list_md,
    extract_contributors(contributorpage),
  )

  case contributorpage.nextpage_cursor {
    Ok(cursor) -> {
      let cursor_opt = option.Some(cursor)
      call_api_for_contributors(
        token,
        from,
        to,
        cursor_opt,
        contributor_list_md,
      )
    }
    _ -> Ok(contributor_list_md)
  }
}

//TODO is contributors sorted first??
//TODO ideally final string output looks like 
// from Version (date) to Version (date)
// All sponsors and contributors
// List
// Just contributors
// Sponsors 500
// Sponsors 100...
// Contributors to gleam lang only?
// Contributors to gleam-experiments?
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

// Entrypoint fn for Erlang escriptize. Must be called `main`. Takes a
// List(String) formed of whitespace seperated commands to stdin.
// Top level, handles error-handling
pub fn main(args: List(String)) -> Nil {
  // try returns early so they have to be in a let block as this fn returns Nil.
  let result = {
    try tuple(token, from_version, to_version) = parse_args(args)
    //get from and to dates from version numbers
    //BROKEN
    try datetimes = api_release_datetimes(token, from_version, to_version)
    // THIS BIT IS BROKEN
    let tuple(from, to) = datetimes
    // let date_from = case datetimes {
    //   tuple(from, to) -> from
    //   _ -> "null"
    // }
    // let date_to = case datetimes {
    //   Ok(tuple(from, to)) -> to
    //   _ -> "null"
    // }
    // io.debug("CALL API FOR SPONSORS")
    try sponsors = call_api_for_sponsors(token, option.None, [])
    // io.debug("CALL API FOR CONTRIBUTORS")
    // TODO THIS FAILS
    try contributors = call_api_for_contributors(
      token,
      from,
      to,
      option.None,
      [],
    )
    let combo = combine_and_sort_lists_to_string(sponsors, contributors)
    // io.debug("COMBINED LISTS")
    // io.debug(combined_lists)
    Ok(combo)
  }

  case result {
    Ok(combo) -> // io.debug("COMBO LIST")
    // io.debug(combo)
    io.println("Done!")
    Error(e) -> io.println(e)
  }
}
