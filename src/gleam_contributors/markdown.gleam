//// Functions for rendering markdown format text.

import gleam/list
import gleam/string

/// Build a markdown unordered list from a list of strings
///
pub fn unordered_list(contributors: List(String)) -> String {
  let string_out =
    list.fold(
      contributors,
      "",
      fn(acc, elem) {
        acc
        |> string.append("\n - ")
        |> string.append(elem)
      },
    )
  string.concat([string_out, "\n"])
}

/// Build markdown hyperlink.
///
pub fn link(text: String, to href: String) -> String {
  string.concat(["[", text, "](", href, ")"])
}
