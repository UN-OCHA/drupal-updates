#!/bin/bash

. ./common.sh

repo="response-site"
jenkins_name=$(jq -r '."'"$repo"'".jenkins_name' < ./repo-lookup.json)
jenkins_other_name=$(jq -r '."'"$repo"'".jenkins_other_name' < ./repo-lookup.json)

# Main routine
main () {
   restore_db
   deploy_prod_to_staging
   enable_stage_file_proxy
   run_cron
   wait_to_continue

   run_vrt_train
   wait_to_continue

   deploy_prod_to_staging
   enable_stage_file_proxy
   run_cron
   wait_to_continue

   run_vrt_test
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
   local prodtag = get_deployed_tag
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

# Trigger VRT training.
run_vrt_train () {
   local url="https://ocha:dev@stage.response-reliefweb-int.ahconu.org"
   cd ../tools-vrt || exit
   cp config/sites/${repo}_anon.txt config/urls_anon.txt

   docker run \
      --shm-size 512m \
      --rm \
      --net="host" \
      --name reference \
      --entrypoint npm \
      -e REF_URI=${url} \
      -v "$(pwd)/data:/srv/data" \
      -v "$(pwd)/config:/srv/config" \
      -w /srv \
      public.ecr.aws/unocha/vrt:main \
      run reference-anon
}

# Deploy main tag.
deploy_prod_to_staging () {
   local prodtag=get_deployed_tag
   curl -X POST --user ${JENKINS_USER}:${JENKINS_TOKEN} \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "DOCKER_TAG=main&BACKUP=0"  \
      "${jenkins_url}/job/${jenkins_other_name}-stage-deploy/buildWithParameters"
}

# Trigger VRT test.
run_vrt_test () {
   local url="https://ocha:dev@stage.response-reliefweb-int.ahconu.org"
   cd ../tools-vrt || exit
   cp config/sites/${repo}_anon.txt config/urls_anon.txt

   docker run \
      --shm-size 512m \
      --rm \
      --net="host" \
      --name reference \
      --entrypoint npm \
      -e TEST_URI=${url} \
      -v "$(pwd)/data:/srv/data" \
      -v "$(pwd)/config:/srv/config" \
      -w /srv \
      public.ecr.aws/unocha/vrt:main \
      run test-anon
}

main
