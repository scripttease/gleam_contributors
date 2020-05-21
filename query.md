# Queries to the github api v4

[https://developer.github.com/v4/explorer/](https://developer.github.com/v4/explorer/)

## For sponsors query

Note that this is for a second page. For a first page do (first: 100) no need for the after. The after is the endCursor and is only required if hasNextPage is True, and then the request would look like say (after: "Ng", first: 100)

```json
query getSponsors($cursor: String, $count: Int){
  user(login: "lpil") {
    sponsorshipsAsMaintainer(after: $cursor, first: $count) {
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
}
```
#### Variables

```json
{
  "count": 2, // max is 100
  "cursor": null
}
```

#### Result

NB TIER is missing because request requires owners api token.

```json
{
  "data": {
    "user": {
      "sponsorshipsAsMaintainer": {
        "pageInfo": {
          "hasNextPage": true,
          "endCursor": "Mg"
        },
        "nodes": [
          {
            "sponsorEntity": {
              "name": "Bruno Michel",
              "url": "https://github.com/nono",
              "avatarUrl": "https://avatars3.githubusercontent.com/u/2767?u=ff72b1ad63026e0729acc2dd41378e28ab704a3f&v=4",
              "websiteUrl": "http://blog.menfin.info/"
            },
            "tier": null
          },
          {
            "sponsorEntity": {
              "name": "José Valim",
              "url": "https://github.com/josevalim",
              "avatarUrl": "https://avatars0.githubusercontent.com/u/9582?u=aa5911734b48eed403a69217a2f233d33af87836&v=4",
              "websiteUrl": "https://dashbit.co/"
            },
            "tier": null
          }
        ]
      }
    }
  }
}
```

## For contributors query

Note that a bang after a variable means it cannot be null.
Have left in next_release_time because we can use it to test this works on prev. releases
The output needs to be parsed for multiple names.
You have to do a request for each repo (eg gleam, stdlib, in both orgs (gleam-lang and gleam-experiments)

```graphql
query getCommits($org: String!, $repo: String!, $cursor: String, $previous_release_time: GitTimestamp!, $next_release_time: GitTimestamp) {
  repository(owner: $org, name: $repo) {
    object(expression: "master") {
      ... on Commit {
        history(since: $previous_release_time, until: $next_release_time, after: $cursor) {
          totalCount
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            author {
              name
            }
          }
        }
      }
    }
  }
}
```

#### Variables

```json
{
  "org": "gleam-lang",
  "repo": "gleam",
  "previous_release_time": "2010-01-20T10:05:45-06:00",
  "next_release_time": null,
  "cursor": null
}
```

#### RESULT

```json
{
  "data": {
    "repository": {
      "object": {
        "history": {
          "totalCount": 1259,
          "pageInfo": {
            "hasNextPage": true,
            "endCursor": "32ce0787178253d7ad5407bc0aba53f8b873c578 99"
          },
          "nodes": [
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Alice Dee"
              }
            },
            {
              "author": {
                "name": "Alice Dee"
              }
            },
            {
              "author": {
                "name": "Michael Borohovski"
              }
            },
            {
              "author": {
                "name": "Michael Borohovski"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "kyle-sammons"
              }
            },
            {
              "author": {
                "name": "kyle-sammons"
              }
            },
            {
              "author": {
                "name": "Alice Dee"
              }
            },
            {
              "author": {
                "name": "Alice Dee"
              }
            },
            {
              "author": {
                "name": "Alice Dee"
              }
            },
            {
              "author": {
                "name": "Alice Dee"
              }
            },
            {
              "author": {
                "name": "Alice Dee"
              }
            },
            {
              "author": {
                "name": "Alice Dee"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Alice Dee"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Peter Saxton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Quinn Wilton"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Anthony Bullard"
              }
            },
            {
              "author": {
                "name": "Anthony Bullard"
              }
            },
            {
              "author": {
                "name": "Anthony Bullard"
              }
            },
            {
              "author": {
                "name": "Anthony Bullard"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Tom Whatmore"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Anthony Bullard"
              }
            },
            {
              "author": {
                "name": "Keith"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Louis Pilfold"
              }
            },
            {
              "author": {
                "name": "Anthony Bullard"
              }
            },
            {
              "author": {
                "name": "Anthony Bullard"
              }
            },
            {
              "author": {
                "name": "Anthony Bullard"
              }
            }
          ]
        }
      }
    }
  }
}
```