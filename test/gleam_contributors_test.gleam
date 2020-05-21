import gleam_contributors.{Sponsorspage, Sponsor}
import gleam/should

pub fn parse_empty_with_cursor_test() {
  let json = "
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
  gleam_contributors.parse_sponsors(json)
  |> should.equal(
    Ok(Sponsorspage(nextpage_cursor: Error(Nil), sponsor_list: [])),
  )
}

pub fn parse_test() {
  let json = "
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
  gleam_contributors.parse_sponsors(json)
  |> should.equal(
    Ok(
      Sponsorspage(
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
      ),
    ),
  )
}
