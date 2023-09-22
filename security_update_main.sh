#!/bin/bash

. ./common.sh

# Drupal core - Critical - Cache poisoning - SA-CORE-2023-006

# Get repolist from repolist.txt
repolist=()
echo "List of repos to reset:"
while IFS= read -r -u 3 repo ; do
  # Skip blank lines and commented lines.
  case "$repo" in ''|\#*) continue ;; esac
  echo "$repo"
  repolist+=("$repo")
done 3< repolist.txt

ticket_number="$1"
branch_name="${ticket_number}-security-update"

read -r -p "Enter a one-line commit message, including the standard commit type (without the ticket number):" commit_message
commit_message="${commit_message}

Refs: #${ticket_number}"

for repo in "${repolist[@]}" ; do
    echo "* * *"
    echo "Processing repo $repo"
    echo "* * *"

    echo "cd-ing to the $repo repo"
    if test -d "${full_path}/${repo}"; then
        cd "${full_path}/${repo}" || exit
    else
        cd "${full_path}" || exit
        git clone git@github.com:UN-OCHA/${repo}.git
        cd "${full_path}/${repo}" || exit
    fi

    git checkout main
    git reset --hard HEAD
    git pull

    if [ `git branch --list ${branch_name}` ]; then
        echo "Branch name ${branch_name} already exists."
        wait_to_continue
        continue
    fi

    git checkout -b ${branch_name}
    docker run --rm --interactive --tty --volume .:/app composer install --ignore-platform-req=ext-gd
    docker run --rm --interactive --tty --volume .:/app composer update --ignore-platform-req=ext-gd
    git status
    echo "Ready to add composer.lock?"

    echo "Do we need to commit?"
    options=("yes" "no")
    select answer in "${options[@]}"; do
        case $answer in
        "yes")
            git add composer.lock
            git commit -m "${commit_message}"
            git push origin ${branch_name}

            pr_url=${remote_url}/${repo}/compare/main...${branch_name}?expand=1
            echo "Opening url for PR: $pr_url"
            copy_to_clipboard "${pr_url}"
            wait_to_continue

            break;;
        "no")
            echo "continuing"
            break;;
        *) echo "invalid option ${REPLY}. Please enter '1' for yes, '2' for no."
        esac

    done
done
