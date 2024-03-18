#!/bin/bash

# Steps through multiple repos making similar changes.

. ./common.sh

###################

# Start here.
echo "Before starting, check BASEDIR is set in .env and the repos listed above"
echo "are appropriate. If necessary, alter them in repolist.txt."
wait_to_continue

# Get ticket number.
echo "Enter ticket number:"
read -r ticket_number

create_pr "$ticket_number"
