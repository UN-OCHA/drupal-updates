#!/bin/bash

# Functions that can be used by other updating scripts.

# TODO
# Check 'open' and 'copy' commands for macOS.

# TODO running with `e` flag caused issues with vrt exit status, check the fix.
set -eu

requires() {
  if ! command -v "$1" &>/dev/null; then
    echo "Requires $1"
    exit 1
  fi
}

requires "composer"
requires "composer-lock-diff"
requires "curl"
requires "docker"
requires "git"
requires "jq"

source ./.env
remote_url=$REMOTE_URL
full_path=$BASEDIR
jenkins_url=$JENKINS_URL

communications_spreadsheet_url="https://unitednations.sharepoint.com/:x:/r/sites/OCHAIMB/Digital%20Services%20Section/06_Projects/Developer%20documentation%20and%20standards/Deployment%20communications.xlsx?d=w2438877454944452a3fd63a63b3d5870&csf=1&web=1&e=dkJ9El"

# Get repolist from repolist.txt
repolist=()
echo "List of repos to work on:"
while IFS= read -r -u 3 repo; do
  # Skip blank lines and commented lines.
  case "$repo" in '' | \#*) continue ;; esac
  echo "$repo"
  repolist+=("$repo")
done 3<repolist.txt

# To allow checking output, or when something needs doing that hasn't yet been
# automated.
wait_to_continue() {
  read -r -p "Hit enter when you're ready to continue" _
}

# Open url.
open_url() {
  ( (command -v xdg-open >/dev/null 2>&1) && xdg-open "$1" 2> /dev/null ) ||
    python3 -m webbrowser "$1"
}

# Copy to both the selection buffer and clipboard with xclip.
copy_to_clipboard() {
  ( (command -v xclip >/dev/null 2>&1) &&
    echo "$1" | xclip -i -sel c -f | xclip -i -sel p ) ||
  ( (command -v pbcopy >/dev/null 2>&1) &&
    echo "$1" | pbcopy )
}

update_branches() {
  branches=("main" "develop")
  for branch in "${branches[@]}"; do
    echo "Updating $branch branch for $repo"
    if ! git checkout "$branch"; then
      echo $?
      echo "- - -"
      echo "Fix the unmerged changes for ${repo} and try this step again"
      return 1
    fi
    if ! git pull; then
      echo $?
      echo "- - -"
      echo "Fix the unmerged changes for ${repo} and try this step again"
      return 1
    fi
  done
  echo "- - -"
  echo "- - -"
  echo "Develop and main branches for $repo updated"
}

need_a_feature_branch() {
  echo "checking feature branch for $repo"
  diff_output=$(git diff main --name-status)
  diff_length=$(wc -l <<<"$diff_output" | cut -d" " -f1)
  echo "* * *"
  echo "There are $diff_length files changed between main and develop."
  echo "* * *"
  if [ "$diff_length" -gt 12 ]; then
    open_url "${remote_url}/${repo}/compare/main...develop"
    echo "Visit ${remote_url}/${repo}/compare/main...develop (the url has been opened in the browser) to decide whether the changes are significant enough to warrant a feature branch to avoid deploying changes to develop that aren't yet ready"
  elif [ "$diff_length" -gt 0 ]; then
    echo "- - -"
    echo "$diff_output"
    echo "- - -"
    echo "Decide whether the changes are significant enough to warrant a feature branch to avoid deploying changes to develop that aren't yet ready"
  fi
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
      break
      ;;
    "no")
      echo "continuing"
      break
      ;;
    *) echo "invalid option ${REPLY}. Please enter '1' for yes, '2' for no." ;;
    esac
  done
}

set_new_branch() {
  echo "- - -"
  echo "- - -"
  echo "creating new branch in $repo"
  git checkout -b "$branch_name"

}

check_and_add_changes() {
  echo "- - -"
  echo "- - -"
  echo "In another tab/ window, 'cd ${full_path}/${repo}', make any changes necessary and 'git add' them to the ${branch_name} branch of ${repo}"
  copy_to_clipboard "cd ${full_path}/${repo}"
  echo "CD command: 'cd ${full_path}/${repo}' copied to clipboard"
  echo "- - -"
  echo "- - -"
  wait_to_continue

}

