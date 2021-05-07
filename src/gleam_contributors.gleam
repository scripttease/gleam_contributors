// Import Gleam StdLib modules here.
// To add an Erlang library, add deps to rebar.config, AND require lib in
// gleam_contributors.app.src To use them create an external fn.
import gleam/result
import gleam/string
import gleam/set.{Set}
import gleam/list
import gleam/io
import gleam/option.{None, Option, Some}
import gleam_contributors/json
import gleam_contributors/time
import gleam_contributors/repo.{Repo}
import gleam_contributors/graphql
import gleam_contributors/markdown
import gleam_contributors/yaml
import gleam_contributors/sponsor.{Sponsor}
import gleam_contributors/contributor.{Contributor}
import gleam_contributors/attributee

external type OkAtom

// Naming the application for Erlang to start processes required in app, such as
// inets. Will convert Camel to Snake case.
type Application {
  GleamContributors
}

//Erlang module Application fn ensure_all_started, see above
external fn start_application_and_deps(Application) -> OkAtom =
  "application" "ensure_all_started"

//TODO err is atom type not string, import gleam atom then if need error convert atom to string
external fn read_file(filename: String) -> Result(String, String) =
  "file" "read_file"

//TODO error is atom type not string, import gleam atom then if need error convert atom to string
//TODO Correct return type
external fn erlang_write_file(
  filename: String,
  content: String,
) -> Result(String, String) =
  "file" "write_file"

fn write_file(filename: String, content: String) -> Result(String, String) {
  // The write_file Erlang fn does NOT return a result so we need to hack it
  // until there are better bindings to the file IO library.
  case erlang_write_file(filename, content) {
    Error(e) -> Error(e)
    _ -> Ok("")
  }
}

