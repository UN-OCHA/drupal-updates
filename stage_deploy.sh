#!/bin/bash

. ./common.sh

repo="response-site"
jenkins_name=$(jq -r '."'"$repo"'".jenkins_name' < ./repo-lookup.json)
jenkins_other_name=$(jq -r '."'"$repo"'".jenkins_other_name' < ./repo-lookup.json)

# Restore production DB.
curl -X POST --user ${JENKINS_USER}:${JENKINS_TOKEN} \
   -H "Content-Type: application/x-www-form-urlencoded" \
   -d "SNAPSHOT=prod-current.sql.gz"  \
   "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-stage-database-restore/buildWithParameters"

# Get deployed tag from production.
prodtag=$(curl -X GET --user ${JENKINS_USER}:${JENKINS_TOKEN} \
   "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-deploy/lastSuccessfulBuild/api/json" \
   | jq .actions[0].parameters | jq '.[] | select(.name=="DOCKER_TAG")' | jq .value)

# If empty assume main.
if [[ -n "$prodtag" ]]; then
      prodtag=main
fi

# Deploy "main" tag.
curl -v -X POST --user ${JENKINS_USER}:${JENKINS_TOKEN} \
   -H "Content-Type: application/x-www-form-urlencoded" \
   -d "DOCKER_TAG=${prodtag}&BACKUP=0"  \
   "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-stage-deploy/buildWithParameters"

# Enable stage file proxy.

# Run cron.

# Trigger VRT training.
