import gleam/dynamic.{DecodeError, Dynamic}
import gleam/list

pub type Repo {
  Repo(org: String, name: String)
}

// TODO Add nextpage cursor for when number of repos exceed 100 results
pub fn decode_organisation_repos(
  repos_json: Dynamic,
  org_name: String,
) -> Result(List(Repo), List(DecodeError)) {
  let repo = fn(data) {
    try name = dynamic.field("name", dynamic.string)(data)
    Ok(Repo(org_name, name))
  }

  let repos =
    dynamic.field(
      "data",
      dynamic.field(
        "organization",
        dynamic.field(
          "repositories",
          dynamic.field("nodes", dynamic.list(of: repo)),
        ),
      ),
    )

  repos_json
  |> repos
}
