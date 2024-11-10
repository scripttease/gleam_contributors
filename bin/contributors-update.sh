#!/bin/sh
set -eu

gleam run readme-list ~/src/gleam/gleam/README.md
gleam run website-yaml ~/src/gleam/website/_data/sponsors.yml
