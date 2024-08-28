#!/bin/bash

# Gets a list of drupal modules in csv form showing repos they're used in.

source ./common.sh

requires "curl"
requires "xmllint"

echo ""
echo ""
echo "For updating the main spreadsheet, check that all Drupal repositories are"
echo "uncommented in repolist.txt"
echo ""
echo ""
echo "NB - this assumes both develop and main are up-to-date"
echo "use 'reset_branches.sh' to prepare all repos."

wait_to_continue

# Prepare header.
printf -v date '%(%Y-%m-%d)T' -1
header_row="Last updated: ${date}. ; Maintenance status ; Security coverage ; Count "
for repo in "${repolist[@]}"; do
  header_row="$header_row ; $repo"
done
options=("full" "outdated")

for type in "${options[@]}"; do
  if [[ "$type" == "full" ]]; then
    # Option for composer.
    option=""
    fields="1,2"
    base_output_file="modulelist.csv"
  else
    option="-o"
    fields="1,2,3,4"
    base_output_file="outdatedlist.csv"
  fi
  vendors=("drupal" "unocha")
  for vendor in "${vendors[@]}"; do
    spacer=""
    packages="${vendor}/*"
    output_file="$(pwd)/data/${vendor}-${base_output_file}"
    echo "$header_row" >"$output_file"

    for repo in "${repolist[@]}"; do
      echo "* * *"
      echo "Processing repo $repo"
      echo "* * *"

      echo "cd-ing to the $repo repo"
      cd "${full_path}/${repo}" || exit

      spacer+=";"
      for module_details in $($COMPOSER show --locked --direct $option "${packages}" |
        tr -s " " | cut -f $fields -d ' ' --output-delimiter=";" | cut -d '/' -f 2); do
        module_name=$(echo "$module_details" | cut -d ';' -f 1)
        module_version=$(echo "$module_details" | cut -d ';' -f 2)
        # Extra information.
        extra=""
        # Check if this module is the same as on main
        cd "${full_path}/${repo}" || exit
        if [ -n "$(git diff -w --word-diff -U1 main composer.lock)" ]; then
          main_version=$(git diff -w --word-diff -U1 main composer.lock | sed -n "/\"name\": \"drupal\/${module_name}\",/{n;p}" | sed -e 's/.*-"\(.*\)",-.*/\1/')
          if [ -n "$main_version" ]; then
            extra="$extra - Main on ${main_version}"
          fi
        fi
        # git diff -w -U1 main composer.lock | tr '\n' ' ' >main.diff
        # if grep "drupal/${module_name}\",.*-.*\"version" main.diff; then
        #   extra="$extra - Not as Main"
        # fi
        # rm main.diff
        cd - || exit
        # Add whether module is patched or pinned.
        if grep "drupal/${module_name}\":" "${full_path}/${repo}/composer.patches.json"; then
          extra="$extra - Patched"
        fi
        if grep "drupal/${module_name}\": \"[[:digit:]]" "${full_path}/${repo}/composer.json"; then
          extra="$extra - Pinned"
        fi

        if grep "^${module_name};" "$output_file"; then
          # Already in the list - add repo to line.
          awk -v pattern="^${module_name};" -v repo="$module_version $extra" \
            '{if ($0 ~ pattern) print $0 repo; else print $0 }' "$output_file" \
            >tmpfile.txt && mv tmpfile.txt "$output_file"
        else
          # Not yet in the list, add another line and relevant information.
          count_formula="=COUNTA(INDIRECT(ADDRESS(ROW(),COLUMN()+1,4)):INDIRECT(ADDRESS(ROW(),COLUMN()+16,4)))"
          if [[ "$vendor" == "drupal" ]]; then
            # Add new module with its maintenance status.
            url="https://updates.drupal.org/release-history/${module_name}/current"
            release_history=$(curl "$url")
            if [[ "$release_history" == *"<error>No release history"* ]]; then
              maintenance="No release history"
              covered="No release history"
            else
              maintenance=$(echo "$release_history" | xmllint --xpath "//project/terms/term[name='Maintenance status']/value/text()" -)
              covered=$(echo "$release_history" | xmllint --xpath "(//project/releases/release/security/text())[1]" - | sed "s/overed/overed#/" | cut -d'#' -f1)
            fi
            echo "${module_name};${maintenance:=No maintenance status specified};${covered:=No security coverage specified};${count_formula}${spacer}$module_version $extra" >>"$output_file"
          else
            echo "${module_name};;;${count_formula}${spacer}$module_version $extra" >>"$output_file"
          fi
        fi
      done
      # Add a trailing semi-colon to each line.
      awk '{print $0 ";"}' "$output_file" >tmpfile.txt && mv tmpfile.txt "$output_file"
      cd - || exit
    done

    LC_COLLATE=C sort "$output_file" >tmpfile.txt && mv tmpfile.txt "$output_file"
    echo "Results ready in $output_file."
  done
done

spreadsheet_url="https://unitednations.sharepoint.com/:x:/r/sites/OCHAIMB/Digital%20Services%20Section/06_Projects/Developer%20documentation%20and%20standards/Drupal%20sites%20package%20version%20overview.xlsx?d=w95705de2bf904ed4816e200cdcc2b1b8&csf=1&web=1&e=6XV9K0"
copy_to_clipboard "${spreadsheet_url}"

echo "Spreadsheet url ${spreadsheet_url} copied to the clipboard."
echo "Best way to update the spreadsheet so far is to open each csv file in a"
echo "sheet locally, then copy and paste to the relevant sheet."
