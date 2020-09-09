import gleam/dynamic.{Dynamic}

pub external fn encode(a) -> String =
  "jsone" "encode"

pub external fn decode(String) -> Dynamic =
  "jsone" "decode"
