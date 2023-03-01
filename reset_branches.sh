#!/bin/bash

# Cycles through the repos in repolist.txt, checking out and pulling the
# main and develop branches, then running composer install for the latter.

source ./common.sh

wait_to_continue

for repo in "${repolist[@]}" ; do

  php_version=$(jq -r '."'"$repo"'".php_version' < ./repo-lookup.json)

  echo "- - -"
  echo " --- "
  echo "- - -"

  echo "Processing repo $repo"

  echo "cd-ing to the $repo repo"
  cd "${full_path}/${repo}" || exit

  update_branches

  echo "- - -"
  echo " --- "
  echo "- - -"

  echo "Installing composer packages for $repo"

  docker run --rm -u 1000 -v "$(pwd):/srv/www" -w /srv/www "public.ecr.aws/unocha/unified-builder:${php_version}-stable" composer install

  cd - || exit

  wait_to_continue

done;
