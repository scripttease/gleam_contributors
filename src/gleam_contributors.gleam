// Import Gleam StdLib modules here.
// To add an Erlang library, add deps to rebar.config. To use them create an external fn.
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
import gleam/option.{Option, Some, None}

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

//Type to interrogate a single page response from the API and determine if
//there is further pagination. The github API will return a maximum of 100
//results per page, however if there are more pages, the endCursor can be used
//as a starting point for the next query.
pub type Sponsorspage {
  Sponsorspage(
    nextpage_cursor: Result(String, Nil),
    sponsor_list: List(Sponsor),
  )
}

//Concatenates optional query params into sponsor query
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

// TODO convert to try_decode OR check for valid json response.
external fn decode_json_from_string(String) -> Dynamic =
  "jsone" "decode"

// Decodes sponsor section of the response JSON (List of treemaps)
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

// Takes response json string and returns a Sponsorspage  
pub fn parse_sponsors(sponsors_json: String) -> Result(Sponsorspage, String) {
  let res = decode_json_from_string(sponsors_json)
  try data = dynamic.field(res, "data")
  try user = dynamic.field(data, "user")
  try spons = dynamic.field(user, "sponsorshipsAsMaintainer")
  try page = dynamic.field(spons, "pageInfo")

  try dynamic_nextpage = dynamic.field(page, "hasNextPage")
  try nextpage = dynamic.bool(dynamic_nextpage)

  // TODO error message string?
  let cursor = case nextpage {
    False -> Error(Nil)
    True -> dynamic.field(page, "endCursor")
      |> // only returns if result(Ok(_))
      result.then(dynamic.string)
      |> // only called if there is no nextpage, ie result -> Error(Nil)
      result.map_error(fn(_) { Nil })
  }

  // TODO There is a bug in the formatter here, as it puts comments after pipes. Can fix in compiler
  try nodes = dynamic.field(spons, "nodes")
  try sponsors = dynamic.list(nodes, decode_sponsor)

  Ok(Sponsorspage(nextpage_cursor: cursor, sponsor_list: sponsors))
}

// Calls the Github API v4 (GraphQL)
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
  // TODO error(e) 
  let response = case result {
    Ok(response) -> {
      io.println(query)
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

  //The sponsor_list acts as an accumluator on the recursive call of the fn, and is therefore passed in as an arg.
  let sponsor_list = list.append(sponsor_list, sponsorpage.sponsor_list)

  case sponsorpage.nextpage_cursor {
    Ok(cursor) -> {
      let cursor_opt = option.Some(cursor)
      call_api_for_sponsors(token, cursor_opt, sponsor_list)
    }
    _ -> Ok(sponsor_list)
  }
}

// Handles command line StdIn arguments
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
      "Usage: _buildfilename $TOKEN $FROM_VESRION $TO_VESRION \n(Version should be in format `v0.3.0`)",
    )
  }
}

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

pub type Repo {
  Repo(org: String, name: String)
}

// Constructs query to API to get the release datetime from the given version
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

//Converts response json.
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

