# gleam_contributors

A Gleam program


## Quick start

```sh
# Build the project
rebar3 compile

# Run the eunit tests
rebar3 eunit

# Run the Erlang REPL
rebar3 shell
```


## Command-line tooling

Use escriptize:

```sh
rebar3 escriptize
```

This creates a file:

`_build/default/bin/my_project_name` which requires a fn `main` as the entrypoint