# gleam_contributors

A Gleam program that queries the Github v4 GraphQL API to request the [Gleam](https://github.com/gleam-lang) project's list of contributors and sponsors.


## Quick start

```sh
# Build the project
rebar3 compile

# Run the eunit tests
rebar3 eunit

# Run to enable escriptize IO commandline tooling
rebar3 escriptize

# Run the program!
_build/default/bin/gleam_contributors $TOKEN $FROM_VERSION $TO_VERSION

# Run the Erlang REPL (If required for debugging)
rebar3 shell
```


## Escriptize Usage

Running Escriptize creates an executable file:

`_build/default/bin/my_project_name` which requires a fn `main` as the entrypoint 

To make the api request, follow the filename by your [github api token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line), generated with the necessary permissions.

```sh
_build/default/bin/my_project_name $TOKEN $FROM_VERSION $TO_VERSION
```

Note that $TO_VERSION is optional, and will default to the current datetime if not given.