pub fn call_api_for_datetimes(
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

pub fn construct_contributor_query(
  cursor: Option(String),
  from_date: String,
  to_date: String,
  count: Option(String),
  org: String,
  repo_name: String,
) -> String {
  let use_cursor = case cursor {
    option.Some(cursor) -> string.concat(["\"", cursor, "\""])
    _ -> "null"
  }

  let use_from_date = string.concat(["\"", from_date, "\""])
  let use_to_date = string.concat(["\"", to_date, "\""])

  // Optional count is for use in integration tests. Otherwise the default is  100 results
  let use_count = case count {
    option.Some(count) -> count
    _ -> "100"
  }

  let use_org = string.concat(["\"", org, "\""])
  let use_repo_name = string.concat(["\"", repo_name, "\""])

  string.concat(
    [
      "{
  repository(owner: ",
      use_org,
      ", name: ",
      use_repo_name,
      ") {
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

// This is still parsing the response json into Gleam types, see
// parse_contributors, but it is the contributor section only. To make the parse
// function more readable
pub fn decode_contributor(json_obj: Dynamic) -> Result(Contributor, String) {
  try author = dynamic.field(json_obj, "author")
  try dynamic_name = dynamic.field(author, "name")
  try name = dynamic.string(dynamic_name)

  let github = option.from_result(
    {
      try user = dynamic.field(author, "user")
      try dynamic_github = dynamic.field(user, "url")
      dynamic.string(dynamic_github)
    },
  )

  Ok(Contributor(name: name, github: github))
}

// Converts response json into Gleam type. Represents one page of contributors
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

//Uses the uniqueness property of sets to remove duplicates from list
pub fn remove_duplicates(slist: List(String)) -> Set(String) {
  list.fold(
    over: slist,
    from: set.new(),
    with: fn(elem, acc) { set.insert(acc, elem) },
  )
}

pub fn list_contributor_to_list_string(lst: List(Contributor)) -> List(String) {
  let initial_list = list.map(
    lst,
    fn(contributor: Contributor) {
      case contributor.github {
        Some(url) -> string.concat(["[", contributor.name, "](", url, ")"])
        None -> contributor.name
      }
    },
  )

  //TODO can the filter and sort be handled later or is here best?
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  let sorted = list.sort(initial_list, case_insensitive_string_compare)

  remove_duplicates(sorted)
  |> set.to_list
}

pub fn call_api_for_contributors(
  token: String,
  from: String,
  to: String,
  cursor: Option(String),
  contributor_list: List(Contributor),
  org: String,
  repo_name: String,
) -> Result(List(Contributor), String) {
  let query = construct_contributor_query(
    cursor,
    from,
    to,
    option.None,
    org,
    repo_name,
  )

  try response_json = call_api(token, query)

  try contributorpage = parse_contributors(response_json)

  let contributor_list = list.append(
    contributor_list,
    contributorpage.contributor_list,
  )

  case contributorpage.nextpage_cursor {
    Ok(cursor) -> {
      let cursor_opt = option.Some(cursor)
      call_api_for_contributors(
        token,
        from,
        to,
        cursor_opt,
        contributor_list,
        org,
        repo_name,
      )
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
  //TODO could separate this into another fn
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  let sorted_filtered = list.sort(filtered, case_insensitive_string_compare)

  let estring = ""

  list.fold(
    sorted_filtered,
    estring,
    fn(elem, acc) {
      acc
      |> string.append("\n")
      |> string.append(elem)
    },
  )
}

pub fn filter_sort(lst: List(String)) -> List(String) {
  let filtered = set.to_list(set.from_list(lst))

  //TODO seperate out?
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  list.sort(filtered, case_insensitive_string_compare)
}

// We want main to output a single string that can be copy pasted into a
// Markdown file. After all the data munging is done, the final step is to
// create a single string in the desired format. Sorting and filtering cannot be
// done on the string so they must be done first.
//TODO add dates at top. Add filtered sponsors
// Add - at beginning of line
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

// TODO Add nextpage cursor for when number of repos exceed 100 results
pub fn parse_repos(
  repos_json: String,
  org_n: String,
) -> Result(List(Repo), String) {
  let res = decode_json_from_string(repos_json)
  try data = dynamic.field(res, "data")
  try org = dynamic.field(data, "organization")
  try repos = dynamic.field(org, "repositories")
  try nodes = dynamic.field(repos, "nodes")
  //dynamic.list needs to take a fn
  try repo_string_list = dynamic.list(
    nodes,
    fn(repo) {
      try dynamic_name = dynamic.field(repo, "name")
      dynamic.string(dynamic_name)
    },
  )

  let list_repo = list.map(
    repo_string_list,
    fn(string) { Repo(org: org_n, name: string) },
  )

  Ok(list_repo)
}

// TODO take org option for gleam-experiments
pub fn construct_repo_query(org: String) -> String {
  string.concat(
    [
      "
  query {
  organization(login: \"",
      org,
      "\")
  {
    name
    url
    repositories(first: 100, isFork: false) {
      totalCount
      nodes {
        name
      }
    }
  }
}
  ",
    ],
  )
}

pub fn call_api_for_repos(token: String) -> Result(List(Repo), String) {
  //TODO this pattern is ugly. Fix it
  let org1 = "gleam-lang"
  let org2 = "gleam-experiments"

  let query1 = construct_repo_query(org1)
  try response_json1 = call_api(token, query1)
  try repo_list1 = parse_repos(response_json1, org1)

  let query2 = construct_repo_query(org2)
  try response_json2 = call_api(token, query2)
  try repo_list2 = parse_repos(response_json2, org2)

  let repo_list = list.append(repo_list1, repo_list2)

  Ok(repo_list)
}

// Entrypoint fn for Erlang escriptize. Must be called `main`. Takes a
// List(String) formed of whitespace seperated commands to stdin.
// Top level, handles error-handling
pub fn main(args: List(String)) -> Nil {
  // Try returns early so we need a let block, otherwise the whole fn would need
  // to return the same type as the result for the try, rather than nil. All of
  // the trys in the let block must have the same error (failure mode/message)
  // type for this reason.
  let result = {
    // Parses command line arguments
    try tuple(token, from_version, to_version) = parse_args(args)
    // From and to dates from version numbers
    try datetimes = call_api_for_datetimes(token, from_version, to_version)
    let tuple(from, to) = datetimes
    // Calls API for Sponsors. Returns List(String) if Ok.
    try sponsors = call_api_for_sponsors(token, option.None, [])
    let str_lst_sponsors = list_sponsor_to_list_string(sponsors)
    //NOTE filtering the sponsor list by sponser amount (cents) is done here. 
    //TODO: Construct fn to return the avatar_url as well as name and guthub url in the required MD format
    //Construct fn to generate the filtered sponsors with avatars as a string
    //and append it to the existing output string
    //Returns List(Repo)
    try list_repos = call_api_for_repos(token)
    //IMPORTANT traverse is for a result or list where map would have given a list of results. IT MIGHT CHANGE TO BE CALLED MAP_WHILE!
    try acc_list_contributors = list.traverse(
      list_repos,
      fn(repo: Repo) {
        call_api_for_contributors(
          token,
          from,
          to,
          option.None,
          [],
          repo.org,
          repo.name,
        )
      },
    )
    let flat_contributors = list.flatten(acc_list_contributors)
    let str_lst_contributors = list_contributor_to_list_string(
      flat_contributors,
    )
    // Combines all sponsors and all contributors
    let str_sponsors_contributors = to_output_string(
      filter_sort(list.append(str_lst_sponsors, str_lst_contributors)),
    )
    //TODO IMPORTANT add a line with sponsors only and sponsors filtered
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
