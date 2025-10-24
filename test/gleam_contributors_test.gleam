import gleam/json
import gleam/option.{None, Some}
import gleam/set
import gleam_contributors
import gleam_contributors/contributor.{Contributor, Contributorspage}
import gleam_contributors/graphql
import gleam_contributors/sponsor.{Sponsor, Sponsorspage}
import gleam_contributors/time
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn parse_sponsor_empty_with_cursor_test() {
  let payload =
    "
 {
  \"data\": {
    \"user\": {
      \"sponsorshipsAsMaintainer\": {
        \"pageInfo\": {
          \"hasNextPage\": false,
          \"endCursor\": \"MjE\"
        },
        \"nodes\": [] }
      }
    }
  }

  "

  json.parse(payload, sponsor.page_decoder())
  |> should.equal(
    Ok(Sponsorspage(nextpage_cursor: option.Some("MjE"), sponsor_list: [])),
  )
}

pub fn parse_sponsor_test() {
  let payload =
    "
{
  \"data\": {
    \"user\": {
      \"sponsorshipsAsMaintainer\": {
        \"pageInfo\": {
          \"hasNextPage\": true,
          \"endCursor\": \"Mg\"
        },
        \"nodes\": [
          {
            \"sponsorEntity\": {
              \"name\": \"Chris Young\",
              \"avatarUrl\": \"https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4\",
              \"websiteUrl\": null,
              \"url\": \"https://github.com/worldofchris\"
            },
            \"tier\": {
              \"monthlyPriceInCents\": 500
            }
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Bruno Michel\",
              \"avatarUrl\": \"https://avatars3.githubusercontent.com/u/2767?u=ff72b1ad63026e0729acc2dd41378e28ab704a3f&v=4\",
              \"websiteUrl\": \"http://blog.menfin.info/\",
              \"url\": \"https://github.com/nono\"
            },
            \"tier\": {
              \"monthlyPriceInCents\": 500
            }
          }
        ]
      }
    }
  }
}
  "
  json.parse(payload, sponsor.page_decoder())
  |> should.equal(
    Ok(
      Sponsorspage(nextpage_cursor: Some("Mg"), sponsor_list: [
        Sponsor(
          name: "Chris Young",
          github: "https://github.com/worldofchris",
          website: None,
        ),
        Sponsor(
          name: "Bruno Michel",
          github: "https://github.com/nono",
          website: Some("http://blog.menfin.info/"),
        ),
      ]),
    ),
  )
}

pub fn construct_release_query_test() {
  let version = "v0.8.0"

  graphql.construct_release_query(version)
  |> should.equal(
    "{
  repository(name: \"gleam\", owner: \"gleam-lang\") {
    release(tagName: \"v0.8.0\") {
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
  )
}

pub fn parse_datetime_test() {
  "
{
  \"data\": {
    \"repository\": {
      \"release\": {
        \"tag\": {
          \"target\": {
            \"committedDate\": \"2020-05-19T16:09:23Z\"
          }
        }
      }
    }
  }
}
  "
  |> json.parse(time.decode_iso_datetime())
  |> should.equal(Ok("2020-05-19T16:09:23Z"))
}

