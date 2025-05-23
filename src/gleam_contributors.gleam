import argv
import envoy
import gleam/httpc
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam_contributors/attributee
import gleam_contributors/contributor.{type Contributor}
import gleam_contributors/graphql
import gleam_contributors/markdown
import gleam_contributors/repo.{type Repo}
import gleam_contributors/sponsor.{type Sponsor, type Sponsorspage, Sponsor}
import gleam_contributors/time
import gliberapay
import simplifile

fn write_file(filename: String, content: String) -> Result(Nil, String) {
  simplifile.write(content, to: filename)
  |> result.map_error(string.inspect)
}

// Calls API with versions and gets datetimes for the version release dates
fn call_api_for_datetimes(
  token: String,
  from_version: String,
  to_version: Option(String),
) -> Result(#(String, String), String) {
  use to_datetime <- result.try(case to_version {
    Some(to_version) -> {
      let query_to: String = graphql.construct_release_query(to_version)
      use response_json: String <- result.try(graphql.call_api(token, query_to))
      json.decode(response_json, time.decode_iso_datetime)
      |> result.map_error(string.inspect)
    }
    None -> Ok(time.iso_format(time.now()))
  })

  let query_from = graphql.construct_release_query(from_version)

  use response_json <- result.try(graphql.call_api(token, query_from))
  use from_datetime <- result.try(
    json.decode(response_json, time.decode_iso_datetime)
    |> result.map_error(string.inspect),
  )
  Ok(#(from_datetime, to_datetime))
}

pub fn list_sponsor_to_list_string(sponsors_list: List(Sponsor)) -> List(String) {
  sponsors_list
  |> list.sort(fn(a, b) {
    string.compare(
      string.lowercase(sponsor.display_name(a)),
      string.lowercase(sponsor.display_name(b)),
    )
  })
  |> list.map(fn(record: Sponsor) {
    let name = sponsor.display_name(record)
    let href = sponsor.display_link(record)
    "<a href=\"" <> href <> "\">" <> name <> "</a>"
  })
}

/// Filters sponsor list to people who have donated `dollars` or above
pub fn filter_sponsors(lst: List(Sponsor), dollars: Int) -> List(Sponsor) {
  let cents = dollars * 100
  list.filter(lst, fn(sponsor: Sponsor) { sponsor.cents >= cents })
}

fn get_sponsors(token: String) -> Result(List(Sponsor), String) {
  use github_sponsors <- result.try(get_github_sponsors(token, option.None, []))
  use liberapay_sponsors <- result.try(get_liberapay_sponsors())
  list.concat([github_sponsors, liberapay_sponsors])
  |> Ok
}

fn get_liberapay_sponsors() -> Result(List(Sponsor), String) {
  let req = gliberapay.download_patrons_csv_request("gleam")
  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(e) {
      "Failed to download liberapay CSV " <> string.inspect(e)
    }),
  )

  use patrons <- result.try(
    gliberapay.parse_patrons_csv(resp.body)
    |> result.map_error(fn(e) {
      "Failed to download liberapay CSV " <> string.inspect(e)
    }),
  )

  patrons
  |> list.map(fn(p) {
    Sponsor(
      name: option.unwrap(p.patron_public_name, p.patron_username),
      github: "",
      avatar: p.patron_avatar_url,
      website: Ok("https://liberapay.com/" <> p.patron_username <> "/"),
      // TODO: remove cents, we don't use it any more
      cents: 0,
    )
  })
  |> Ok
}

fn get_github_sponsors(
  token: String,
  cursor: Option(String),
  sponsor_list: List(Sponsor),
) -> Result(List(Sponsor), String) {
  let query = graphql.construct_sponsor_query(cursor, option.None)

  // The sponsor_list acts as an accumluator on the recursive call of the fn,
  // and is therefore passed in as an arg.
  use response_json: String <- result.try(graphql.call_api(token, query))
  use sponsorpage: Sponsorspage <- result.try(
    json.decode(response_json, sponsor.decode_page)
    |> result.map_error(string.inspect),
  )

  let sponsor_list: List(Sponsor) =
    list.append(sponsor_list, sponsorpage.sponsor_list)
  case sponsorpage.nextpage_cursor {
    Ok(cursor) -> {
      let cursor_opt = option.Some(cursor)
      get_github_sponsors(token, cursor_opt, sponsor_list)
    }
    _ -> Ok(sponsor_list)
  }
}

