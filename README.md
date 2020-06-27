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

## To autogenerate a list of sponsors in file using Github Actions:

This will generate a list of everyone who sponsors you over $10 per month

1. Set up your repo to perform github actions (Link required)
2. Add your github token to the repo secrets (Link required)
1. In the root directory of the file you want to autogenerate, in folder `.github/workflows/` create a `yaml` file with the following code

```yml
name: Sponsors List 

# Controls when the action will run.
# Can set to on: push for example.
# This will run every 15 minutes!
on:
  schedule:
    - cron:  '*/15 * * * *'

jobs:
  readme_edit:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: gleam-lang/setup-erlang@v1.0.0
      with:
        otp-version: 22.1
    - uses: gleam-lang/setup-gleam@v1.0.1
      with:
        gleam-version: 0.9.0
    - name: Clones gleam_contributors
      run: |
        git clone https://github.com/scripttease/gleam_contributors.git
        cd gleam_contributors
        rebar3 install_deps
        rebar3 eunit
        gleam format --check src test
        rebar3 escriptize
    - name: Adds Sponors to README
      run: |
        gleam_contributors/_build/default/bin/gleam_contributors GA $API_TOKEN README.md 
    # Runs a set of commands using the runners shell
    - name: Commits and pushes updated README
      run: |
        git add README.md
        git config user.email scripttease@users.noreply.github.com
        git config user.name Al Dee
        git commit README.md -m 'Update README.md with test Cron job' || echo "Update README.md failed"
        git push origin || echo "Push Failed"

```

2. In the name of the file that you wish to put your sponsors list, add the following code (For example, in the README.md) Then COMMENT OUT THE LINE! The file should be a markdown file.

```md
Below this line this file is autogenerated 
```

3. If you wish to instead run the sponsors list generator from the command line use:

```sh
_build/default/bin/gleam_contributors GA $TOKEN $FILENAME
```

GA is a tag, it does not need to be in quotes. 

<!-- Below this line this file is autogenerated -->

 - [Arian Daneshvar](https://github.com/bees)
 - [Ben Myles](https://github.com/benmyles)
 - [Bryan Paxton](https://github.com/starbelly)
 - [David McKay](https://github.com/rawkode)
 - [Erik Terpstra](https://github.com/eterps)
 - [Hasan YILDIZ](https://github.com/hsnyildiz)
 - [Hendrik Richter](https://github.com/hendi)
 - [Hécate](https://github.com/Kleidukos)
 - [James MacAulay](https://github.com/jamesmacaulay)
 - [John Palgut](https://github.com/Jwsonic)
 - [José Valim](https://github.com/josevalim)
 - [Keith](https://github.com/ktec)
 - [Lars Wikman](https://github.com/lawik)
 - [mario](https://github.com/mario-mazo)
 - [Mike Roach](https://github.com/mroach)
 - [ontofractal](https://github.com/ontofractal)
 - [Parker Selbert](https://github.com/sorentwo)
 - [Shritesh Bhattarai](https://github.com/shritesh)
 - [Wojtek Mach](https://github.com/wojtekmach)
