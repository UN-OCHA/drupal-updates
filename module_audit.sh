#!/bin/bash

# Gets a list of drupal modules in csv form showing repos they're used in.
# TODO: make it work with other OSs.

source ./common.sh

requires "curl"
requires "xmllint"

echo ""
echo ""
echo "For updating the main spreadsheet, check that all D9+ modules are"
echo "uncommented in repolist.txt"
echo ""
echo ""
echo "NB - outdated assumes \`composer install\` has been run in each repo on"
echo "your local directories, use 'reset_branches.sh' to prepare all repos."

printf -v date '%(%Y-%m-%d)T' -1
first_line="Last updated: ${date}. Note we only check if a module is patched in the first repo it is added for."
options=("full" "outdated")
for type in "${options[@]}"; do
  if [[ "$type" == "full" ]]; then
    option=""
    fields="1,2"
    base_output_file="modulelist.csv"
  else
    option="-o"
    fields="1,2,3,4"
    base_output_file="outdatedlist.csv"
  fi
  vendors=( "drupal" "unocha" )
  for vendor in "${vendors[@]}" ; do
    spacer=""
    packages="${vendor}/*"
    output_file="data/${vendor}-${base_output_file}"
    echo "$first_line" > "$output_file"
    for repo in "${repolist[@]}" ; do
      spacer+=";"
      for module_details in $(composer show $option -d "${full_path}/${repo}" "${packages}" \
        | tr -s " " | cut -f $fields -d ' ' --output-delimiter=";" | cut -d '/' -f 2 ); do
        module_name=$(echo "$module_details" | cut -d ';' -f 1 )
        if grep "${module_name};" "$output_file"; then
          # Already in the list - add repo to line.
          awk -v pattern="${module_name};" -v repo="$repo" \
            '{if ($0 ~ pattern) print $0 repo; else print $0 }' "$output_file" \
            > tmpfile.txt && mv tmpfile.txt "$output_file"
        else
          count_formula="=COUNTA(INDIRECT(ADDRESS(ROW(),COLUMN()+1,4)):INDIRECT(ADDRESS(ROW(),COLUMN()+16,4)))"
          if [[ "$vendor" == "drupal" ]]; then
            # TODO: what information about patches could be useful?
            if grep "drupal/${module_name}\":" "${full_path}/${repo}/composer.patches.json"; then
              patched="Patched"
            else
              patched=" - "
            fi

            # Add new module with its maintenance status.
            url="https://updates.drupal.org/release-history/${module_name}/current"
            release_history=$(curl "$url")
            if [[ "$release_history" == *"<error>No release history"* ]]; then
              maintenance="No release history"
              covered="No release history"
            else
              maintenance=$(echo "$release_history" | xmllint --xpath "//project/terms/term[name='Maintenance status']/value/text()" -)
              covered=$(echo "$release_history" | xmllint --xpath "(//project/releases/release/security/text())[1]" - | sed "s/overed/overed#/" | cut -d'#' -f1 )
            fi
            echo "${module_details};${patched};${maintenance:=No maintenance status specified};${covered:=No security coverage specified};${count_formula}${spacer}${repo}" >> "$output_file"
          else
            echo "${module_details};${count_formula}${spacer}${repo}" >> "$output_file"
          fi
        fi
      done
      # Add a trailing semi-colon to each line.
      awk '{print $0 ";"}' "$output_file" > tmpfile.txt && mv tmpfile.txt "$output_file"
    done;

    LC_COLLATE=C sort "$output_file" > tmpfile.txt && mv tmpfile.txt "$output_file"
    echo "Results ready in $output_file."
  done;
done;


spreadsheet_url="https://docs.google.com/spreadsheets/d/1iMSJE5Lhk86m0lBWLE1R64QFGxZhFUfmconmmyu3XAU/edit"
copy_to_clipboard "${spreadsheet_url}"

echo "Spreadsheet url ${spreadsheet_url} copied to the clipboard. Use File > Import to update the relevant sheets."
echo ""
echo "Note that semi-colons are used to separate fields, you need to specify that as a custom separator when you upload each file."