fn token_from_env() -> Result(String, String) {
  case envoy.get("GITHUB_TOKEN") {
    Ok(token) -> Ok(token)
    Error(Nil) -> Error("GITHUB_TOKEN not set")
  }
}

fn readme_list(filename: String) -> Result(Nil, String) {
  use token <- result.try(token_from_env())

  io.println("Calling Sponsors API")

  // Get sponsors over $10 for generated readme section
  // recombine partone with the autogenerated bit and sponsors into a string
  // write to file
  use sponsors <- result.try(get_sponsors(token))
  io.println("Reading target file")
  use file <- result.try(
    simplifile.read(filename)
    |> result.map_error(string.inspect),
  )
  io.println("Editing file contents")
  let splitter = "<!-- Below this line this file is autogenerated -->"
  let parts = string.split(file, splitter)
  use part_one <- result.try(
    list.first(parts)
    |> result.map_error(fn(_) { "Could not split file." }),
  )
  let str_lst_sponsors = list_sponsor_to_list_string(sponsors)
  let output_sponsors =
    "<p align=\"center\">\n  "
    <> string.join(str_lst_sponsors, " -\n  ")
    <> "\n</p>"
  let gen_readme = string.concat([part_one, splitter, "\n", output_sponsors])
  io.println("Writing edited content to target file")
  write_file(filename, gen_readme)
}

// Parse args from STDIN
fn parse_args(
  token: String,
  args: List(String),
) -> Result(#(String, String), String) {
  case args {
    [from_version, to_version] -> {
      // From and to dates from version numbers
      call_api_for_datetimes(token, from_version, Some(to_version))
    }
    [from_version] -> {
      call_api_for_datetimes(token, from_version, None)
    }
    _ ->
      Error(
        "Usage: _buildfilename $FROM_VERSION $TO_VESRION
Version should be in format `v0.3.0`
$TO_VERSION is optional and if omitted, records will be retrieved up to the current datetime.",
      )
  }
}

//Uses the uniqueness property of sets to remove duplicates from list
pub fn remove_duplicates(sponsors_list: List(String)) -> Set(String) {
  list.fold(over: sponsors_list, from: set.new(), with: fn(acc, elem) {
    set.insert(acc, elem)
  })
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

  list.filter(contributor, keeping: isnt_louis)
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

  use response_json <- result.try(graphql.call_api(token, query))
  use contributorpage <- result.try(
    contributor.decode_page(response_json)
    |> result.map_error(string.inspect),
  )
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

  use contributorpage <- result.try(case fetch_and_parse("main") {
    Ok(data) -> Ok(data)
    Error(_) -> fetch_and_parse("master")
  })
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
    use resp <- result.try(graphql.call_api(token, query))
    resp
    |> json.decode(repo.decode_organisation_repos(_, org))
    |> result.map_error(string.inspect)
  }

  use orgs <- result.try(list.try_map(["gleam-lang"], get_repos))
  orgs
  |> list.fold([], list.append)
  |> Ok
}

fn call_api_for_all_contributors(token, from, to) {
  use list_repos <- result.try(call_api_for_repos(token))
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

fn print_combined_sponsors_and_contributors(
  args: List(String),
) -> Result(Nil, String) {
  use token <- result.try(token_from_env())

  // Parses command line arguments
  // Call API for sponsors and contribtors
  // Join the sponsors and contributors together as attributees
  use #(from, to) <- result.try(parse_args(token, args))

  use sponsors <- result.try(get_sponsors(token))
  use contributors <- result.try(call_api_for_all_contributors(token, from, to))
  let contributors =
    contributors
    |> list.flatten
    |> filter_creator_from_contributors
    |> list.map(attributee.from_contributor)
  let sponsors = list.map(sponsors, attributee.from_sponsor)

  let text =
    sponsors
    |> list.append(contributors)
    |> attributee.deduplicate
    |> attributee.sort_by_name
    |> list.map(attributee.to_markdown_link)
    |> markdown.unordered_list

  io.println(text)

  Ok(Nil)
}

// Entrypoint fn for Erlang escriptize. Must be called `main`. Takes a
// List(Charlist) formed of whitespace seperated commands to stdin.
// Top level, handles error-handling
pub fn main() -> Nil {
  let args = argv.load().arguments
  io.println("Erlang applications started")

  let result = case args {
    ["readme-list", filename] -> readme_list(filename)
    _other -> print_combined_sponsors_and_contributors(args)
  }

  case result {
    Ok(Nil) -> {
      io.println("Done!")
    }
    Error(e) -> {
      io.println("Got an Error. The message was:")
      io.println(e)
    }
  }
}
