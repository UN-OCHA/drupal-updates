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

  project_name=$(awk -F= '/PROJECT_NAME/ {print $2; exit 1}' "${full_path}/${repo}/local/.env")
  docker compose -f local/docker-compose.yml up -d
  docker exec -w /srv/www "${project_name}-site" composer install
  docker compose -f local/docker-compose.yml down

  cd - || exit

  # wait_to_continue

done;
