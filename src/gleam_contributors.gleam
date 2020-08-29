// Import Gleam StdLib modules here.
// To add an Erlang library, add deps to rebar.config, AND require lib in
// gleam_contributors.app.src To use them create an external fn.
import gleam/result
import gleam/dynamic.{Dynamic}
import gleam/httpc
import gleam/http.{Post}
import gleam/map
import gleam/string
import gleam/set.{Set}
import gleam/list
import gleam/int
import gleam/io
import gleam/option.{None, Option, Some}

external type OkAtom

// Naming the application for Erlang to start processes required in app, such as
// inets. Will convert Camel to Snake case.
type Application {
  GleamContributors
}

//Erlang module Application fn ensure_all_started, see above
external fn start_application_and_deps(Application) -> OkAtom =
  "application" "ensure_all_started"

//Erlang library for json encoding
external fn encode_json(a) -> String =
  "jsone" "encode"

//Erlang library for datetime
external fn current_time() -> tuple(Int, Int, Int) =
  "calendar" "universal_time"

external fn iso_format(tuple(Int, Int, Int)) -> String =
  "iso8601" "format"

external fn decode_json_from_string(String) -> Dynamic =
  "jsone" "decode"

//TODO err is atom type not string, import gleam atom then if need error convert atom to string
external fn read_file(filename: String) -> Result(String, String) =
  "file" "read_file"

//TODO error is atom type not string, import gleam atom then if need error convert atom to string
//TODO Correct return type
external fn write_file(
  filename: String,
  content: String,
) -> Result(String, String) =
  "file" "write_file"

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

// Calls the Github API v4 (GraphQL)
fn call_api(token: String, query: String) -> Result(String, String) {
  let json = map.from_list([tuple("query", query)])

  let result =
    http.default_req()
    |> http.set_method(Post)
    |> http.set_host("api.github.com")
    |> http.set_path("/graphql")
    |> http.prepend_req_header("user-agent", "gleam contributors")
    |> http.prepend_req_header("authorization", string.append("bearer ", token))
    |> http.prepend_req_header("content-type", "application/json")
    |> http.set_req_body(encode_json(json))
    |> httpc.send
  // TODO error(e)
  let response = case result {
    Ok(response) -> Ok(response.body)
    Error(e) -> {
      io.debug(e)
      Error("There was an error during the POST request :(\n")
    }
  }
  response
}

// Constructs a query that will take a version number and return the datetime
// that version was released.
pub fn construct_release_query(version: String) -> String {
  let use_version = string.concat(["\"", version, "\""])

  string.concat([
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
  ])
}

//Converts response json to datetime string.
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

// Calls API with versions and gets datetimes for the version release dates
fn call_api_for_datetimes(
  token: String,
  from_version: String,
  to_version: Option(String),
) -> Result(tuple(String, String), String) {
  try to_datetime = case to_version {
    Some(to_version) -> {
      let query_to = construct_release_query(to_version)
      try response_json = call_api(token, query_to)
      parse_datetime(response_json)
    }
    None -> Ok(iso_format(current_time()))
  }

  let query_from = construct_release_query(from_version)
  try response_json = call_api(token, query_from)
  try from_datetime = parse_datetime(response_json)

  Ok(tuple(from_datetime, to_datetime))
}

//Concatenates optional query params into sponsor query
// Creates query that will return all sponsors of 'lpil'
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

  string.concat([
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
  ])
}

// Some sponsors wish to display their username differently, so override it for
// these people.
fn sponsor_display_name(sponsor: Sponsor) -> String {
  case sponsor.github {
    "https://github.com/ktec" -> "Clever Bunny LTD"
    _ -> sponsor.name
  }
}

// Some sponsors wish to display their link differently, so override it for
// these people.
fn sponsor_display_link(sponsor: Sponsor) -> String {
  case sponsor.github {
    "https://github.com/ktec" -> "https://github.com/cleverbunny"
    _ -> sponsor.github
  }
}

pub fn list_sponsor_to_list_string(sponsors_list: List(Sponsor)) -> List(String) {
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  sponsors_list
  |> list.map(fn(sponsor: Sponsor) {
    let name = sponsor_display_name(sponsor)
    let link = sponsor_display_link(sponsor)
    string.concat(["[", name, "]", "(", link, ")"])
  })
  |> list.sort(case_insensitive_string_compare)
}

