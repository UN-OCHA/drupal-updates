#!/bin/bash

# Steps through the update process for drupal core or contrib modules.

# There are 5 stages, each with its own steps. This script tries to provide
# helpers for each of those stages, though some of those helpers are little
# more than links.
# The stages:
# 1. create PR
# 2. test on stage
# 3. merge to main
# 4. create tags
# 5. prod deploy


# TODO
# Add open and copy for macOS, and windows.
# Include VRT - at least open some pages to test it.
# Add an env file for things that don't change - github url, local base dir.

source ./.env
remote_url=$REMOTE_URL
full_path=$BASEDIR
jenkins_url=$JENKINS_URL
testing_urls=$TESTING_URLS

# For when something needs doing that hasn't yet been automated.
wait_to_continue () {
  read -r -p "Hit enter when you're ready to continue" _
}

update_branches () {
# TODO: if this aborts because of unmerged changes, it will not update
# but won't warn that the update hasn't happened. Check for such silent
# failures.
  echo "updating main branch for $repo"
  git checkout main
  git pull
  echo $?
  echo "updating develop branch for $repo"
  git checkout develop
  git pull
  echo $?
  echo "- - -"
  echo "- - -"
  echo "Develop and main branches for $repo updated"
  echo "(or they should be - if there are unmerged changes, the update may fail"
  echo "check for the word 'Aborting' in the previous output, and later make"
  echo "this command check for failure and give a proper warning.)"
}

need_a_feature_branch () {
  echo "- - -"
  echo "- - -"
  echo "checking feature branch for $repo"
  echo "- - -"
  echo "- - -"
  echo "start of output of 'git diff main --name-status'"
  echo "(if it scrolls off the screen, scroll down with 'j' and hit 'q' to escape)"
  git diff main --name-status
  echo "- - -"
  echo "- - -"
  echo "output finished."
  echo "- - -"
  echo "- - -"
  echo ""
  echo ""
  echo "- - -"
  echo "- - -"
  echo "if necessary, visit ${remote_url}/${repo}/compare/main...develop to decide whether the changes are significant enough to warrant a feature branch to avoid deploying changes to develop that aren't yet ready"
  echo "- - -"
  echo "- - -"
  wait_to_continue

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

  echo "- - -"
  echo "- - -"
  echo "bringing composer up-to-date"
  composer install
}

check_php_version () {
  echo "- - -"
  echo "- - -"
  echo "checking php version for $repo"
  echo "- - -"
  echo "- - -"
  echo "required php version"
  echo "composer check-platform-reqs | grep php"
  composer check-platform-reqs | grep php
  echo "- - -"
  echo "- - -"
  echo "local php version"
  echo "composer show -p php | grep versions"
  composer show -p php | grep versions
  echo "- - -"
  echo "- - -"
  echo "compare the output above and, if necessary, alter your version of php"
  echo "for example (in Ubuntu, if alternatives are already in place):"
  echo "sudo update-alternatives --set php /usr/bin/php8.0 && sudo update-alternatives --set phar /usr/bin/phar8.0 && sudo update-alternatives --set phar.phar /usr/bin/phar.phar8.0"
  echo "- - -"
  echo "- - -"
  wait_to_continue

}

composer_update () {

  case $update_type in
    "core")
      echo "- - -"
      echo "- - -"
      echo "updating core for $repo"
      echo "will run 'composer -v update drupal/core-* --with-all-dependencies'"
      echo "- - -"
      echo "- - -"
      composer -v update "drupal/core-*" --with-all-dependencies
      return;;
    "contrib")
      echo "- - -"
      echo "- - -"
      echo "updating ${module_name} for $repo"
      echo "will run 'composer -v update drupal/${module_name} --with-all-dependencies'"
      echo "- - -"
      echo "- - -"
      composer -v update "drupal/${module_name}" --with-all-dependencies
      return;;
  esac

}

check_and_add_changes () {
  echo "- - -"
  echo "- - -"
  echo "in another tab/ window, 'cd ${full_path}/${repo}', check the changes are all as you'd expect and 'git add' them to the ${branch_name} branch of ${repo}"
  ( command -v xclip >/dev/null 2>&1 ) &&
    echo "cd ${full_path}/${repo}" | xclip -i -sel c -f |xclip -i -sel p &&
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
      read -r -p "enter one-line commit message, including the standard commit type, the ticket number will be appended: " commit_message
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
# Linux copy to both the selection buffer and clipboard with xclip.
  ( command -v xclip >/dev/null 2>&1 ) &&
    echo "[${ticket_number}] ${update_type} update" | xclip -i -sel c -f |xclip -i -sel p &&
    echo "PR title: '[${ticket_number}] ${update_type} update' copied to clipboard"

}

next_steps () {
  echo "- - -"
  echo "- - -"
  echo "Next steps:"
  echo "- - -"
  echo "- - -"
  echo "1. Get a review from another developer"
  echo "2. Merge to develop"
  echo "3. Deploy the changes to the dev environment if there isn’t already an automatic deployment"
  echo "4. Run the script again and work through the remaining stages. Next up is testing on staging."
}

test_on_stage () {
  echo "There's a list of links to test at $testing_urls"
  echo "Ask the content squad for help testing key pages."
  echo "After testing, check ELK for any errors or warnings which might not have been immediately obvious (or otherwise visible) to the content squad."
# Linux copy to both the selection buffer and clipboard with xclip.
  ( command -v xclip >/dev/null 2>&1 ) &&
    echo "$testing_urls" | xclip -i -sel c -f |xclip -i -sel p &&
    echo "Testing urls spreadsheet link copied to clipboard"
  echo "@todo open jenkins log-in pages for each dev site."
  echo "@todo open elk links filtered by each dev site."
  echo "@todo include VRT to check for differences"
}

