import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam_contributors/contributor.{type Contributor}
import gleam_contributors/markdown
import gleam_contributors/sponsor.{type Sponsor}

pub type Attributee {
  Attributee(name: String, github: Option(String))
}

pub fn from_sponsor(x: Sponsor) -> Attributee {
  Attributee(
    name: sponsor.display_name(x),
    github: Some(sponsor.display_link(x)),
  )
}

pub fn from_contributor(contributor: Contributor) -> Attributee {
  Attributee(name: contributor.name, github: contributor.github)
}

pub fn deduplicate(attributees: List(Attributee)) -> List(Attributee) {
  attributees
  |> list.map(fn(attributee) {
    let key = case attributee {
      Attributee(github: Some(github), ..) -> github
      Attributee(name: name, ..) -> string.append("name->", name)
    }
    #(key, attributee)
  })
  |> dict.from_list
  |> dict.values
}

pub fn sort_by_name(attributees: List(Attributee)) -> List(Attributee) {
  let compare_name = fn(a: Attributee, b: Attributee) {
    string.compare(string.lowercase(a.name), string.lowercase(b.name))
  }

  list.sort(attributees, compare_name)
}

pub fn to_markdown_link(attributee: Attributee) -> String {
  case attributee {
    Attributee(name: name, github: Some(github)) ->
      markdown.link(name, to: github)
    Attributee(name: name, github: None) -> name
  }
}
