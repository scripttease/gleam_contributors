import gleam/int
import gleam/list
import gleam/string_builder.{type StringBuilder}
import gleam_contributors/sponsor.{type Sponsor}

pub fn sponsors(sponsors: List(Sponsor)) -> String {
  sponsors
  |> list.map(sponsor_list_entry)
  |> string_builder.concat
  |> string_builder.to_string
}

fn sponsor_list_entry(sponsor: Sponsor) -> StringBuilder {
  [
    "- name: \"",
    sponsor.display_name(sponsor),
    "\"\n  url: \"",
    sponsor.display_link(sponsor),
    "\"\n  avatar: \"",
    sponsor.display_avatar(sponsor),
    "\"\n  tier: ",
    int.to_string(sponsor.tier(sponsor)),
    "\n  square_avatar: ",
    case sponsor.square_avatar(sponsor) {
      True -> "true"
      False -> "false"
    },
    "\n",
  ]
  |> string_builder.from_strings
}
