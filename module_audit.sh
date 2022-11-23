#!/bin/bash

# Gets a list of drupal modules in csv form showing repos they're used in.
# Requires curl and libxml2-utils.
# TODO: make it work with other OSs.

# CSVs should be uploaded to: https://docs.google.com/spreadsheets/d/1iMSJE5Lhk86m0lBWLE1R64QFGxZhFUfmconmmyu3XAU/edit#gid=335219432

set -e

function requires() {
    if ! command -v $1 &>/dev/null; then
        echo "Requires $1"
        exit 1
    fi
}

requires "composer"
requires "curl"
requires "xmllint"

# Get type of update.
echo "Choose whether to output a full list of modules or just the outdated ones"
echo "NB - outdated assumes \`composer install\` has been run in each repo on"
echo "your local directories, not just that the composer.lock is up to date."
options=("1 for full list" "2 for outdated ones only")
select type in "${options[@]}"; do
  case $type in
    "1 for full list")
      option=""
      fields="1,2"
      output_file="modulelist.txt"

      break;;
    "2 for outdated ones only")
      option="-o"
      fields="1,2,3,4"
      output_file="outdatedlist.txt"

      break;;
    *) echo "invalid option ${REPLY}. Please choose a number."
  esac
done

source ./.env
# remote_url=$REMOTE_URL
full_path=$BASEDIR

# For when something needs doing that hasn't yet been automated.
wait_to_continue () {
  read -r -p "Hit enter when you're ready to continue" _
}

true > $output_file
spacer=""
echo "Getting list of modules"
while IFS= read -r -u 3 repo ; do
  # Skip blank lines and commented lines.
  case "$repo" in ''|\#*) continue ;; esac
  spacer+=","
  for module_details in $(composer show $option -d "${full_path}/${repo}" drupal/* \
    | tr -s " " | cut -f $fields -d ' ' --output-delimiter="," | cut -d '/' -f 2 ); do
    module_name=$(echo "$module_details" | cut -d ',' -f 1 )
    if grep "${module_name}," $output_file; then
      # Already in the list - add repo to line.
      awk -v pattern="${module_name}," -v repo="$repo" \
        '{if ($0 ~ pattern) print $0 repo; else print $0 }' $output_file \
        > tmpfile.txt && mv tmpfile.txt $output_file
    else
      # TODO: check if the module is in composer.patches.json.

      # Add new module with its maintenance status.
      url="https://updates.drupal.org/release-history/${module_name}/current"
      release_history=$(curl "$url")
      if [[ "$release_history" == *"<error>No release history"* ]]; then
        maintenance="No release history"
        covered="No release history"
      else
        maintenance=$(echo "$release_history" | xmllint --xpath "//project/terms/term[name='Maintenance status']/value/text()" -)
        covered=$(echo "$release_history" | xmllint --xpath "(//project/releases/release/security/text())[1]" -)
      fi
      echo "${module_details},${maintenance:=No maintenance status specified},${covered:=No security coverage specified}${spacer}${repo}" >> $output_file
    fi
  done
  # Add a trailing comma to each line.
  awk '{print $0 ","}' $output_file > tmpfile.txt && mv tmpfile.txt $output_file

done 3< repolist.txt

sort $output_file > tmpfile.txt && mv tmpfile.txt $output_file

echo "Results are now ready in $output_file"
