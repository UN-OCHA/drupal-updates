#!/bin/bash

# Steps through the update process for drupal core or contrib modules.

# There are 5 stages, each with its own steps. This script tries to provide
# helpers for each of those stages, though some of those helpers are little
# more than links.
# The stages:
# 1. create PR
# 2. vrt comparison of prod and stage
# 3. Send communications, update Jira tickets
# 4. merge to main
# 5. create tags
# 6. stage deploy
# 7. Send more communications
# 8. prod deploy

. ./common.sh

# TODO
# Add open and copy for macOS, and windows.
# Include VRT - at least open some pages to test it.

###################

# Start here.
echo "Before starting, check BASEDIR is set in .env and the repos listed above"
echo "are appropriate. If necessary, alter them in repolist.txt."
wait_to_continue

# Get ticket number.
echo "Enter ticket number:"
read -r ticket_number

# Choose stage.
# Get type of update.
echo "Choose stage of updates"
options=("create PR" "send dev communications" "vrt comparison of prod and stage"  "merge to main" "create tags" "stage_deploy" "send deploy communications" "prod deploy")
select stage in "${options[@]}"; do
  case $stage in
    "create PR")
      create_pr "$ticket_number"

      break;;
    "send dev communications")
      dev_communications

      break;;
    "vrt comparison of prod and stage")
      vrt_comparison

      break;;
    "merge to main")
      merge_to_main

      break;;
    "create tags")
      create_tags

      break;;
    "stage_deploy")
      stage_deploy

      break;;
    "send deploy communications")
      deploy_communications

      break;;
    "prod deploy")
      prod_deploy

      break;;
    *) echo "invalid option ${REPLY}. Please choose a number."
  esac
done

