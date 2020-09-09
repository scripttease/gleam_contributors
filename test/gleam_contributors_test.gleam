import gleam_contributors
import gleam_contributors/sponsor.{Sponsor, Sponsorspage}
import gleam_contributors/contributor.{Contributor, Contributorspage}
import gleam_contributors/graphql
import gleam_contributors/json
import gleam/option.{None, Some}
import gleam/should
import gleam/set

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

  sponsor.decode_page(json.decode(payload))
  |> should.equal(Ok(Sponsorspage(nextpage_cursor: Error(Nil), sponsor_list: [])))
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
  sponsor.decode_page(json.decode(payload))
  |> should.equal(Ok(Sponsorspage(
    nextpage_cursor: Ok("Mg"),
    sponsor_list: [
      Sponsor(
        name: "Chris Young",
        avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
        github: "https://github.com/worldofchris",
        website: Error(Nil),
        cents: 500,
      ),
      Sponsor(
        name: "Bruno Michel",
        github: "https://github.com/nono",
        avatar: "https://avatars3.githubusercontent.com/u/2767?u=ff72b1ad63026e0729acc2dd41378e28ab704a3f&v=4",
        website: Ok("http://blog.menfin.info/"),
        cents: 500,
      ),
    ],
  )))
}

pub fn list_sponsor_to_list_string_test() {
  // let page = Sponsorspage(
  //   nextpage_cursor: Ok("Mg"),
  //   sponsor_list: [
  let lst = [
    Sponsor(
      name: "Chris Young",
      avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
      github: "https://github.com/worldofchris",
      website: Error(Nil),
      cents: 500,
    ),
    Sponsor(
      name: "Bruno Michel",
      github: "https://github.com/nono",
      avatar: "https://avatars3.githubusercontent.com/u/2767?u=ff72b1ad63026e0729acc2dd41378e28ab704a3f&v=4",
      website: Ok("http://blog.menfin.info/"),
      cents: 500,
    ),
  ]
  gleam_contributors.list_sponsor_to_list_string(lst)
  |> should.equal([
    "[Bruno Michel](https://github.com/nono)", "[Chris Young](https://github.com/worldofchris)",
  ])
}

pub fn filter_sponsors_test() {
  let lst = [
    Sponsor(
      name: "Chris Young",
      avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
      github: "https://github.com/worldofchris",
      website: Error(Nil),
      cents: 500,
    ),
    Sponsor(
      name: "Bruno Michel",
      github: "https://github.com/nono",
      avatar: "https://avatars3.githubusercontent.com/u/2767?u=ff72b1ad63026e0729acc2dd41378e28ab704a3f&v=4",
      website: Ok("http://blog.menfin.info/"),
      cents: 5000,
    ),
  ]
  let dollars = 20
  gleam_contributors.filter_sponsors(lst, dollars)
  |> // |> should.equal(["[Bruno Michel](https://github.com/nono)"])
  should.equal([
    Sponsor(
      name: "Bruno Michel",
      github: "https://github.com/nono",
      avatar: "https://avatars3.githubusercontent.com/u/2767?u=ff72b1ad63026e0729acc2dd41378e28ab704a3f&v=4",
      website: Ok("http://blog.menfin.info/"),
      cents: 5000,
    ),
  ])
}

pub fn filter_sponsors_none_test() {
  let lst = [
    Sponsor(
      name: "Chris Young",
      avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
      github: "https://github.com/worldofchris",
      website: Error(Nil),
      cents: 500,
    ),
    Sponsor(
      name: "Bruno Michel",
      github: "https://github.com/nono",
      avatar: "https://avatars3.githubusercontent.com/u/2767?u=ff72b1ad63026e0729acc2dd41378e28ab704a3f&v=4",
      website: Ok("http://blog.menfin.info/"),
      cents: 500,
    ),
  ]
  let dollars = 50

  gleam_contributors.filter_sponsors(lst, dollars)
  |> should.equal([])
}

