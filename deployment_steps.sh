#!/bin/bash

# Steps through the deployment process.

# There are 7 stages, each with its own steps. This script tries to provide
# helpers for each of those stages, though some of those helpers are little
# more than links.
# The stages:
# 1. vrt comparison of prod and dev
# 2. Send communications, update Jira tickets
# 3. merge to main
# 4. create tags
# 5. stage deploy
# 6. Send more communications
# 7. prod deploy

. ./common.sh

###################

# Start here.
echo "Before starting, check BASEDIR is set in .env and the repos listed above"
echo "are appropriate. If necessary, alter them in repolist.txt."
wait_to_continue

# Choose stage.
# Get type of update.
echo "Choose stage of updates"
options=("send dev communications" "vrt comparison of prod and dev" "merge to main" "create tags" "stage_deploy" "send deploy communications" "prod deploy")
select stage in "${options[@]}"; do
  case $stage in
  "send dev communications")
    dev_communications

    break
    ;;
  "vrt comparison of prod and dev")
    vrt_comparison

    break
    ;;
  "merge to main")
    merge_to_main

    break
    ;;
  "create tags")
    create_tags

    break
    ;;
  "stage_deploy")
    stage_deploy

    break
    ;;
  "send deploy communications")
    deploy_communications

    break
    ;;
  "prod deploy")
    prod_deploy

    break
    ;;
  *) echo "invalid option ${REPLY}. Please choose a number." ;;
  esac
done
