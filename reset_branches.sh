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

  update_branches || exit

  echo "- - -"
  echo " --- "
  echo "- - -"

  echo "Installing composer packages for $repo"
  echo "Current directory: $(pwd)"

  branches=( "main" "develop" )
  for branch in "${branches[@]}"; do
    project_name=$(awk -F= '/PROJECT_NAME/ {print $2; exit 1}' "${full_path}/${repo}/local/.env")
    docker compose -f local/docker-compose.yml up -d
    docker exec -w /srv/www "${project_name}-site" composer install
    docker compose -f local/docker-compose.yml down
    # docker run --rm -v "$(pwd):/srv/www" -w /srv/www "${docker_image}" composer install || exit
  done

  cd - || exit

  # wait_to_continue

done;
