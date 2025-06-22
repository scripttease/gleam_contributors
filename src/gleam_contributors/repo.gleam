import gleam/dynamic/decode.{type Decoder}

pub type Repo {
  Repo(org: String, name: String)
}

// TODO Add nextpage cursor for when number of repos exceed 100 results
pub fn decode_organisation_repos(org: String) -> Decoder(List(Repo)) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Repo(org:, name:))
  }
  decode.at(
    ["data", "organization", "repositories", "nodes"],
    decode.list(decoder),
  )
}