pub fn construct_contributor_query_test_master() {
  let cursor = option.None
  let from = "2020-03-01T19:22:35Z"
  let to = "2020-05-07T18:57:47Z"
  let count = option.Some("5")
  let org = "gleam-lang"
  let repo_name = "gleam"
  let branch = "master"

  graphql.construct_contributor_query(
    cursor,
    from,
    to,
    count,
    org,
    repo_name,
    branch,
  )
  |> should.equal(
    "{
  repository(owner: \"gleam-lang\", name: \"gleam\") {
    object(expression: \"master\") {
      ... on Commit {
        history(since: \"2020-03-01T19:22:35Z\", until: \"2020-05-07T18:57:47Z\", after: null, first: 5) {
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
  )
}

pub fn construct_contributor_query_test_main() {
  let cursor = option.None
  let from = "2020-03-01T19:22:35Z"
  let to = "2020-05-07T18:57:47Z"
  let count = option.Some("5")
  let org = "gleam-lang"
  let repo_name = "gleam"
  let branch = "main"

  graphql.construct_contributor_query(
    cursor,
    from,
    to,
    count,
    org,
    repo_name,
    branch,
  )
  |> should.equal(
    "{
  repository(owner: \"gleam-lang\", name: \"gleam\") {
    object(expression: \"main\") {
      ... on Commit {
        history(since: \"2020-03-01T19:22:35Z\", until: \"2020-05-07T18:57:47Z\", after: null, first: 5) {
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
  )
}

pub fn parse_contributors_empty_with_cursor_test() {
  "
  {
  \"data\": {
    \"repository\": {
      \"object\": {
        \"history\": {
          \"totalCount\": 0,
          \"pageInfo\": {
            \"hasNextPage\": false,
            \"endCursor\": null
          },
          \"nodes\": []
        }
      }
    }
  }
}
  "
  |> json.parse(contributor.page_decoder())
  |> should.equal(
    Ok(Contributorspage(nextpage_cursor: None, contributor_list: [])),
  )
}

// TODO change previous to latest or current
pub fn parse_contributors_test() {
  "
{
  \"data\": {
    \"repository\": {
      \"object\": {
        \"history\": {
          \"totalCount\": 1285,
          \"pageInfo\": {
            \"hasNextPage\": true,
            \"endCursor\": \"3cecc58691af74a1b9e1bdc7c9bd42020a7a9052 4\"
          },
          \"nodes\": [
            {
              \"author\": {
                \"name\": \"Louis Pilfold\",
                \"user\": {
                  \"login\": \"lpil\",
                  \"url\": \"https://github.com/lpil\"
                }
              }
            },
            {
              \"author\": {
                \"name\": \"Tom Whatmore\",
                \"user\": {
                  \"login\": \"tomwhatmore\",
                  \"url\": \"https://github.com/tomwhatmore\"
                }
              }
            },
            {
              \"author\": {
                \"name\": \"Louis Pilfold\",
                \"user\": {
                  \"login\": \"lpil\",
                  \"url\": \"https://github.com/lpil\"
                }
              }
            },
            {
              \"author\": {
                \"name\": \"Louis Pilfold\",
                \"user\": {
                  \"login\": \"lpil\",
                  \"url\": \"https://github.com/lpil\"
                }
              }
            },
            {
              \"author\": {
                \"name\": \"Quinn Wilton\",
                \"user\": {
                  \"login\": \"QuinnWilton\",
                  \"url\": \"https://github.com/QuinnWilton\"
                }
              }
            }
          ]
        }
      }
    }
  }
}
  "
  |> json.parse(contributor.page_decoder())
  |> should.equal(
    Ok(
      Contributorspage(
        nextpage_cursor: Some("3cecc58691af74a1b9e1bdc7c9bd42020a7a9052 4"),
        contributor_list: [
          Contributor(
            name: "Louis Pilfold",
            github: Some("https://github.com/lpil"),
          ),
          Contributor(
            name: "Tom Whatmore",
            github: Some("https://github.com/tomwhatmore"),
          ),
          Contributor(
            name: "Louis Pilfold",
            github: Some("https://github.com/lpil"),
          ),
          Contributor(
            name: "Louis Pilfold",
            github: Some("https://github.com/lpil"),
          ),
          Contributor(
            name: "Quinn Wilton",
            github: Some("https://github.com/QuinnWilton"),
          ),
        ],
      ),
    ),
  )
}

pub fn parse_url_is_optional_test() {
  "
{
  \"data\": {
    \"repository\": {
      \"object\": {
        \"history\": {
          \"totalCount\": 1285,
          \"pageInfo\": {
            \"hasNextPage\": true,
            \"endCursor\": \"3cecc58691af74a1b9e1bdc7c9bd42020a7a9052 4\"
          },
          \"nodes\": [
            {
              \"author\": {
                \"name\": \"Louis Pilfold\",
                \"user\": null
              }
            }
          ]
        }
      }
    }
  }
}
  "
  |> json.parse(contributor.page_decoder())
  |> should.equal(
    Ok(
      Contributorspage(
        nextpage_cursor: Some("3cecc58691af74a1b9e1bdc7c9bd42020a7a9052 4"),
        contributor_list: [Contributor(name: "Louis Pilfold", github: None)],
      ),
    ),
  )
}

pub fn remove_duplicates_test() {
  let slist = ["a", "a", "b", "c", "c"]

  gleam_contributors.remove_duplicates(slist)
  |> should.equal(set.from_list(["a", "b", "c"]))
}

pub fn list_contributor_to_list_string_test() {
  // let page = Contributorspage(
  //   nextpage_cursor: Ok("3cecc58691af74a1b9e1bdc7c9bd42020a7a9052 4"),
  //   contributor_list: [
  let lst = [
    Contributor(name: "Louis Pilfold", github: Some("https://github.com/lpil")),
    Contributor(
      name: "Tom Whatmore",
      github: Some("https://github.com/tomwhatmore"),
    ),
    Contributor(name: "Louis Pilfold", github: Some("https://github.com/lpil")),
    Contributor(name: "Louis Pilfold", github: Some("https://github.com/lpil")),
    Contributor(
      name: "Quinn Wilton",
      github: Some("https://github.com/QuinnWilton"),
    ),
  ]

  gleam_contributors.list_contributor_to_list_string(lst)
  |> should.equal([
    "[Louis Pilfold](https://github.com/lpil)",
    "[Quinn Wilton](https://github.com/QuinnWilton)",
    "[Tom Whatmore](https://github.com/tomwhatmore)",
  ])
}
