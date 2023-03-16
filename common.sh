#!/bin/bash

# Functions that can be used by other updating scripts.

# set -e

requires () {
    if ! command -v "$1" &>/dev/null; then
        echo "Requires $1"
        exit 1
    fi
}

requires "composer"
requires "docker"
requires "git"

source ./.env
remote_url=$REMOTE_URL
full_path=$BASEDIR
jenkins_url=$JENKINS_URL

# Get repolist from repolist.txt
repolist=()
echo "List of repos to reset:"
while IFS= read -r -u 3 repo ; do
  # Skip blank lines and commented lines.
  case "$repo" in ''|\#*) continue ;; esac
  echo "$repo"
  repolist+=("$repo")
done 3< repolist.txt

# To allow checking output, or when something needs doing that hasn't yet been
# automated.
wait_to_continue () {
  read -r -p "Hit enter when you're ready to continue" _
}

# Open url.
# TODO: get this working for MacOS etc, and to give a warning if it fails.
open_url () {
  ( command -v xdg-open >/dev/null 2>&1 ) &&
    xdg-open "$1"
}

# Copy to both the selection buffer and clipboard with xclip.
# TODO: get this working for MacOS etc, and to give a warning if it fails.
copy_to_clipboard () {
  ( command -v xclip >/dev/null 2>&1 ) &&
    echo "$1" | xclip -i -sel c -f | xclip -i -sel p
}

update_branches () {
  branches=( "main" "develop" )
  for branch in "${branches[@]}"; do
    if [ "$repo" == "drupal-starterkit" ] && [ "$branch" == "develop" ]; then
      continue
    fi
    # TODO: still in development - remove when it's launched.
    if [ "$repo" == "unocha-site" ] && [ "$branch" == "main" ]; then
      continue
    fi
    echo "Updating $branch branch for $repo"
    if ! git checkout "$branch"; then
      echo $?
      echo "- - -"
      echo "Fix the unmerged changes for ${repo} and try this step again"
      exit
    fi
    if ! git pull; then 
      echo $?
      echo "- - -"
      echo "Fix the unmerged changes for ${repo} and try this step again"
      exit
    fi
  done
  echo "- - -"
  echo "- - -"
  echo "Develop and main branches for $repo updated"
}

need_a_feature_branch () {
  echo "- - -"
  echo "- - -"
  echo "checking feature branch for $repo"
  echo "- - -"
  echo "- - -"
  echo "start of output of 'git diff main --name-status'"
  echo "(if it scrolls off the screen, scroll down with 'j' and hit 'q' to escape)"
  diff_output=$(git diff main --name-status)
  diff_length=$(wc -l <<<"$diff_output" | cut -d" " -f1)
  if [ "$diff_length" -gt 12 ]; then
    copy_to_clipboard "${remote_url}/${repo}/compare/main...develop"
    echo "There are a number of differences, visit ${remote_url}/${repo}/compare/main...develop (the url has been copied to the clipboard) to decide whether the changes are significant enough to warrant a feature branch to avoid deploying changes to develop that aren't yet ready"
  else
    echo "$diff_output"
  fi
  echo "- - -"
  echo "- - -"
  echo "output finished."
  wait_to_continue

  # Reset branch name in case it has been changed.
  branch_name=$(echo "${branch_name}" | sed 's/feature\///')

  echo "Do we need a feature branch for $repo?"
  options=("yes" "no")
  select feature_branch in "${options[@]}"; do
    case $feature_branch in
      "yes")
        echo "setting feature branch for $repo"
        branch_name="feature/${branch_name}"
        echo "checking out main branch to create feature from"
        git checkout main
        break;;
      "no")
        echo "continuing"
        break;;
      *) echo "invalid option ${REPLY}. Please enter '1' for yes, '2' for no."
    esac
  done
}

set_new_branch () {
  echo "- - -"
  echo "- - -"
  echo "creating new branch in $repo"
  git checkout -b "$branch_name"

}

composer_update () {

  php_version=$(jq -r '."'"$repo"'".php_version' < ./repo-lookup.json)

  case $update_type in
    "core")
      echo "- - -"
      echo "- - -"
      echo "updating core for $repo"
      echo "will run 'docker run --rm -u \"$(id -u)\" -v \"$(pwd):/srv/www\" -w /srv/www -it public.ecr.aws/unocha/unified-builder:${php_version}-stable sh -c \"composer -v update drupal/core-* --with-all-dependencies\"'"
      echo "- - -"
      echo "- - -"
      docker run --rm -u "$(id -u)" -v "$(pwd):/srv/www" -w /srv/www -it "public.ecr.aws/unocha/unified-builder:${php_version}-stable" sh -c "composer -v update drupal/core-* --with-all-dependencies"
      return;;
    "contrib")
      echo "- - -"
      echo "- - -"
      echo "updating ${module_name} for $repo"
      echo "will run 'docker run --rm -u \"$(id -u)\" -v \"$(pwd):/srv/www\" -w /srv/www -it public.ecr.aws/unocha/unified-builder:${php_version}-stable sh -c \"composer -v update drupal/${module_name} --with-all-dependencies\"'"
      echo "- - -"
      echo "- - -"
      docker run --rm -u "$(id -u)" -v "$(pwd):/srv/www" -w /srv/www -it "public.ecr.aws/unocha/unified-builder:${php_version}-stable" sh -c "composer -v update drupal/${module_name} --with-all-dependencies"
      return;;
  esac

}

