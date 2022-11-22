#!/bin/bash

# Gets a list of drupal modules in csv form showing repos they're used in.
# Requires curl and libxml2-utils.
# TODO: make it work with other OSs.

# CSVs should be uploaded to: https://docs.google.com/spreadsheets/d/1iMSJE5Lhk86m0lBWLE1R64QFGxZhFUfmconmmyu3XAU/edit#gid=335219432

# Get type of update.
echo "Choose whether to output a full list of modules or just the outdated ones"
echo "NB - outdated assumes \`composer install\` has been run in each repo on"
echo "your local directories, not just that the composer.lock is up to date."
options=("1 for full list" "2 for outdated ones only")
select type in "${options[@]}"; do
  case $type in
    "1 for full list")
      option=""
      output_file="modulelist.txt"

      break;;
    "2 for outdated ones only")
      option="-o"
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
  for module in $(composer show $option -d "${full_path}/${repo}" -N drupal/* \
    | tr -d " " | cut -f 2 -d '/'); do
    if grep "${module}," $output_file; then
      # Already in the list - add repo to line.
      awk -v pattern="${module}," -v repo="$repo" \
        '{if ($0 ~ pattern) print $0 repo; else print $0 }' $output_file \
        > tmpfile.txt && mv tmpfile.txt $output_file
    else
      # TODO: check if the module is in composer.patches.json. For now, just
      # the first time it's included.

      # Add new module with its maintenance status.
      url="https://updates.drupal.org/release-history/${module}/current"
      status=$(curl "$url" | xmllint --xpath "//project/terms/term[name='Maintenance status']/value/text()" -)
      echo "${module},${status:=Not specified},${spacer}${repo}" >> $output_file
    fi
  done
  # Add a trailing comma to each line.
  awk '{print $0 ","}' $output_file > tmpfile.txt && mv tmpfile.txt $output_file

done 3< repolist.txt

sort $output_file > tmpfile.txt && mv tmpfile.txt $output_file

echo "Results are now ready in $output_file"
