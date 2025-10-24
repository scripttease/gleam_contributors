import gleam/dynamic/decode.{type Decoder}
import gleam/option

pub type Sponsor {
  Sponsor(name: String, github: String, website: option.Option(String))
}

// Type to interrogate a single page response from the API and determine if
// there is further pagination. The github API will return a maximum of 100
// results per page, however if there are more pages, the endCursor can be used
// as a starting point for the next query.
pub type Sponsorspage {
  Sponsorspage(
    nextpage_cursor: option.Option(String),
    sponsor_list: List(Sponsor),
  )
}

/// Decodes sponsor section of the response JSON (List of maps)
///
pub fn decoder() -> Decoder(Sponsor) {
  use github <- decode.subfield(["sponsorEntity", "url"], decode.string)
  use website <- decode.then(
    decode.one_of(
      decode.at(["sponsorEntity", "websiteUrl"], decode.optional(decode.string)),
      [decode.success(option.None)],
    ),
  )
  use name <- decode.then(
    decode.one_of(decode.at(["sponsorEntity", "name"], decode.string), [
      decode.at(["sponsorEntity", "login"], decode.string),
    ]),
  )

  decode.success(Sponsor(name: name, github: github, website: website))
}

// Takes response json string and returns a Sponsorspage
pub fn page_decoder() -> Decoder(Sponsorspage) {
  let decoder = {
    use sponsor_list <- decode.field("nodes", decode.list(decoder()))
    use nextpage_cursor <- decode.subfield(
      ["pageInfo", "endCursor"],
      decode.optional(decode.string),
    )
    decode.success(Sponsorspage(nextpage_cursor:, sponsor_list:))
  }
  decode.at(["data", "repositoryOwner", "sponsorshipsAsMaintainer"], decoder)
}

// Some sponsors wish to display their username differently, so override it for
// these people.
pub fn display_name(sponsor: Sponsor) -> String {
  case sponsor.github {
    "https://github.com/ktec" -> "Clever Bunny LTD"
    "https://github.com/varnerac" -> "NineFX"
    _ -> sponsor.name
  }
}

// Some sponsors have an avatar that would look good not in a circle on the
// website.
pub fn square_avatar(sponsor: Sponsor) -> Bool {
  case sponsor.github {
    "https://github.com/skunkwerks" -> True
    "https://github.com/smartlogic" -> True
    "https://github.com/hypno2000" -> True
    "https://github.com/varnerac" -> True
    _ -> False
  }
}

// Some sponsors wish to display their link differently, so override it for
// these people.
pub fn display_link(sponsor: Sponsor) -> String {
  let website = option.unwrap(sponsor.website, sponsor.github)
  case sponsor.github {
    "https://github.com/ktec" -> "https://github.com/cleverbunny"
    "https://github.com/team-alembic" -> website
    "https://github.com/skunkwerks" -> website
    "https://github.com/varnerac" -> website
    // TODO: fix this. It is an empty string if the sponsor is from liberapay
    "" -> website
    _ -> sponsor.github
  }
}