check_and_add_changes () {
  echo "- - -"
  echo "- - -"
  echo "in another tab/ window, 'cd ${full_path}/${repo}', check the changes are all as you'd expect and 'git add' them to the ${branch_name} branch of ${repo}"
  copy_to_clipboard "cd ${full_path}/${repo}"
  echo "CD command: 'cd ${full_path}/${repo}' copied to clipboard"
  echo "- - -"
  echo "- - -"
  wait_to_continue

}

commit_changes () {
  echo "- - -"
  echo "- - -"
  echo "confirm everything is ready to commit"
  echo "- - -"
  echo "- - -"
  wait_to_continue

  case $update_type in
    "core")
      echo "- - -"
      echo "- - -"
      echo "committing core update"
      echo "- - -"
      echo "- - -"
      new_version=$(composer show -f json drupal/core-recommended | jq .versions[] | sed s/\"//g)
      git commit -m "chore: update ${update_type} to ${new_version}" -m "Refs: ${ticket_number}"
      return;;
    "contrib")
      echo "- - -"
      echo "- - -"
      echo "committing contrib update"
      echo "- - -"
      echo "- - -"
      new_version=$(composer show -f json "drupal/${module_name}" | jq .versions[] | sed s/\"//g)
      git commit -m "chore: update ${module_name} module to ${new_version}" -m "Refs: ${ticket_number}"
      return;;
    "other")
      echo "- - -"
      echo "- - -"
      echo "committing changes"
      echo "- - -"
      echo "- - -"
      read -r -p "enter one-line commit message, including the standard commit type, the ticket number will be added on another line: " commit_message
      git commit -m "${commit_message}" -m "Refs: ${ticket_number}"
      return;;
  esac

}

push_changes () {
  echo "- - -"
  echo "- - -"
  echo "pushing to $repo remote"
  echo "- - -"
  echo "- - -"
  git push -u origin "$branch_name"
  echo "Create pull request at link above"
  copy_to_clipboard "[${ticket_number}] ${update_type} update"
  echo "PR title: '[${ticket_number}] ${update_type} update' copied to clipboard"

}

pre_deploy_tests () {

  for repo in "${repolist[@]}" ; do

    if [[ $repo = "docstore-site" ]]
    then
      continue
    fi

    stages=('reference' 'test')
    for stage in "${stages[@]}" ; do
      case $stage in
        "reference" )
          environment="prod" ;;
        "test" )
          environment="stage" ;;
      esac
      echo "Running $stage stage for $repo"
      run_vrt "$repo" "$stage" "$environment"
    done;

    vrt_report "$repo"
  done;
}

run_vrt () {
  repo="$1"
  stage="$2"
  environment="$3"

  cd ../tools-vrt || exit

  # TODO revise VRT logins so it works with authenticated users too.
  # statuses=( 'anon' 'auth' )
  statuses=( 'anon' )
  for status in "${statuses[@]}" ; do
    docker run -u "$(id -u)" --shm-size 512m --rm --name "${stage}" --net="host" --entrypoint npm -e REPO="${repo}" -e LOGGED_IN_STATUS="${status}" -e ENVIRONMENT="${environment}" -v "$(pwd):/srv" -v "$(pwd)/data/${repo}:/srv/data" -v "$(pwd)/config:/srv/config" -w /srv public.ecr.aws/unocha/vrt:local run "${stage}"
  done

  cd - || exit
}

vrt_report () {
  repo="$1"

  cd ../tools-vrt || exit

  statuses=( 'anon' 'auth' )
  for status in "${statuses[@]}" ; do
    file="file://$(pwd)/data/${repo}/${status}/html_report/index.html"
    echo "Opening $file in browser"
    open_url "$file"
  done

  cd - || exit

  # Match repo name to elk name.
  elk_name=$(jq -r '."'"$repo"'".elk_name' < ../updates/repo-lookup.json)
  echo "Opening ELK report for $elk_name"

  log_url="https://elk.aws.ahconu.org/app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:now-15m,to:now))&_a=(columns:!(unocha.property,drupal_action,drupal.message,drupal_request_uri,syslog.severity_label,syslog.host),filters:!(('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:unocha.property,negate:!f,params:!(${elk_name}),type:phrases),query:(bool:(minimum_should_match:1,should:!((match_phrase:(unocha.property:${elk_name})))))),('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:syslog.severity_label,negate:!t,params:(query:informational),type:phrase),query:(match_phrase:(syslog.severity_label:informational))),('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:syslog.severity_label,negate:!t,params:(query:debug),type:phrase),query:(match_phrase:(syslog.severity_label:debug))),('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:syslog.severity_label,negate:!t,params:(query:notice),type:phrase),query:(match_phrase:(syslog.severity_label:notice))),('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:drupal.action,negate:!t,params:(query:'access%20denied'),type:phrase),query:(match_phrase:(drupal.action:'access%20denied'))),('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:drupal_action,negate:!t,params:(query:user_expire),type:phrase),query:(match_phrase:(drupal_action:user_expire)))),index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc)))"
  open_url "$log_url"
}

