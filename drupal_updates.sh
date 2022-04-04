#!/bin/bash

# Steps through the update process for drupal core or contrib modules.

remote_url="https://github.com/UN-OCHA"

# For when something needs doing that hasn't yet been automated.
wait_to_continue () {
  read -r -p "Hit enter when you're ready to continue" _
}

update_branches () {
  echo "updating main branch for $repo"
  git checkout main
  git pull
  echo "updating develop branch for $repo"
  git checkout develop
  git pull
  echo "branches for $repo updated"
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
  echo "output finished."
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
        break;;
      "no")
        echo "continuing"
        break;;
      *) echo "invalid option ${REPLY}. Please enter '1' for yes, '2' for no."
    esac
  done
}

set_new_branch () {
  echo "creating new branch in $repo"
  git checkout -b "$branch_name"

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
      echo "- - -"
      echo "- - -"
      composer -v update "drupal/core-*" --with-all-dependencies
      return;;
    "contrib")
      echo "- - -"
      echo "- - -"
      echo "updating ${module_name} for $repo"
      echo "- - -"
      echo "- - -"
      composer -v update "drupal/${module_name}"
      return;;
  esac

}

check_and_add_changes () {
  echo "- - -"
  echo "- - -"
  echo "in another tab/ window, 'cd ${full_path}/${repo}', check the changes are all as you'd expect and 'git add' them to the ${branch_name} branch of ${repo}"
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
      echo "commiting core update"
      echo "- - -"
      echo "- - -"
      new_version=$(composer show -f json drupal/core-recommended | jq .versions[] | sed s/\"//g)
      git commit -m "[${ticket_number}] update ${update_type} to ${new_version}"
      return;;
    "contrib")
      echo "- - -"
      echo "- - -"
      echo "commiting contrib update"
      echo "- - -"
      echo "- - -"
      new_version=$(composer show -f json "drupal/${module_name}" | jq .versions[] | sed s/\"//g)
      git commit -m "[${ticket_number}] update ${module_name} module to ${new_version}"
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

}

next_steps () {
  echo "- - -"
  echo "- - -"
  echo "Next steps:"
  echo "- - -"
  echo "- - -"
  echo "1. Create pull request at link above, or ${remote_url}/${repo}/pull/new/${branch_name}?body=[${ticket_number}] update ${module_name}"
  echo "2. Get a review from another developer"
  echo "3. Merge to develop"
  echo "4. Deploy the changes to the dev environment if there isn’t already an automatic deployment"
  echo "5. Ask the content squad for help testing key pages. There is a list of URLs in https://docs.google.com/spreadsheets/d/1GcqvK2PWuSZbLKEvQQNKtBc0xOx-GzTSbiIdd6HP5lI/edit#gid=0 If the list grows too large, maybe we consider breaking it into a separate spreadsheets per property. This spreadsheet currently lives in Digital Services > Documentation."
  echo "6. After testing from the content squad check ELK for any errors or warnings which might not have been immediately obvious (or otherwise visible) to the content squad."

}

# Get base directory
echo "Enter full path to where the repos are kept, without final slash:"
read -r full_path

# Get ticket number.
echo "Enter ticket number:"
read -r ticket_number

# Get type of update.
echo "Choose type of update"
options=("core" "contrib")
select update_type in "${options[@]}"; do
  case $update_type in
    "core")
      repolist=()
      echo "List of repos to update:"
      while IFS= read -r -u 3 repo ; do
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
echo "${repolist[*]}"
wait_to_continue

case $update_type in
  "core")
    branch_name="${ticket_number}-${update_type}-update";;
  "contrib")
    branch_name="${ticket_number}-${module_name}-module-update";;
esac

for repo in "${repolist[@]}" ; do

  echo "Processing repo $repo"

  echo "cd-ing to the $repo repo"
  cd "${full_path}/${repo}" || exit

  update_branches
  wait_to_continue

  need_a_feature_branch
  wait_to_continue

  set_new_branch
  wait_to_continue

  check_php_version

  composer_update
  wait_to_continue

  check_and_add_changes

  commit_changes
  wait_to_continue

  push_changes
  wait_to_continue

  next_steps
  wait_to_continue

  echo "All done"

done
