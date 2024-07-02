# Drupal maintenance scripts

A group of scripts for automating common maintenance tasks for drupal repos.
Inspired by [this blogpost.](https://blog.danslimmon.com/2019/07/15/do-nothing-scripting-the-key-to-gradual-automation/)

There are four separate scripts:

* `common_changes.sh` For making the same change to more than one repo.

* `deployment_steps.sh` Test, prep and complete deployments. See steps below.

* `module_audit.sh` Produce a csv of all drupal and unocha modules used.

* `reset_branches.sh` A helper for the module audit script - checkout and update
develop and main branches and install dependencies for each repo.

## Best practices to avoid deploying unready changes

This section copied from a discussion on OPS-10218.

### Branch strategy
Anything that has a chance of going to main can be merged to develop.
If there's significant doubt, or it's likely to take a long time to get approval, use a feature branch.
If we need more instances for testing feature branches, we can ask for them.
Merging to main can happen whenever a feature is completed. It will normally be merged into develop first. If it's not, merge main to develop. We can look at adding a github action to enforce this.
Branches for security deployments should be made from the currently deployed tag, not from main.
Any changes deployed to production should be merged back into develop and main.

### Communication
Communicate all changes that you judge would be useful for others to know about. (But beware of information overload.)
PR descriptions should be more consistent: useful PR title, ticket reference, short description of the changes (with a bit of background if complex), test steps and/or any information about what to expect, what to be careful about when reviewing etc.

### Avoiding unready changes getting to production
The person doing deployments should check Jira boards for all properties to look for any tickets that are still in testing. There is now a link in the 'dev communications' step to show each project's Jira board and any changes that will be included. If the changes are already merged to develop, they should communicate with the tester and/or developer to resolve the situation.
Significant merges to main should get reviewed and signed off by someone who is familiar with the changes.

## Requirements
Jenkins ID and API token, defined in `.env` file, to kick off vrt jobs.
See https://www.jenkins.io/blog/2018/07/02/new-api-token-system/

Most other requirements: docker, composer, git, curl, etc. will already exist.

The deploy script requires `jq`
on Ubuntu `sudo apt install jq`
for others: https://jqlang.github.io/jq/download/
and `composer-lock-diff`
`composer global require davidrjonas/composer-lock-diff:^1.0`

The module audit script requires `libxml2-utils`:
on Ubuntu `sudo apt install libxml2-utils`
TODO: check if this is already installed for MacOS

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
* Complete movement of uses of vrt from local to Jenkins.

## Assumptions:
* all the repositories are in the same parent directory
* each repo has a `main` and a `develop` branch
* names of repos to be updated are listed in `repolist.txt` and\
`repo-lookup.txt`, both found in the same directory as this script.
