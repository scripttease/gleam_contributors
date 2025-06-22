import gleam/dynamic/decode.{type Decoder}
import gleam/option.{type Option}

pub type Contributor {
  Contributor(name: String, github: Option(String))
}

// Could include avatarURl and websiteUrl if required
pub type Contributorspage {
  Contributorspage(
    nextpage_cursor: option.Option(String),
    contributor_list: List(Contributor),
  )
}

pub fn decoder() -> Decoder(Contributor) {
  let decoder = {
    use name <- decode.then(
      decode.one_of(decode.at(["name"], decode.string), [
        decode.at(["user", "login"], decode.string),
      ]),
    )
    use github <- decode.then(
      decode.one_of(
        decode.at(["user", "url"], decode.string) |> decode.map(option.Some),
        [decode.success(option.None)],
      ),
    )
    decode.success(Contributor(name:, github:))
  }
  decode.at(["author"], decoder)
}

/// Converts response json into Gleam type. Represents one page of contributors
pub fn page_decoder() -> Decoder(Contributorspage) {
  let decoder = {
    use contributor_list <- decode.field("nodes", decode.list(decoder()))
    use nextpage_cursor <- decode.subfield(
      ["pageInfo", "endCursor"],
      decode.optional(decode.string),
    )
    decode.success(Contributorspage(nextpage_cursor:, contributor_list:))
  }
  decode.at(["data", "repository", "object", "history"], decoder)
}
