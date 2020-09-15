import gleam/list
import gleam/string_builder
import gleam_contributors/sponsor.{Sponsor}

fn concat(xs: List(String)) -> String {
  xs
  |> string_builder.from_strings
  |> string_builder.to_string
}

fn sponsor_list_entry(sponsor: Sponsor) -> String {
  ["- name: \"", sponsor.name, "\"\n", "  url: \"", sponsor.github, "\"\n"]
  |> concat
}

pub fn sponsors_list(sponsors: List(Sponsor)) -> String {
  sponsors
  |> list.map(sponsor_list_entry)
  |> concat
}
