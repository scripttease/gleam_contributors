import gleam/dynamic.{DecodeError, Dynamic}
import gleam/result
import gleam/string

pub type Sponsor {
  Sponsor(
    name: String,
    github: String,
    avatar: String,
    website: Result(String, Nil),
    cents: Int,
  )
}

// Type to interrogate a single page response from the API and determine if
// there is further pagination. The github API will return a maximum of 100
// results per page, however if there are more pages, the endCursor can be used
// as a starting point for the next query.
pub type Sponsorspage {
  Sponsorspage(
    nextpage_cursor: Result(String, Nil),
    sponsor_list: List(Sponsor),
  )
}

/// Decodes sponsor section of the response JSON (List of maps)
///
pub fn decode(json_obj: Dynamic) -> Result(Sponsor, List(DecodeError)) {
  try entity = dynamic.field("sponsorEntity", Ok)(json_obj)

  try github = dynamic.field("url", dynamic.string)(entity)
  try name =
    dynamic.field("name", dynamic.string)(entity)
    |> result.or(Ok(string.slice(
      from: github,
      at_index: string.length("https://github.com/"),
      length: 1000,
    )))
  try avatar = dynamic.field("avatarUrl", dynamic.string)(entity)
  let website =
    dynamic.field("websiteUrl", dynamic.string)(entity)
    |> result.map_error(fn(_) { Nil })
  try cents =
    dynamic.field("tier", dynamic.field("monthlyPriceInCents", dynamic.int))(
      json_obj,
    )
  Ok(Sponsor(
    name: name,
    github: github,
    avatar: avatar,
    website: website,
    cents: cents,
  ))
}

// Takes response json string and returns a Sponsorspage
pub fn decode_page(sponsors: Dynamic) -> Result(Sponsorspage, List(DecodeError)) {
  // TODO error message string?
  // only returns if result(Ok(_))
  // only called if there is no nextpage, ie result -> Error(Nil)
  try data = dynamic.field("data", Ok)(sponsors)
  try user = dynamic.field("user", Ok)(data)
  try spons = dynamic.field("sponsorshipsAsMaintainer", Ok)(user)
  try page = dynamic.field("pageInfo", Ok)(spons)
  try nextpage = dynamic.field("hasNextPage", dynamic.bool)(page)
  let cursor = case nextpage {
    False -> Error(Nil)
    True ->
      dynamic.field("endCursor", dynamic.string)(page)
      |> result.map_error(fn(_) { Nil })
  }
  try sponsors = dynamic.field("nodes", dynamic.list(decode))(spons)
  Ok(Sponsorspage(nextpage_cursor: cursor, sponsor_list: sponsors))
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
  let website = result.unwrap(sponsor.website, sponsor.github)
  case sponsor.github {
    "https://github.com/ktec" -> "https://github.com/cleverbunny"
    "https://github.com/skunkwerks" -> website
    "https://github.com/varnerac" -> website
    _ -> sponsor.github
  }
}

// Some sponsors wish to display their avatar differently, so override it for
// these people.
pub fn display_avatar(sponsor: Sponsor) -> String {
  case sponsor.github {
    "https://github.com/varnerac" ->
      "https://gleam.run/images/sponsors/nine-fx.png"
    _ -> sponsor.avatar
  }
}

pub fn tier(sponsor: Sponsor) -> Int {
  case sponsor.cents / 100 {
    dollars if dollars >= 1000 -> 4
    dollars if dollars >= 100 -> 3
    dollars if dollars >= 20 -> 2
    _otherwise -> 1
  }
}
