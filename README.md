# Helpful maintenance scripts

A group of helpful scripts for automating common maintenance tasks.
Inspired by [this blogpost.](https://blog.danslimmon.com/2019/07/15/do-nothing-scripting-the-key-to-gradual-automation/)

The initial focus was on updating core or specific contrib modules for all the repos, before periodic updates were automated in github actions. It's now more useful for following the steps of a deployment process, modifying a few sites at once, and running audits.

## Requirements
Most requirements - docker, composer, git, curl should already be in place. The module audit script requires libxml2-utils  - on Ubuntu `sudo apt install libxml2-utils`

## List of scripts:

* common.sh
Functions that are used by most of the scripts here.

* drupal_updates.sh
A lightly automated checklist to step through multiple drupal repos updating
core or contrib modules.

* infra_audit.sh
Generates a csv file listing versions of php, solr and varnish for each repo.

* module_audit.sh
Generates csv files listing all modules and which repos they're used in,
and similar for outdated modules.

* reset_branches.sh
Update main and develop branches for each repo, running composer install to
bring packages up-to-date.

## Stages of drupal_updates.sh script.
There are 5 stages, each with its own steps. When commits have already been merged to dev, the deployment process uses the last four in turn.
* create PR
* test with vrt
* merge to main
* create tags
* prod deploy

## TODO
* Creating PRs is now handled weekly by a github action. Adapt this stage.
* Adapt 'open' and 'copy' commands for macOS, and windows.

## Assumptions:
* all the repositories are in the same parent directory
* names of repos to be updated are listed in `repolist.txt`, found in the same
* details of repos are up-to-date in `repo-lookup.txt`, found in the same
directory as this script
* each repo has a `main` and a `develop` branch