pub fn filter_sponsors_many_unordered_500c() {
  let lst = [
    Sponsor(
      name: "Chris Young",
      avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
      github: "https://github.com/worldofchris",
      website: Error(Nil),
      cents: 50000,
    ),
    Sponsor(
      name: "Bruno Michel",
      github: "https://github.com/nono",
      avatar: "https://avatars3.githubusercontent.com/u/2767?u=ff72b1ad63026e0729acc2dd41378e28ab704a3f&v=4",
      website: Ok("http://blog.menfin.info/"),
      cents: 500,
    ),
    Sponsor(
      name: "Scripttease",
      avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
      github: "https://github.com/scripttease",
      website: Error(Nil),
      cents: 50000,
    ),
    Sponsor(
      name: "Jose Valim",
      avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
      github: "https://github.com/josevalim",
      website: Error(Nil),
      cents: 10000,
    ),
  ]
  let dollars = 50
  gleam_contributors.filter_sponsors(lst, dollars)
  |> // |> should.equal(
  //   [
  //     "[Chris Young](https://github.com/worldofchris)",
  //     "[Jose Valim](https://github.com/josevalim)",
  //     "[Scripttease](https://github.com/scripttease)",
  //   ],
  // )
  should.equal([
    Sponsor(
      name: "Chris Young",
      avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
      github: "https://github.com/worldofchris",
      website: Error(Nil),
      cents: 50000,
    ),
    Sponsor(
      name: "Scripttease",
      avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
      github: "https://github.com/scripttease",
      website: Error(Nil),
      cents: 50000,
    ),
    Sponsor(
      name: "Jose Valim",
      avatar: "https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4",
      github: "https://github.com/josevalim",
      website: Error(Nil),
      cents: 10000,
    ),
  ])
}

pub fn construct_sponsor_query_test() {
  let cursor = option.Some("Ng")
  let num_results = option.Some("2")

  graphql.construct_sponsor_query(cursor, num_results)
  |> should.equal(
    "{
  user(login: \"lpil\") {
    sponsorshipsAsMaintainer(after: \"Ng\", first: 2) {
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
  )
}

pub fn construct_sponsor_query_nocursor_test() {
  let cursor = option.None
  let num_results = option.Some("2")

  graphql.construct_sponsor_query(cursor, num_results)
  |> should.equal(
    "{
  user(login: \"lpil\") {
    sponsorshipsAsMaintainer(after: null, first: 2) {
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
  )
}

pub fn construct_sponsor_query_nonum_result_test() {
  let cursor = option.None
  let num_results = option.None

  graphql.construct_sponsor_query(cursor, num_results)
  |> should.equal(
    "{
  user(login: \"lpil\") {
    sponsorshipsAsMaintainer(after: null, first: 100) {
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
  let json =
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
  gleam_contributors.parse_datetime(json)
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
  let json =
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
  contributor.decode_page(json)
  |> should.equal(Ok(Contributorspage(
    nextpage_cursor: Error(Nil),
    contributor_list: [],
  )))
}

// TODO change previous to latest or current
pub fn parse_contributors_test() {
  let json =
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

  contributor.decode_page(json)
  |> should.equal(Ok(Contributorspage(
    nextpage_cursor: Ok("3cecc58691af74a1b9e1bdc7c9bd42020a7a9052 4"),
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
  )))
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
    "[Louis Pilfold](https://github.com/lpil)", "[Quinn Wilton](https://github.com/QuinnWilton)",
    "[Tom Whatmore](https://github.com/tomwhatmore)",
  ])
}

// TODO extract and test case_insensitive compare
// pub fn case_insensitive_contributor_compare_test() {
// TODO
// }
pub fn filter_creator_test() {
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

  gleam_contributors.filter_creator_from_contributors(lst)
  |> should.equal([
    Contributor(
      name: "Tom Whatmore",
      github: Some("https://github.com/tomwhatmore"),
    ),
    Contributor(
      name: "Quinn Wilton",
      github: Some("https://github.com/QuinnWilton"),
    ),
  ])
}
