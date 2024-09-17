#!/bin/bash

. ./common.sh

requires "gh"

# Main routine
main () {

   echo "vars: ${jenkins_other_name} - ${tag} - ${command}"

   case $command in

   vrt)
      run_vrt
      ;;

   pr)
      create_pr
      ;;

   release)
      create_release
      ;;

   restore)
      restore_db
      ;;

   deploy)
      deploy_prod_to_staging
      ;;

   proxy)
      enable_stage_file_proxy
      ;;

   cron)
      run_cron
      ;;

   prepstage)
      restore_db
      deploy_prod_to_staging
      enable_stage_file_proxy
      run_cron
      ;;

   *)
      echo Usage: ./prep_prod.sh -r ai-summarize-site -t main -c vrt
      echo Usage: ./prep_prod.sh -r ai-summarize-site -t main -c pr
      echo Usage: ./prep_prod.sh -r ai-summarize-site -t main -c release
      echo Usage: ./prep_prod.sh -r ai-summarize-site -t main -c restore
      echo Usage: ./prep_prod.sh -r ai-summarize-site -t main -c deploy
      echo Usage: ./prep_prod.sh -r ai-summarize-site -t main -c proxy
      echo Usage: ./prep_prod.sh -r ai-summarize-site -t main -c cron
      ;;

   esac
}

# Restore production DB.
restore_db () {
   curl -X POST --user ${JENKINS_ID}:${JENKINS_TOKEN} \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "SNAPSHOT=prod-current.sql.gz"  \
      "${jenkins_url}/job/${jenkins_other_name}-stage-database-restore/buildWithParameters"
}

# Deploy production tag.
deploy_prod_to_staging () {
   curl -X POST --user ${JENKINS_ID}:${JENKINS_TOKEN} \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "DOCKER_TAG=${tag}&BACKUP=0"  \
      "${jenkins_url}/job/${jenkins_other_name}-stage-deploy/buildWithParameters"
}

# Enable stage file proxy.
enable_stage_file_proxy () {
   curl -X POST --user ${JENKINS_ID}:${JENKINS_TOKEN} \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "COMMAND=en -y stage_file_proxy"  \
      "${jenkins_url}/job/${jenkins_other_name}-stage-drush/buildWithParameters"
}

# Run cron.
run_cron () {
   curl -X POST --user ${JENKINS_ID}:${JENKINS_TOKEN} \
      "${jenkins_url}/job/${jenkins_other_name}-stage-cron/build"
}

# Start VRT develop vs production.
run_vrt() {
   if [ "$jenkins_name" = "n/a" ]; then
      continue
   fi

   echo "Kicking off jenkins vrt job for $repo."
   curl -X POST --user ${JENKINS_ID}:${JENKINS_TOKEN} "${jenkins_url}/view/VRT/job/vrt-anonymous/buildWithParameters?delay=0sec&REFERENCE_URI=${prod_url}&TEST_URI=${dev_url}&SITE_REPOSITORY=git@github.com:UN-OCHA/${repo}.git"
}

# Create PR for main.
create_pr() {
   echo "Creating PR for $repo."
   cd ${full_path}/${repo}
   tomorrow=$(date --date="tomorrow" +%d-%m-%Y)
   ts=$(date --date="tomorrow" +%Y%m%d)

   git fetch --prune
   git checkout develop
   git pull origin develop
   $COMPOSER install

   git checkout main
   git checkout -b deploy-20240917
   git merge develop

   $COMPOSER_CHANGELOG
   git diff --unified=0 CHANGELOG.md  | grep '^[+-]' | grep -Ev '^(--- a/|\+\+\+ b/)' | sed 's/^\+//g' > changes.md
   echo "## Composer changes" >> changes.md
   echo "" >> changes.md
   $COMPOSER_LOCK_DIFF --from main --to develop --only-prod --md >> changes.md 

   echo Changelog updated and changes.md generated.
   wait_to_continue

   $COMPOSER update --lock
   git add composer.lock composer.json CHANGELOG.md 
   git commit -m 'Prepare deployment ${tomorrow}'
   git push origin deploy-${ts}
   gh pr create --base main --title "Deploy ${tomorrow}" --body-file changes.md --reviewer lazysoundsystem
}

# Create new release.
create_release() {
   echo "Creating release for $repo."
   cd ${full_path}/${repo}
   git checkout main
   git pull origin main
   git fetch --tags

   latest=$(git tag --sort=committerdate | tail -1)
   next=$(echo "${latest}" | awk -F. -v OFS=. '{$NF += 1 ; print}')

   tomorrow=$(date --date="tomorrow" +%d-%m-%Y)
   gh release create ${next} --target main --title "Deploy ${tomorrow}" --notes-file changes.md
}

while getopts j:t:c: flag
do
    case "${flag}" in
        r) repo=${OPTARG};;
        t) tag=${OPTARG};;
        c) command=${OPTARG};;
    esac
done

prod_url=$(jq -r '."'"$repo"'".prod_url' <./repo-lookup.json)
prod_url="https://$prod_url"
dev_url=$(jq -r '."'"$repo"'".dev_url' <./repo-lookup.json)
dev_url="https://$BASIC_AUTH_CREDENTIALS@$dev_url"
jenkins_name=$(jq -r '."'"$repo"'".jenkins_name' <./repo-lookup.json | sed 's/ /%20/' )
jenkins_other_name=$(jq -r '."'"$repo"'".jenkins_other_name' <./repo-lookup.json)

main
