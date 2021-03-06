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
query getCommits($org: String!, $repo: String!, $cursor: String, $previous_release_time: GitTimestamp, $next_release_time: GitTimestamp, $count: Int) {
  repository(owner: $org, name: $repo) {
    object(expression: "master") {
      ... on Commit {
        history(since: $previous_release_time, until: $next_release_time, after: $cursor, first: $count) {
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
}

```

#### Variables

```json
{
  "org": "gleam-lang",
  "repo": "gleam",
  "previous_release_time": "2020-03-01T19:22:35Z",
  "next_release_time": "2020-05-07T18:57:47Z",
  "count": 5,
  "cursor": null,
  "version": "v0.8.0"
}
```

#### RESULT
NB will contain duplicates

```json
{
  "data": {
    "repository": {
      "object": {
        "history": {
          "totalCount": 259,
          "pageInfo": {
            "hasNextPage": true,
            "endCursor": "3cecc58691af74a1b9e1bdc7c9bd42020a7a9052 4"
          },
          "nodes": [
            {
              "author": {
                "name": "Louis Pilfold",
                "user": {
                  "login": "lpil",
                  "url": "https://github.com/lpil"
                }
              }
            },
            {
              "author": {
                "name": "Louis Pilfold",
                "user": {
                  "login": "lpil",
                  "url": "https://github.com/lpil"
                }
              }
            },
            {
              "author": {
                "name": "Louis Pilfold",
                "user": {
                  "login": "lpil",
                  "url": "https://github.com/lpil"
                }
              }
            },
            {
              "author": {
                "name": "Tom Whatmore",
                "user": {
                  "login": "tomwhatmore",
                  "url": "https://github.com/tomwhatmore"
                }
              }
            },
            {
              "author": {
                "name": "Tom Whatmore",
                "user": {
                  "login": "tomwhatmore",
                  "url": "https://github.com/tomwhatmore"
                }
              }
            }
          ]
        }
      }
    }
  }
}
```

## For Release Datetime query

```graphql
query releasedate($version: String!) {
  repository(name: "gleam", owner: "gleam-lang") {
    release(tagName: $version) {
      tag {
        target {
          ... on Commit {
            committedDate
          }
        }
      }
    }
  }
}
```

#### Variables

```graphql
{
  "version": "v0.8.1"
}
```

#### Results

```json
{
  "data": {
    "repository": {
      "release": {
        "tag": {
          "target": {
            "committedDate": "2020-05-19T16:09:23Z"
          }
        }
      }
    }
  }
}
```

## Repository name query

```graphql
{
  organization(login: "Gleam") {
    repositories {
      ... on RepositoryConnection {
        pageInfo {
          endCursor
        }
        nodes {
          name
        }
      }
    }
  }
}
```