commit_changes() {
  echo "- - -"
  echo "- - -"
  echo "confirm everything is ready to commit"
  echo "- - -"
  echo "- - -"
  wait_to_continue

  echo "- - -"
  echo "- - -"
  echo "committing changes"
  echo "- - -"
  echo "- - -"
  git commit -m "${commit_message}" -m "Refs: ${ticket_number}"

}

push_changes() {
  echo "- - -"
  echo "- - -"
  echo "pushing to $repo remote"
  echo "- - -"
  echo "- - -"
  git push -u origin "$branch_name"
  pr_url=${remote_url}/${repo}/pull/new/${branch_name}
  echo "Opening url for PR: $pr_url"
  open_url "${pr_url}"
  echo "Reverting to develop branch"
  git checkout develop

}

check_gtm() {
  home="$1"
  echo "$home"
  echo "Checking for presence of GTM:"
  ga_id=$(jq -r '."'"$repo"'".ga_dashboard' <./repo-lookup.json)
  if [ "$ga_id" != "n/a" ]; then
    echo "Opening GA realtime dashboard for ${repo}"
    "$JIRA_BROWSER" "https://analytics.google.com/analytics/web/#/p${ga_id}/realtime/overview"
  fi
  curl -L -s "$home" | grep -iF "GTM-" || echo "Not finding GTM- key. Check this!"
  wait_to_continue
}

check_extra() {
  repo="$1"
  if [[ $repo = "cerf8" ]]; then
    echo "Checking PDF works for CERF"
    test_page="https://cerf.un.org/what-we-do/allocation-pdf/2021/summary/21-RR-COL-49434"
    curl -L -s "$test_page" | grep -iF "%%EOF" || echo "Didn't get a PDF returned. Check this!"
    wait_to_continue
    echo "Check the Publications page is doing okay"
    echo "If not, it may need multiple cache clears"
    open_url "https://cerf.un.org/about-us/publications"
    wait_to_continue
  elif [[ $repo = "unocha-site" ]]; then
    echo "Check the CBPF page is doing okay and the homepage map is working"
    open_url "https://www.unocha.org/country-based-pooled-funds"
    open_url "https://www.unocha.org"
    wait_to_continue
  elif [[ $repo = "other" ]]; then
    echo "additional checks here"
  else
    echo "No additional checks for $repo"
  fi
}

vrt_report() {
  repo="$1"
  job="$2"

  # TODO revise VRT logins so it works with authenticated users too.
  # statuses=( 'anon' 'auth' )
  statuses=('anon')
  for status in "${statuses[@]}"; do
    url="https://jenkins.aws.ahconu.org/view/VRT/job/${job}/lastCompletedBuild/artifact/data/${status}/html_report/index.html"
    echo "Opening $url in browser"
    open_url "$url"
  done

  # Match repo name to elk name.
  elk_name=$(jq -r '."'"$repo"'".elk_name' <./repo-lookup.json)
  echo "Opening ELK report for $elk_name"

  # TODO: this url works, but surely could be more concise.
  log_url="https://elk.aws.ahconu.org/app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:now-15m,to:now))&_a=(columns:!(unocha.property,drupal.action,drupal.message,drupal.request_uri,syslog.severity_label,unocha.environment),filters:!(('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:unocha.property,negate:!f,params:!(${elk_name}),type:phrases),query:(bool:(minimum_should_match:1,should:!((match_phrase:(unocha.property:${elk_name})))))),('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:syslog.severity_label,negate:!t,params:(query:informational),type:phrase),query:(match_phrase:(syslog.severity_label:informational))),('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:syslog.severity_label,negate:!t,params:(query:debug),type:phrase),query:(match_phrase:(syslog.severity_label:debug))),('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:syslog.severity_label,negate:!t,params:(query:notice),type:phrase),query:(match_phrase:(syslog.severity_label:notice))),('\$state':(store:appState),meta:(alias:!n,disabled:!f,index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',key:syslog.severity_label,negate:!t,params:(query:notice),type:phrase),query:(match_phrase:(syslog.severity_label:warning)))),index:'69b486f0-81d4-11ea-9a40-e9f42857bb64',interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc)))"
  open_url "$log_url"
}

