import gleam/dynamic.{Dynamic}
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
pub fn decode(json_obj: Dynamic) -> Result(Sponsor, String) {
  try entity = dynamic.field(json_obj, "sponsorEntity")
  try dynamic_github = dynamic.field(entity, "url")
  try github = dynamic.string(dynamic_github)
  try dynamic_name = dynamic.field(entity, "name")
  try name =
    dynamic.string(dynamic_name)
    |> result.or(Ok(string.slice(
      from: github,
      at_index: string.length("https://github.com/"),
      length: 1000,
    )))
  try dynamic_avatar = dynamic.field(entity, "avatarUrl")
  try avatar = dynamic.string(dynamic_avatar)

  try dynamic_website = dynamic.field(entity, "websiteUrl")
  let website =
    dynamic.string(dynamic_website)
    |> result.map_error(fn(_) { Nil })

  try tier = dynamic.field(json_obj, "tier")
  try dynamic_cents = dynamic.field(tier, "monthlyPriceInCents")
  try cents = dynamic.int(dynamic_cents)

  Ok(Sponsor(
    name: name,
    github: github,
    avatar: avatar,
    website: website,
    cents: cents,
  ))
}

// Takes response json string and returns a Sponsorspage
pub fn decode_page(sponsors: Dynamic) -> Result(Sponsorspage, String) {
  try data = dynamic.field(sponsors, "data")
  try user = dynamic.field(data, "user")
  try spons = dynamic.field(user, "sponsorshipsAsMaintainer")
  try page = dynamic.field(spons, "pageInfo")

  try dynamic_nextpage = dynamic.field(page, "hasNextPage")
  try nextpage = dynamic.bool(dynamic_nextpage)

  // TODO error message string?
  let cursor = case nextpage {
    False -> Error(Nil)
    True ->
      dynamic.field(page, "endCursor")
      |> // only returns if result(Ok(_))
      result.then(dynamic.string)
      |> // only called if there is no nextpage, ie result -> Error(Nil)
      result.map_error(fn(_) { Nil })
  }

  try nodes = dynamic.field(spons, "nodes")
  try sponsors = dynamic.typed_list(nodes, of: decode)

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
