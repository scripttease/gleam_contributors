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

This creates an executable file:

`_build/default/bin/my_project_name` which requires a fn `main` as the entrypoint This must be followed a space and then by your github api token, generated with the necessary permissions.

The following must also be inculded in `deps` in `rebar.config`:

```conf
{deps, [
    {gleam_stdlib, "0.8.0"},
    {gleam_httpc, {git, "https://github.com/gleam-experiments/httpc"}},
    jsone
]}.
```

The following must be included in the `applications` list in `my_project_name.app.src`:

`gleam_httpc, ssl, inets`

These erlang tools and the Application (named) need to be started in the entry point function `main` in order for the command line tooling to work with inets ssl etc.
