import gleam/list
import gleam/string_builder.{StringBuilder}
import gleam_contributors/sponsor.{Sponsor}

pub fn sponsors_tiers(sponsors: List(tuple(String, List(Sponsor)))) -> String {
  sponsors
  |> list.map(tier)
  |> string_builder.concat
  |> string_builder.to_string
}

fn nested_sponsor_list_entry(sponsor: Sponsor) -> StringBuilder {
  [
    "- name: \"",
    sponsor.name,
    "\"\n  url: \"",
    sponsor.github,
    "\"\n  avatar: \"",
    sponsor.avatar,
    "\"\n",
  ]
  |> string_builder.from_strings
}

pub fn tier(sponsors: tuple(String, List(Sponsor))) -> StringBuilder {
  let tuple(name, sponsors) = sponsors
  string_builder.from_string(name)
  |> string_builder.append(":\n")
  |> string_builder.append_builder(
    sponsors
    |> list.map(nested_sponsor_list_entry)
    |> string_builder.concat,
  )
}
