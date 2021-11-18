import gleam/dynamic.{Dynamic}

pub external fn encode(anything) -> String =
  "jsone" "encode"

// Should this be Dynamic?
pub external fn decode(String) -> Dynamic =
  "jsone" "decode"
