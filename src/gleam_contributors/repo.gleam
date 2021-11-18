import gleam/dynamic.{DecodeError, Dynamic}
import gleam/list

pub type Repo {
  Repo(org: String, name: String)
}

// TODO Add nextpage cursor for when number of repos exceed 100 results
pub fn decode_organisation_repos(
  repos_json: Dynamic,
  org_n: String,
) -> Result(List(Repo), DecodeError) {
  try data = dynamic.field(repos_json, "data")

  try org = dynamic.field(data, "organization")
  try repos = dynamic.field(org, "repositories")
  try nodes = dynamic.field(repos, "nodes")
  let name_field = fn(repo) {
    try dynamic_name = dynamic.field(repo, "name")
    dynamic.string(dynamic_name)
  }
  try repo_string_list = dynamic.typed_list(nodes, of: name_field)
  let list_repo =
    list.map(repo_string_list, fn(string) { Repo(org: org_n, name: string) })
  Ok(list_repo)
}