// Calls API with versions and gets datetimes for the version release dates
fn call_api_for_datetimes(
  token: String,
  from_version: String,
  to_version: Option(String),
) -> Result(#(String, String), String) {
  try to_datetime = case to_version {
    Some(to_version) -> {
      let query_to = graphql.construct_release_query(to_version)
      try response_json = graphql.call_api(token, query_to)
      time.decode_iso_datetime(json.decode(response_json))
    }
    None -> Ok(time.iso_format(time.now()))
  }

  let query_from = graphql.construct_release_query(from_version)

  try response_json = graphql.call_api(token, query_from)
  try from_datetime = time.decode_iso_datetime(json.decode(response_json))
  Ok(#(from_datetime, to_datetime))
}

fn case_insensitive_sort(items: List(String)) -> List(String) {
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  list.sort(items, case_insensitive_string_compare)
}

pub fn list_sponsor_to_list_string(sponsors_list: List(Sponsor)) -> List(String) {
  sponsors_list
  |> list.map(fn(record: Sponsor) {
    let name = sponsor.display_name(record)
    let href = sponsor.display_link(record)
    markdown.link(name, to: href)
  })
  |> case_insensitive_sort
}

/// Filters sponsor list to people who have donated `dollars` or above
pub fn filter_sponsors(lst: List(Sponsor), dollars: Int) -> List(Sponsor) {
  let cents = dollars * 100
  list.filter(lst, fn(sponsor: Sponsor) { sponsor.cents >= cents })
}

fn call_api_for_sponsors(
  token: String,
  cursor: Option(String),
  sponsor_list: List(Sponsor),
) -> Result(List(Sponsor), String) {
  let query = graphql.construct_sponsor_query(cursor, option.None)

  //The sponsor_list acts as an accumluator on the recursive call of the fn,
  //and is therefore passed in as an arg.
  try response_json = graphql.call_api(token, query)
  let response_json = json.decode(response_json)
  try sponsorpage = sponsor.decode_page(response_json)
  let sponsor_list = list.append(sponsor_list, sponsorpage.sponsor_list)
  case sponsorpage.nextpage_cursor {
    Ok(cursor) -> {
      let cursor_opt = option.Some(cursor)
      call_api_for_sponsors(token, cursor_opt, sponsor_list)
    }
    _ -> Ok(sponsor_list)
  }
}

pub type WebsiteTiers {
  WebsiteTiers(first: List(Sponsor), second: List(Sponsor))
}

fn website_tiers(sponsors: List(Sponsor)) -> WebsiteTiers {
  let fold = fn(sponsor: Sponsor, acc: WebsiteTiers) {
    case sponsor.cents / 100 {
      dollars if dollars >= 100 ->
        WebsiteTiers(..acc, second: [sponsor, ..acc.second])

      dollars if dollars >= 20 ->
        WebsiteTiers(..acc, first: [sponsor, ..acc.first])

      _otherwise -> acc
    }
  }
  list.fold(sponsors, WebsiteTiers([], []), fold)
}

fn website_yaml(token: String, filename: String) -> Result(String, String) {
  io.println("Calling Sponsors API")
  try sponsors = call_api_for_sponsors(token, option.None, [])
  let tiers = website_tiers(sponsors)
  [#("first_tier", tiers.first), #("second_tier", tiers.second)]
  |> yaml.sponsors_tiers
  |> write_file(filename, _)
}

fn readme_list(token: String, filename: String) -> Result(String, String) {
  io.println("Calling Sponsors API")

  // Get sponsors over $10 for generated readme section
  // recombine partone with the autogenerated bit and sponsors into a string
  // write to file
  try sponsors = call_api_for_sponsors(token, option.None, [])
  io.println("Reading target file")
  try file = read_file(filename)
  io.println("Editing file contents")
  let splitter = "<!-- Below this line this file is autogenerated -->"
  let parts = string.split(file, splitter)
  try part_one =
    list.head(parts)
    |> result.map_error(fn(_) { "Could not split file." })
  let sponsors100 = filter_sponsors(sponsors, 10)
  let str_lst_sponsors = list_sponsor_to_list_string(sponsors100)
  let output_sponsors = markdown.unordered_list(str_lst_sponsors)
  let gen_readme = string.concat([part_one, splitter, "\n", output_sponsors])
  io.println("Writing edited content to target file")
  write_file(filename, gen_readme)
}

// Parse args from STDIN
fn parse_args(args: List(String)) -> Result(#(String, String, String), String) {
  case args {
    [token, from_version, to_version] ->
      // From and to dates from version numbers
      try datetimes =
        call_api_for_datetimes(token, from_version, Some(to_version))
      let #(from, to) = datetimes
      Ok(#(token, from, to))
    [token, from_version] ->
      try datetimes = call_api_for_datetimes(token, from_version, None)
      let #(from, to) = datetimes
      Ok(#(token, from, to))
    _ ->
      Error(
        "Usage: _buildfilename $TOKEN $FROM_VERSION $TO_VESRION
Version should be in format `v0.3.0`
$TO_VERSION is optional and if omitted, records will be retrieved up to the current datetime.",
      )
  }
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
        Some(url) -> markdown.link(contributor.name, to: url)
        None -> contributor.name
      }
    })

  // TODO: can the filter and sort be handled later or is here best?
  let case_insensitive_string_compare = fn(a, b) {
    string.compare(string.lowercase(a), string.lowercase(b))
  }

  let sorted = list.sort(initial_list, case_insensitive_string_compare)

  remove_duplicates(sorted)
  |> set.to_list
}

pub fn filter_creator_from_contributors(
  contributor: List(Contributor),
) -> List(Contributor) {
  let isnt_louis = fn(contributor: Contributor) {
    contributor.github != Some("https://github.com/lpil")
  }

  list.filter(contributor, for: isnt_louis)
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
    graphql.construct_contributor_query(
      cursor,
      from,
      to,
      option.None,
      org,
      repo_name,
      branch,
    )

  try response_json = graphql.call_api(token, query)
  try contributorpage = contributor.decode_page(response_json)
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

fn call_api_for_repos(token: String) -> Result(List(Repo), String) {
  let get_repos = fn(org) {
    io.println(string.append("Calling API to get repos in ", org))
    let query = graphql.construct_repo_query(org)
    try resp = graphql.call_api(token, query)
    resp
    |> json.decode
    |> repo.decode_organisation_repos(org)
  }

  try orgs = list.try_map(["gleam-lang", "gleam-experiments"], get_repos)
  orgs
  |> list.fold([], list.append)
  |> Ok
}

// Args from command line are actually an Erlang Charlist not strings, so they need to be converted.
pub external type Charlist

external fn charlist_to_string(Charlist) -> String =
  "erlang" "list_to_binary"

fn call_api_for_all_contributors(token, from, to) {
  try list_repos = call_api_for_repos(token)
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
}

fn print_combined_sponsors_and_contributors(args: List(String)) {
  // Parses command line arguments
  // Call API for sponsors and contribtors
  // Join the sponsors and contributors together as attributees
  try #(token, from, to) = parse_args(args)

  try sponsors = call_api_for_sponsors(token, option.None, [])
  try contributors = call_api_for_all_contributors(token, from, to)
  let contributors =
    contributors
    |> list.flatten
    |> filter_creator_from_contributors
    |> list.map(attributee.from_contributor)
  let sponsors = list.map(sponsors, attributee.from_sponsor)
  sponsors
  |> list.append(contributors)
  |> attributee.deduplicate
  |> attributee.sort_by_name
  |> list.map(attributee.to_markdown_link)
  |> markdown.unordered_list
  |> Ok
}

// Entrypoint fn for Erlang escriptize. Must be called `main`. Takes a
// List(Charlist) formed of whitespace seperated commands to stdin.
// Top level, handles error-handling
pub fn main(args: List(Charlist)) -> Nil {
  start_application_and_deps(GleamContributors)
  io.println("Erlang applications started")

  let args = list.map(args, fn(x) { charlist_to_string(x) })

  let result = case args {
    ["readme-list", token, filename] -> readme_list(token, filename)
    ["website-yaml", token, filename] -> website_yaml(token, filename)
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