// Filters sponsor list to people who have donated `dollars` or above
pub fn filter_sponsors(lst: List(Sponsor), dollars: Int) -> List(Sponsor) {
  let cents = dollars * 100
  list.filter(lst, fn(sponsor: Sponsor) { sponsor.cents >= cents })
}

// Decodes sponsor section of the response JSON (List of treemaps)
fn decode_sponsor(json_obj: Dynamic) -> Result(Sponsor, String) {
  try entity = dynamic.field(json_obj, "sponsorEntity")
  try dynamic_name = dynamic.field(entity, "name")
  try name = dynamic.string(dynamic_name)
  try dynamic_avatar = dynamic.field(entity, "avatarUrl")
  try avatar = dynamic.string(dynamic_avatar)
  try dynamic_github = dynamic.field(entity, "url")
  try github = dynamic.string(dynamic_github)

  try dynamic_website = dynamic.field(entity, "websiteUrl")
  let website =
    dynamic.string(dynamic_website)
    |> result.map_error(fn(_) { Nil })

  try tier = dynamic.field(json_obj, "tier")
  try dynamic_cents = dynamic.field(tier, "monthlyPriceInCents")
  try cents = dynamic.int(dynamic_cents)

  Ok(Sponsor(
    name: name,
    github: github,
    avatar: avatar,
    website: website,
    cents: cents,
  ))
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
    True ->
      dynamic.field(page, "endCursor")
      |> // only returns if result(Ok(_))
      result.then(dynamic.string)
      |> // only called if there is no nextpage, ie result -> Error(Nil)
      result.map_error(fn(_) { Nil })
  }

  try nodes = dynamic.field(spons, "nodes")
  try sponsors = dynamic.typed_list(nodes, of: decode_sponsor)

  Ok(Sponsorspage(nextpage_cursor: cursor, sponsor_list: sponsors))
}

fn call_api_for_sponsors(
  token: String,
  cursor: Option(String),
  sponsor_list: List(Sponsor),
) -> Result(List(Sponsor), String) {
  let query = construct_sponsor_query(cursor, option.None)

  try response_json = call_api(token, query)
  try sponsorpage = parse_sponsors(response_json)

  //The sponsor_list acts as an accumluator on the recursive call of the fn,
  //and is therefore passed in as an arg.
  let sponsor_list = list.append(sponsor_list, sponsorpage.sponsor_list)

  case sponsorpage.nextpage_cursor {
    Ok(cursor) -> {
      let cursor_opt = option.Some(cursor)
      call_api_for_sponsors(token, cursor_opt, sponsor_list)
    }
    _ -> Ok(sponsor_list)
  }
}

// We want main to output a single string that can be copy pasted into a
// Markdown file. After all the data munging is done, the final step is to
// create a single string in the desired format.
// done on the string so they must be done first.
fn to_output_string(contributors: List(String)) -> String {
  let string_out =
    list.fold(
      contributors,
      "",
      fn(elem, acc) {
        acc
        |> string.append("\n - ")
        |> string.append(elem)
      },
    )
  string.concat([string_out, "\n"])
}

fn github_actions(token: String, filename: String) -> Result(String, String) {
  io.println("Calling Sponsors API")
  try sponsors = call_api_for_sponsors(token, option.None, [])
  io.println("Reading target file")
  try file = read_file(filename)
  io.println("Editing file contents")
  let splitter = "<!-- Below this line this file is autogenerated -->"
  let parts = string.split(file, splitter)
  try part_one =
    list.head(parts)
    |> result.map_error(fn(_) { "Could not split file." })

  // Get sponsors over $10 for generated readme section
  let sponsors100 = filter_sponsors(sponsors, 10)
  let str_lst_sponsors = list_sponsor_to_list_string(sponsors100)
  let output_sponsors = to_output_string(str_lst_sponsors)

  // recombine partone with the autogenerated bit and sponsors into a string
  let gen_readme = string.concat([part_one, splitter, "\n", output_sponsors])

  // write to file
  io.println("Writing edited content to target file")
  // try out = write_file("README.md", gen_readme)
  // The write_file Erlang fn does NOT return a result so we need to hack it
  // until there are better bindings to the file IO library.
  case write_file(filename, gen_readme) {
    Error(e) -> Error(e)
    _ -> Ok("")
  }
}

