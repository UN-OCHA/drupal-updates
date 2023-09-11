#!/bin/bash

# Checks versions for php, solr and varnish.

# CSV should be uploaded to: https://docs.google.com/spreadsheets/d/1iMSJE5Lhk86m0lBWLE1R64QFGxZhFUfmconmmyu3XAU/edit?pli=1#gid=405205484

set -e

source ./common.sh

printf -v date '%(%Y-%m-%d)T' -1
echo "Last updated: ${date}." > data/infralist.csv
echo "Repo name,PHP version from dockerfile,Drupal core version,Solr version,Varnish version," >> data/infralist.csv

for repo in "${repolist[@]}"; do

  if [[ $repo = "drupal-starterkit" ]]
  then
    continue
  fi

  stack_name=$(jq -r '."'"$repo"'".stack_name' < ./repo-lookup.json)
  message=""
  message+=$repo
  message+=,
  message+=$(tac "${full_path}/${repo}/docker/Dockerfile" | grep k8s -m 1 | awk -F'/' '{print $NF}' | cut -d":" -f 2-)
  message+=,
  message+=$(grep -A1 '"name": "drupal/core",' "${full_path}/${repo}/composer.lock" | grep -v 'name' | cut -d":" -f 2)
  message+=$(grep 'image: solr' "${full_path}/${stack_name}/common.yml" | awk '{print $NF}')
  message+=,
  message+=$(grep 'unocha/varnish' "${full_path}/${stack_name}/common.yml" | awk -F'/' '{print $NF}')
  message+=,

  echo "$message" >> data/infralist.csv

done

echo "Infrastructure details output to ./data/infralist.csv"
spreadsheet_url="https://docs.google.com/spreadsheets/d/1iMSJE5Lhk86m0lBWLE1R64QFGxZhFUfmconmmyu3XAU/edit?pli=1#gid=405205484"
copy_to_clipboard "${spreadsheet_url}"

echo "Spreadsheet url ${spreadsheet_url} copied to the clipboard. Use File > Import to update the 'Infra versions' sheet."
