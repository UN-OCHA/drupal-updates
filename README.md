# Helpful maintenance scripts

A group of helpful scripts for automating common maintenance tasks.
Inspired by [this blogpost.](https://blog.danslimmon.com/2019/07/15/do-nothing-scripting-the-key-to-gradual-automation/)

The initial focus was on updating core or specific contrib modules for all the
repos, before periodic updates were automated in github actions.

It's now more useful for following the steps of a deployment process, modifying
a few sites at once, and running audits.

## Requirements
Most requirements - docker, composer, git, curl should already be in place.
The module audit script requires `libxml2-utils`:
on Ubuntu `sudo apt install libxml2-utils`

## List of scripts:

* common.sh
Common functions used by one or more of the scripts here.

* drupal_updates.sh
A lightly automated checklist to step through multiple drupal repos. Used for
making repetitive changes or preparing and performing deployments.

* module_audit.sh
Generates csv files listing all modules and which repos they're used in,
and similar for outdated modules.

* reset_branches.sh
Update main and develop branches for each repo, running composer install to
bring packages up-to-date.

## List of configuration files:

* repolist.txt
A list of repos to run the scripts on. These often change depending on the job.

* repo-lookup.json
A dictionary to match repo names (for jenkins, elk, the stack and the prod url).

## Stages of drupal_updates.sh script.
For making changes to more than one repo:
1. create PR
Deployment steps:
2. test with vrt - comparison of prod and stage
3. send communications
4. merge to main
5. create tags
6. deploy tag to stage
7. send more communications
8. prod deploy - including post-deployment tests

## Post deployment tests
* GTM (see `check_gtm` function in `common.sh`).
This curls the homepage and checks for the 'GTM-' string.
* CERF pdfs
Checks
https://cerf.un.org/what-we-do/allocation-pdf/2021/summary/21-RR-COL-49434
to see if it returns a pdf.

## TODO
* Adapt 'open' and 'copy' commands for macOS, and windows.

## Assumptions:
* all the repositories are in the same parent directory
* each repo has a `main` and a `develop` branch
* names of repos to be updated are listed in `repolist.txt` and\
`repo-lookup.txt`, both found in the same directory as this script.