create_pr () {
  ticket_number="$1"
  # Get type of update.
  # TODO: This was set up before the periodic updates - the core/contrib/other
  # divide no longer makes much sense. Re-work for PRs that should be made
  # for multiple repos.
  echo "Choose type of update"
  options=("core" "contrib" "other")
  select update_type in "${options[@]}"; do
    case $update_type in
      "core" | "other")
        break;;
      "contrib")
        #get list of repos with this module in the composer json.
        read -r -p "module name to update: " module_name

        contrib_repolist=()

        for repo in "${repolist[@]}" ; do
          if composer show -q -d "${full_path}/${repo}" -o "drupal/${module_name}"
          then
            contrib_repolist+=("$repo")
          fi
        done;
        repolist=( "${contrib_repolist[@]}" )

        break;;
      *) echo "invalid option ${REPLY}. Please choose a number."
    esac
  done

  echo "Repos to be updated: "
  printf '%s\n' "${repolist[@]}"
  wait_to_continue

  case $update_type in
    "core")
      branch_name="${ticket_number}-${update_type}-update";;
    "contrib")
      branch_name="${ticket_number}-${module_name}-module-update";;
    "other")
      echo "Enter branch name (without the ticket number):"
      read -r branch_name
      branch_name="${ticket_number}-${branch_name}";;
  esac

  for repo in "${repolist[@]}" ; do

    echo "- - -"
    echo " --- "
    echo "- - -"
    echo "Processing repo $repo"

    echo "cd-ing to the $repo repo"
    cd "${full_path}/${repo}" || exit

    update_branches
    wait_to_continue

    need_a_feature_branch

    set_new_branch
    wait_to_continue

    case $update_type in
      "core" | "contrib")
        composer_update
        wait_to_continue
    esac

    check_and_add_changes

    commit_changes
    wait_to_continue

    push_changes
    wait_to_continue

    cd - || exit

    echo "All done"

  done
}

vrt_comparison () {
  echo "This uses vrt to open some links on the dev sites and compare them to" 
  echo "the same links on the production site."
  if [ ! -d "../tools-vrt" ]; then
    echo "This command assumes the Tools-vrt repo is checked out in the same"
    echo "directory as this 'updates' repo, and cannot run without it."
  else
    pre_deploy_tests
  fi;

}

merge_to_main () {

  echo "Opening pull requests."
  for repo in "${repolist[@]}" ; do
    open_url "${remote_url}/${repo}/compare/main...develop"
  done;
}

create_tags () {

  for repo in "${repolist[@]}" ; do
    echo "Creating tag for $repo"

    echo "cd-ing to the $repo repo"
    cd "${full_path}/${repo}" || exit

    # Get latest tag.
    git fetch --tags
    latest=$(git tag --sort=committerdate | tail -1)

    # Get next tag.
    next=$(echo "${latest}" | awk -F. -v OFS=. '{$NF += 1 ; print}')
    echo "The new tag will be $next"

    # Final URL
    today=$(date +%d-%m-%Y)
    url="${remote_url}/${repo}/releases/new?target=main&tag=$next&title=Deploy%20$today"
    echo "$url"

    open_url "${url}"
  done;
}

prod_deploy () {
  echo "Preparing prod deployments."
  for repo in "${repolist[@]}" ; do
    # Match repo to other names.
    stack_name=$(jq -r '."'"$repo"'".stack_name' < ./repo-lookup.json)
    jenkins_name=$(jq -r '."'"$repo"'".jenkins_name' < ./repo-lookup.json)
    jenkins_other_name=$(jq -r '."'"$repo"'".jenkins_other_name' < ./repo-lookup.json)

    echo "Running pre-deploy VRT for reference."
    run_vrt "$repo" reference prod

    echo "Opening jenkins links for $repo."
    open_url "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-login-url/build"
    open_url "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-deploy/build"
    open_url "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-drush"
    echo "Deploy this to prod and continue when it's done"
    wait_to_continue

    echo "Running post-deploy VRT for comparison."
    run_vrt "$repo" test prod

    echo "Opening VRT reports"
    vrt_report "$repo"

    echo "Opened pull request page for stack repo"
    open_url "${remote_url}/${stack_name}/pulls"
  done;
  echo "All done"
}
