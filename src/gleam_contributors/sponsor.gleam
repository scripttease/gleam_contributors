import gleam/dynamic.{Dynamic}
import gleam/result

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
  try dynamic_name = dynamic.field(entity, "name")
  try name = dynamic.string(dynamic_name)
  try dynamic_avatar = dynamic.field(entity, "avatarUrl")
  try avatar = dynamic.string(dynamic_avatar)
  try dynamic_github = dynamic.field(entity, "url")
  try github = dynamic.string(dynamic_github)

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