//Parse args from STDIN
fn parse_args(
  args: List(String),
) -> Result(tuple(String, String, String), String) {
  case args {
    [token, from_version, to_version] -> {
      // From and to dates from version numbers
      try datetimes =
        call_api_for_datetimes(token, from_version, Some(to_version))
      let tuple(from, to) = datetimes
      Ok(tuple(token, from, to))
    }
    [token, from_version] -> {
      try datetimes = call_api_for_datetimes(token, from_version, None)
      let tuple(from, to) = datetimes
      Ok(tuple(token, from, to))
    }
    _ ->
      Error(
        "Usage: _buildfilename $TOKEN $FROM_VERSION $TO_VESRION\nVersion should be in format `v0.3.0`\n$TO_VERSION is optional and if omitted, records will be retrieved up to the current datetime.",
      )
  }
}

pub fn construct_contributor_query(
  cursor: Option(String),
  from_date: String,
  to_date: String,
  count: Option(String),
  org: String,
  repo_name: String,
  branch: String,
) -> String {
  let use_cursor = case cursor {
    option.Some(cursor) -> string.concat(["\"", cursor, "\""])
    _ -> "null"
  }

  let use_from_date = string.concat(["\"", from_date, "\""])
  let use_to_date = string.concat(["\"", to_date, "\""])
  let use_branch = string.concat(["\"", branch, "\""])

  // Optional count is for use in integration tests. Otherwise the default is  100 results
  let use_count = case count {
    option.Some(count) -> count
    _ -> "100"
  }

  let use_org = string.concat(["\"", org, "\""])
  let use_repo_name = string.concat(["\"", repo_name, "\""])

  string.concat([
    "{
  repository(owner: ",
    use_org,
    ", name: ",
    use_repo_name,
    ") {
    object(expression: ",
    use_branch,
    ") {
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
  ])
}

// This is still parsing the response json into Gleam types, see
// parse_contributors, but it is the contributor section only. To make the parse
// function more readable
fn decode_contributor(json_obj: Dynamic) -> Result(Contributor, String) {
  try author = dynamic.field(json_obj, "author")
  try dynamic_name = dynamic.field(author, "name")
  try name = dynamic.string(dynamic_name)

  let github = {
    try user = dynamic.field(author, "user")
    try dynamic_github = dynamic.field(user, "url")
    dynamic.string(dynamic_github)
  }

  Ok(Contributor(name: name, github: option.from_result(github)))
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
    True ->
      dynamic.field(pageinfo, "endCursor")
      |> result.then(dynamic.string)
      |> result.map_error(fn(_) { Nil })
  }

  try nodes = dynamic.field(history, "nodes")
  try contributors = dynamic.typed_list(nodes, of: decode_contributor)

  Ok(Contributorspage(nextpage_cursor: cursor, contributor_list: contributors))
}

//Uses the uniqueness property of sets to remove duplicates from list
pub fn remove_duplicates(sponsors_list: List(String)) -> Set(String) {
  list.fold(
    over: sponsors_list,
    from: set.new(),
    with: fn(elem, acc) { set.insert(acc, elem) },
  )
}

pub fn list_contributor_to_list_string(
  contributors: List(Contributor),
) -> List(String) {
  let initial_list =
    contributors
    |> list.map(fn(contributor: Contributor) {
      case contributor.github {
        Some(url) -> string.concat(["[", contributor.name, "](", url, ")"])
        None -> contributor.name
      }
    })

  //TODO can the filter and sort be handled later or is here best?
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  let sorted = list.sort(initial_list, case_insensitive_string_compare)

  remove_duplicates(sorted)
  |> set.to_list
}

pub fn filter_creator_from_contributors(
  creator: Contributor,
  lst: List(Contributor),
) -> List(Contributor) {
  list.filter(lst, fn(elem) { elem != creator })
}

fn request_and_parse_contributors(
  token,
  from,
  to,
  cursor,
  org,
  repo_name,
  branch,
) {
  let query =
    construct_contributor_query(
      cursor,
      from,
      to,
      option.None,
      org,
      repo_name,
      branch,
    )

  try response_json = call_api(token, query)
  try contributorpage = parse_contributors(response_json)
  Ok(contributorpage)
}

fn call_api_for_contributors(
  token: String,
  from: String,
  to: String,
  cursor: Option(String),
  contributor_list: List(Contributor),
  org: String,
  repo_name: String,
) -> Result(List(Contributor), String) {
  ["Calling API for contributors to ", org, "/", repo_name]
  |> string.concat
  |> io.println

  let fetch_and_parse = fn(branch) {
    request_and_parse_contributors(
      token,
      from,
      to,
      cursor,
      org,
      repo_name,
      branch,
    )
  }

  try contributorpage = case fetch_and_parse("main") {
    Ok(data) -> Ok(data)
    Error(_) -> fetch_and_parse("master")
  }

  let contributor_list =
    list.append(contributor_list, contributorpage.contributor_list)

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

fn filter_sort(lst: List(String)) -> List(String) {
  let filtered = set.to_list(set.from_list(lst))

  //TODO seperate out?
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  list.sort(filtered, case_insensitive_string_compare)
}

// TODO Add nextpage cursor for when number of repos exceed 100 results
fn parse_repos(repos_json: String, org_n: String) -> Result(List(Repo), String) {
  let res = decode_json_from_string(repos_json)
  try data = dynamic.field(res, "data")
  try org = dynamic.field(data, "organization")
  try repos = dynamic.field(org, "repositories")
  try nodes = dynamic.field(repos, "nodes")
  //dynamic.list needs to take a fn
  let name_field = fn(repo) {
    try dynamic_name = dynamic.field(repo, "name")
    dynamic.string(dynamic_name)
  }
  try repo_string_list = dynamic.typed_list(nodes, of: name_field)

  let list_repo =
    list.map(repo_string_list, fn(string) { Repo(org: org_n, name: string) })

  Ok(list_repo)
}

// Query for getting all of the repos
fn construct_repo_query(org: String) -> String {
  string.concat([
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
  ])
}

fn call_api_for_repos(token: String) -> Result(List(Repo), String) {
  //TODO this pattern is ugly. Fix it
  let org1 = "gleam-lang"
  let org2 = "gleam-experiments"

  io.println("Calling API to get repos in gleam-lang")
  let query1 = construct_repo_query(org1)
  try response_json1 = call_api(token, query1)
  try repo_list1 = parse_repos(response_json1, org1)

  io.println("Calling API to get repos in gleam-experiments")
  let query2 = construct_repo_query(org2)
  try response_json2 = call_api(token, query2)
  try repo_list2 = parse_repos(response_json2, org2)

  let repo_list = list.append(repo_list1, repo_list2)

  Ok(repo_list)
}

// Args from command line are actually an Erlang Charlist not strings, so they need to be converted.
pub external type Charlist

external fn charlist_to_string(Charlist) -> String =
  "erlang" "list_to_binary"

fn print_combined_sponsors_and_contributors(args: List(String)) {
  // Parses command line arguments
  try tuple(token, from, to) = parse_args(args)
  // Calls API for Sponsors. Returns List(String) if Ok.
  try sponsors = call_api_for_sponsors(token, option.None, [])
  let str_list_sponsors = list_sponsor_to_list_string(sponsors)
  //NOTE filtering the sponsor list by sponser amount (cents) could also be done here.
  // let sponsors100 = filter_sponsors(sponsors, 100)
  //TODO: Construct fn to return the avatar_url as well as name and github url in the required MD format
  //Construct fn to generate the filtered sponsors with avatars as a string
  //and append it to the existing output string
  //Returns List(Repo)
  try list_repos = call_api_for_repos(token)
  try acc_list_contributors =
    list_repos
    |> list.try_map(fn(repo: Repo) {
      call_api_for_contributors(
        token,
        from,
        to,
        option.None,
        [],
        repo.org,
        repo.name,
      )
    })
  let flat_contributors = list.flatten(acc_list_contributors)
  let louis =
    Contributor(name: "Louis Pilfold", github: Some("https://github.com/lpil"))
  let filtered_contributors =
    filter_creator_from_contributors(louis, flat_contributors)
  let str_list_contributors =
    list_contributor_to_list_string(filtered_contributors)
  // Combines all sponsors and all contributors
  let str_sponsors_contributors =
    to_output_string(filter_sort(list.append(
      str_list_sponsors,
      str_list_contributors,
    )))
  Ok(str_sponsors_contributors)
}

// Entrypoint fn for Erlang escriptize. Must be called `main`. Takes a
// List(Charlist) formed of whitespace seperated commands to stdin.
// Top level, handles error-handling
pub fn main(args: List(Charlist)) -> Nil {
  start_application_and_deps(GleamContributors)
  io.println("Erlang applications started")

  let args = list.map(args, fn(x) { charlist_to_string(x) })

  let result = case args {
    ["GA", token, filename] -> github_actions(token, filename)
    _other -> print_combined_sponsors_and_contributors(args)
  }

  case result {
    Ok(res) -> {
      io.print(res)
      io.println("Done!")
    }
    Error(e) -> {
      io.println("Got an Error. The message was:")
      io.println(e)
    }
  }
}
