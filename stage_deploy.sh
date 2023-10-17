#!/bin/bash

. ./common.sh

# Main routine
main () {

  for repo in "${repolist[@]}" ; do
    jenkins_name=$(jq -r '."'"$repo"'".jenkins_name' < ./repo-lookup.json)
    jenkins_other_name=$(jq -r '."'"$repo"'".jenkins_other_name' < ./repo-lookup.json)
    prod_url=$(jq -r '."'"$repo"'".prod_url' < ./repo-lookup.json)
    stage_url=$(jq -r '."'"$repo"'".stage_url' < ./repo-lookup.json)

    if [[ $repo = "docstore-site" ]]
    then
      continue
    fi

    # Copy production to staging
    restore_db
    deploy_prod_to_staging
    enable_stage_file_proxy
    run_cron

    # Deploy main to staging
    deploy_main_to_staging
    enable_stage_file_proxy
    run_cron

    wait_to_continue

    trigger_vrt_job

    vrt_report "$repo"
  done;
}

# Restore production DB.
restore_db () {
   curl -X POST --user ${JENKINS_USER}:${JENKINS_TOKEN} \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "SNAPSHOT=prod-current.sql.gz"  \
      "${jenkins_url}/job/${jenkins_other_name}-stage-database-restore/buildWithParameters"
}

# Get deployed tag from production.
get_deployed_tag () {
   local prodtag=$(curl -X GET --user ${JENKINS_USER}:${JENKINS_TOKEN} \
      "${jenkins_url}/job/${jenkins_other_name}-prod-deploy/lastSuccessfulBuild/api/json" \
      | jq .actions[0].parameters | jq '.[] | select(.name=="DOCKER_TAG")' | jq .value)

   # If empty check name.
   if [[ -n "$prodtag" ]]; then
      prodtag=$(curl -X GET --user ${JENKINS_USER}:${JENKINS_TOKEN} \
         "${jenkins_url}/job/${jenkins_other_name}-prod-deploy/lastSuccessfulBuild/api/json" \
         | jq .displayName \
         | tr " - " "\n" | tail -n1)
   fi

   # If empty assume main.
   if [[ -n "$prodtag" ]]; then
         prodtag=main
   fi

   echo ${prodtag}
}

# Deploy production tag.
deploy_prod_to_staging () {
   local prodtag=get_deployed_tag
   curl -X POST --user ${JENKINS_USER}:${JENKINS_TOKEN} \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "DOCKER_TAG=${prodtag}&BACKUP=0"  \
      "${jenkins_url}/job/${jenkins_other_name}-stage-deploy/buildWithParameters"
}

# Enable stage file proxy.
enable_stage_file_proxy () {
   curl -X POST --user ${JENKINS_USER}:${JENKINS_TOKEN} \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "COMMAND=en -y stage_file_proxy"  \
      "${jenkins_url}/job/${jenkins_other_name}-stage-drush/buildWithParameters"
}

# Run cron.
run_cron () {
   curl -X POST --user ${JENKINS_USER}:${JENKINS_TOKEN} \
      "${jenkins_url}/job/${jenkins_other_name}-stage-cron/build"
}

# Deploy main tag.
deploy_main_to_staging () {
   local prodtag=get_deployed_tag
   curl -X POST --user ${JENKINS_USER}:${JENKINS_TOKEN} \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "DOCKER_TAG=main&BACKUP=0"  \
      "${jenkins_url}/job/${jenkins_other_name}-stage-deploy/buildWithParameters"
}

# Trigger VRT job and send list of URLs.
trigger_vrt_job () {
   local ref_uri=prod_url
   local test_uri=stage_url

   curl -X POST --user ${JENKINS_USER}:${JENKINS_TOKEN} \
      --form "REF_URI=${ref_uri}" \
      --form "TEST_URI=${test_uri}"  \
      --form "config/urls_anon.txt=@../tools-vrt/config/sites/${repo}_anon.txt" \
      "${jenkins_url}/job/vrt-anonymous/buildWithParameters"
}

main
