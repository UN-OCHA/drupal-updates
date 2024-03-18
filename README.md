# Drupal maintenance scripts

A group of scripts for automating common maintenance tasks for drupal repos.
Inspired by [this blogpost.](https://blog.danslimmon.com/2019/07/15/do-nothing-scripting-the-key-to-gradual-automation/)

There are four separate scripts:

* `common_changes.sh` For making the same change to more than one repo.

* `deployment_steps.sh` Test, prep and complete deployments. See steps below.

* `module_audit.sh` Produce a csv of all drupal and unocha modules used.

* `reset_branches.sh` A helper for the module audit script - checkout and update
develop and main branches and install dependencies for each repo.

## Requirements
Jenkins ID and API token, defined in `.env` file, to kick off vrt jobs.
See https://www.jenkins.io/blog/2018/07/02/new-api-token-system/

Most other requirements: docker, composer, git, curl, etc. will already exist.

The deploy script requires `jq`
on Ubuntu `sudo apt install jq`
for others: https://jqlang.github.io/jq/download/

The module audit script requires `libxml2-utils`:
on Ubuntu `sudo apt install libxml2-utils`

## Configuration files

* `.env`
Common urls and secrets. Copy `.env.example` and set all the values.

* `repolist.txt`
A list of repos to run the scripts on. These often change depending on the job.

* `repo-lookup.json`
A dictionary to match repo names to e.g. jenkins names, elk name, and prod url.

## Deployment steps
1. test with vrt - comparison of prod and dev
1. send communications, update Jira tickets
1. merge to main
1. create tags
1. stage deploy
1. send more communications
1. prod deploy - including post-deployment tests

## Post deployment tests
* GTM (see `check_gtm` function in `common.sh`).
This curls the homepage and checks for the 'GTM-' string.
* CERF pdfs
Checks
https://cerf.un.org/what-we-do/allocation-pdf/2021/summary/21-RR-COL-49434
to see if it returns a pdf.

## TODO
* Adapt 'open' and 'copy' commands for macOS, and windows.
* Complete movement of uses of vrt from local to Jenkins.

## Assumptions:
* all the repositories are in the same parent directory
* each repo has a `main` and a `develop` branch
* names of repos to be updated are listed in `repolist.txt` and\
`repo-lookup.txt`, both found in the same directory as this script.
