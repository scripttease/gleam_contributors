import gleam/http.{Post}
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/option.{type Option}
import gleam/string

/// Calls the Github API v4 (GraphQL)
pub fn call_api(token: String, query: String) -> Result(String, String) {
  let body = json.object([#("query", json.string(query))])

  let assert Ok(request) = request.to("https://api.github.com/graphql")
  let result =
    request
    |> request.set_method(Post)
    |> request.prepend_header("user-agent", "gleam contributors")
    |> request.prepend_header("authorization", string.append("bearer ", token))
    |> request.prepend_header("content-type", "application/json")
    |> request.set_body(json.to_string(body))
    |> httpc.send
  // TODO error(e)
  let response = case result {
    Ok(response) -> Ok(response.body)
    Error(e) -> {
      Error(
        "There was an error during the POST request :(\n" <> string.inspect(e),
      )
    }
  }
  response
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
                name
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

// Concatenates optional query params into sponsor query
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
            url
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

// Query for getting all of the repos
pub fn construct_repo_query(org: String) -> String {
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