create_pr () {
# Get type of update.
  echo "Choose type of update"
  options=("core" "contrib" "other")
  select update_type in "${options[@]}"; do
    case $update_type in
      "core" | "other")
        repolist=()
        echo "List of repos to update:"
        while IFS= read -r -u 3 repo ; do
          # Skip blank lines and commented lines.
          case "$repo" in ''|\#*) continue ;; esac
          echo "$repo"
          repolist+=("$repo")
        done 3< repolist.txt
        break;;
      "contrib")
        #get list of repos with this module in the composer json.
        read -r -p "module name to update: " module_name

        repolist=()
        echo "List of repos to update:"
        while IFS= read -r -u 3 repo ; do
          # Skip blank lines and commented lines.
          case "$repo" in ''|\#*) continue ;; esac
          if composer show -q -d "${full_path}/${repo}" -o "drupal/${module_name}"
          then
            repolist+=("$repo")
          fi

        done 3< repolist.txt

        break;;
      *) echo "invalid option ${REPLY}. Please choose a number."
    esac
  done

  echo "Repos to be updated: "
  printf '%s\n' "${repolist[*]}"
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

    check_php_version

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

    next_steps
    wait_to_continue

    echo "All done"

  done
}

merge_to_main () {

# Get type of update.
  echo "Choose type of update"
  options=("core" "contrib" "other")
  select update_type in "${options[@]}"; do
    echo "Opening pull requests."
    while IFS= read -r -u 3 repo ; do
      # Skip blank lines and commented lines.
      case "$repo" in ''|\#*) continue ;; esac
      echo "$repo"
      xdg-open "${remote_url}/${repo}/compare/main...develop"
    done 3< repolist.txt
    case $update_type in
      "core" | "contrib")
# Linux copy to both the selection buffer and clipboard with xclip.
        ( command -v xclip >/dev/null 2>&1 ) &&
          echo "[${ticket_number}] $update_type security update " | xclip -i -sel c -f |xclip -i -sel p &&
          echo "Ticket title copied to clipboard"
            break;;
      "other")
# What could be useful here?
            break;;
      *) echo "invalid option ${REPLY}. Please choose a number."
    esac
  done
}

create_tags () {

  while IFS= read -r -u 3 repo ; do
    # Skip blank lines and commented lines.
    case "$repo" in ''|\#*) continue ;; esac
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

# Linux open link in browser.
    xdg-open "${url}"
  done 3< repolist.txt

}

prod_deploy () {
  echo "Preparing prod deployments."
  while IFS= read -r -u 3 repo ; do
    # Skip blank lines and commented lines.
    case "$repo" in ''|\#*) continue ;; esac
    echo "$repo"
    # Match repo name to jenkins name.
    case $repo in
      "assessmentregistry8-site" )
        echo "Matched assessments"
        stack_name="assessmentregistry-stack"
        jenkins_name="Assessments"
        jenkins_other_name="assessments" ;;
      "common-design-site" )
        stack_name="common-design-stack"
        jenkins_name="Common Design"
        jenkins_other_name="ds-commondesign" ;;
      "cerf8" )
        stack_name="cerf-stack"
        jenkins_name="CERF"
        jenkins_other_name="cerf" ;;
      "docstore-site" )
        stack_name="docstore-stack"
        jenkins_name="Docstore"
        jenkins_other_name="docstore" ;;
      "gho-2022-site" )
        stack_name="gho-2022-stack"
        jenkins_name="GHO 2022"
        jenkins_other_name="gho-2022" ;;
      "gms-unocha-org" )
        stack_name="gms-stack"
        jenkins_name="GMS"
        jenkins_other_name="gms" ;;
      "iasc8" )
        stack_name="iasc-stack"
        jenkins_name="IASC"
        jenkins_other_name="iasc" ;;
      "odsg8-site" )
        stack_name="odsg-stack"
        jenkins_name="ODSG"
        jenkins_other_name="odsg" ;;
      "slt8-site" )
        stack_name="slt-stack"
        jenkins_name="SLT"
        jenkins_other_name="slt" ;;
      "sesame-site" )
        jenkins_name="Sesame"
        jenkins_other_name="sesame" ;;
      *) echo "Couldn't match ${repo} to a Jenkins property. Please check this."
    esac
    xdg-open "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-login-url/build"
    xdg-open "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-deploy/build"
    xdg-open "${jenkins_url}/view/${jenkins_name}/job/${jenkins_other_name}-prod-drush"
    echo "Opened jenkins links for $repo. To log in, and to deploy with drush page open just in case."
    # TODO open github stack pull request page too.
    echo "Deploy this to prod and continue when it's done"
    wait_to_continue
    echo "Opened pull request page for stack repo"
    xdg-open "${remote_url}/${stack_name}/pulls"
  done 3< repolist.txt
  echo "All done"
}

###################

###################

# Start here.
echo "Before starting, check BASEDIR is set in .env and the repos in repolist.txt are appropriate."
wait_to_continue

# Get ticket number.
echo "Enter ticket number:"
read -r ticket_number

# Choose stage.
# Get type of update.
echo "Choose stage of updates"
options=("create PR" "test on stage"  "merge to main" "create tags" "prod deploy")
select stage in "${options[@]}"; do
  case $stage in
    "create PR")
      create_pr

      break;;
    "test on stage")
      test_on_stage

      break;;
    "merge to main")
      merge_to_main

      break;;
    "create tags")
      create_tags

      break;;
    "prod deploy")
      prod_deploy

      break;;
    *) echo "invalid option ${REPLY}. Please choose a number."
  esac
done