create_pr() {
  ticket_number="$1"

  echo "Enter branch name (without the ticket number):"
  read -r branch_name
  branch_name=$(echo "${ticket_number}-${branch_name}" | tr ' ' '-')

  read -r -p "Enter a one-line commit message, including the standard commit type (without the ticket number):" commit_message

  for repo in "${repolist[@]}"; do

    echo "* * *"
    echo "Processing repo $repo"
    echo "* * *"

    echo "cd-ing to the $repo repo"
    cd "${full_path}/${repo}" || exit

    update_branches || (echo "Failed to update branches due to a merge conflict. In another tab/ window, 'cd ${full_path}/${repo}', and manually update the develop and main branches." &&
      copy_to_clipboard "cd ${full_path}/${repo}" &&
      echo "CD command: 'cd ${full_path}/${repo}' copied to clipboard")
    wait_to_continue

    need_a_feature_branch

    set_new_branch

    check_and_add_changes

    commit_changes

    push_changes
    wait_to_continue

    cd - || exit

  done

  echo "All done"

}

dev_communications() {

  echo "Check ${communications_spreadsheet_url} for communication steps"

  echo "Continue to open Jira boards for each site and to list the git commits since last deploy."

  wait_to_continue

  for repo in "${repolist[@]}"; do
    jira_name=$(jq -r '."'"$repo"'".jira_name' <./repo-lookup.json)
    if [ "$jira_name" != "n/a" ]; then
      echo "Opening jira board for ${repo}"
      "$JIRA_BROWSER" "https://humanitarian.atlassian.net/browse/$jira_name"
    fi

    echo "Git logs and module updates for ${repo} printed below to show changes"
    cd "${full_path}/${repo}" || exit
    git fetch --prune
    git checkout develop
    git pull
    if [ -z "$(git rev-list --tags --max-count=1)" ]; then
      continue
    fi
    latest_tag_raw=$(git rev-list --tags --max-count=1)
    latest_tag=$(git describe --tags "$latest_tag_raw")
    git log "${latest_tag}..HEAD" --pretty="format:%cd%n%s%n%an%n%b%n--%n--%n"
    composer-lock-diff --from main --to develop --only-prod | less
    cd - || exit
    wait_to_continue
  done

  echo "All done"

}

vrt_comparison() {
  echo "This uses vrt to open some links on the dev sites and compare them to"
  echo "the same links on the production site."

  # Check we have a Jenkins API token.
  if [[ $JENKINS_TOKEN = '' ]]; then
    echo "A Jenkins API token is needed and should be defined in the .env file."
    echo "See https://www.jenkins.io/blog/2018/07/02/new-api-token-system/"
  else

    for repo in "${repolist[@]}"; do

      # Match repo to other names.
      prod_url=$(jq -r '."'"$repo"'".prod_url' <./repo-lookup.json)
      prod_url="https://$prod_url"
      dev_url=$(jq -r '."'"$repo"'".dev_url' <./repo-lookup.json)
      dev_url="https://$BASIC_AUTH_CREDENTIALS@$dev_url"
      jenkins_name=$(jq -r '."'"$repo"'".jenkins_name' <./repo-lookup.json | sed 's/ /%20/' )

      if [ "$jenkins_name" = "n/a" ]; then
        continue
      fi

      echo "Kicking off jenkins vrt job for $repo."
      curl -X POST --user ${JENKINS_ID}:${JENKINS_TOKEN} "${jenkins_url}/view/VRT/job/vrt-anonymous/buildWithParameters?delay=0sec&REFERENCE_URI=${prod_url}&TEST_URI=${dev_url}&SITE_REPOSITORY=git@github.com:UN-OCHA/${repo}.git"
      open_url "${jenkins_url}/view/VRT/job/vrt-anonymous"

      echo "When VRT job has finished, hit enter to see the results and logs."
      wait_to_continue
      vrt_report "$repo" "vrt-anonymous"

    done
  fi

  echo "All done"
}

