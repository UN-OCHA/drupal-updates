#!/bin/bash

# Helper script to open a batch of urls.
# Expects the urls to be one-per-line in a separate file.
# Skips blank and commented (#) lines.
# Opens them on linux.
# That's it.

# Take filename from argument if there is one.
if [ "$1" ]; then
  filename="$1"
else
  # If no argument given, ask for a filename.
  # Show files in this directory including 'test' in their name.
  echo "Files to choose from:"
  find ./test_urls/ -name "*.txt" | cut -f 3 -d '/'

  # Get filename.
  echo "Enter file name (and path if it's not in this directory):"
  read -r filename
  filename="test_urls/$filename"
fi

while IFS= read -r -u 3 url ; do
  # Skip blank lines and commented lines.
  case "$url" in ''|\#*) continue ;; esac
  xdg-open "$url"
  echo "Opening $url"
done 3< "$filename"
