#!/bin/bash

# Cycles through the repos in repolist.txt, checking out and pulling the
# main and develop branches, then running composer install for the latter.

source ./common.sh

wait_to_continue

for repo in "${repolist[@]}" ; do

  docker_image=$(awk '/FROM/ {print $2; exit 1}' "${full_path}/${repo}/docker/Dockerfile")

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

  # Get the docker image from docker/Dockerfile
  docker run --rm -u 1000 -v "$(pwd):/srv/www" -w /srv/www "${docker_image}" composer install

  cd - || exit

  # wait_to_continue

done;