merge_to_main() {

  echo "Listing package differences and opening pull requests."
  echo "List the main Jira tickets as:"
  printf "## Chores\n\n## Fixes\n\n## Features\n\n## Updates\n\n"
  echo "Copy drupal package differences to ## Updates section"
  echo "For an example, look at last month's merge to main"
  wait_to_continue
  for repo in "${repolist[@]}"; do

    open_url "${remote_url}/${repo}/compare/main...develop"

    cd "${full_path}/${repo}" || exit
    echo "Git logs for ${repo} printed below to show changes"
    cd "${full_path}/${repo}" || exit
    if [ -z "$(git rev-list --tags --max-count=1)" ]; then
      continue
    fi
    latest_tag_raw=$(git rev-list --tags --max-count=1)
    latest_tag=$(git describe --tags "$latest_tag_raw")
    git log "${latest_tag}..HEAD" --pretty="format:%cd%n%s%n%an%n%b%n--%n--%n"

    git fetch --prune
    git checkout develop
    git pull
    echo "Package changes for ${repo}"
    composer-lock-diff --from main --to develop --only-prod --md
    cd - || exit

    wait_to_continue
  done
  echo "All done"
}

create_tags() {

  for repo in "${repolist[@]}"; do
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
    # today=$(date +%d-%m-%Y)
    tomorrow=$(date --date="tomorrow" +%d-%m-%Y)
    url="${remote_url}/${repo}/releases/new?target=main&tag=$next&title=Deploy%20$tomorrow"
    echo "$url"

    open_url "${url}"
  done

  echo "Adjust date and tag version if necessary"
  echo "Use 'Generate release notes' button to summarize changes."
  echo "Then copy description from PR to main."
  echo "For an example, look at last month's tag descriptions."
}

stage_deploy() {
  echo "Deploying to stage - with a reset to what we have on production first."
  for repo in "${repolist[@]}"; do
    # Match repo to other names.
    jenkins_name=$(jq -r '."'"$repo"'".jenkins_name' <./repo-lookup.json | sed 's/ /%20/' )
    jenkins_other_name=$(jq -r '."'"$repo"'".jenkins_other_name' <./repo-lookup.json)

    echo "Links for jenkins test deploy for $repo."
    echo "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-testdeploy/build"
    # open_url "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-testdeploy/build"
  done

  echo "All done"
}

deploy_communications() {
  echo "Check ${communications_spreadsheet_url} for communication steps"
}

prod_deploy() {
  echo "Preparing prod deployments."
  for repo in "${repolist[@]}"; do
    # Match repo to other names.
    prod_url=$(jq -r '."'"$repo"'".prod_url' <./repo-lookup.json)
    jenkins_name=$(jq -r '."'"$repo"'".jenkins_name' <./repo-lookup.json)
    jenkins_other_name=$(jq -r '."'"$repo"'".jenkins_other_name' <./repo-lookup.json)

    echo "Opening jenkins links for $repo."
    open_url "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-login-url/build"
    open_url "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-deploy/build"
    open_url "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-drush"
    echo "Deploy this to prod and continue when it's done"
    wait_to_continue

    echo "Checking if GTM is present on the site"
    check_gtm "$prod_url"

    echo "Running any site-specific tests"
    check_extra "$repo"

    echo "Opening VRT report"
    vrt_report "$repo" "vrt-anonymous-step"

  done

  echo "All done"

}

post_deployment() {
  echo "Follow-up steps:"
  echo "Run ./reset-branches.sh in another terminal window to make sure everything is up-to-date"
  wait_to_continue
  echo "Add links to deployed tags to the Jira ticket."
  echo "These tags have been deployed - changes are listed on the tag pages:" > data/latest_tags.txt
  for repo in "${repolist[@]}"; do
    echo "cd-ing to the $repo repo"
    jenkins_name=$(jq -r '."'"$repo"'".jenkins_name' <./repo-lookup.json )
    cd "${full_path}/${repo}" || exit
    if [ -z "$(git rev-list --tags --max-count=1)" ]; then
      echo "No tag found. Continuing."
      cd - || exit
      continue
    fi
    latest_tag_id=$(git rev-list --tags --max-count=1)
    if [ "$latest_tag_id" = "" ]; then
      echo "Latest tag is empty. Continuing."
      cd - || exit
      continue
    fi
    latest_tag=$(git describe --tags "${latest_tag_id}")
    echo "Latest tag for repo is ${latest_tag}"
    cd - || exit
    echo " * $jenkins_name - __${latest_tag}__ - ${remote_url}/${repo}/releases/tag/${latest_tag}" >> data/latest_tags.txt

  done
  echo "List of latest tags is in ./data/latest_tags.txt. Copy that list to the ticket."
  echo "Check all open Jira tickets and update as necessary."
  echo "Run module audit script and update the spreadsheet."
}
