#!/usr/bin/env bash

help() {
  echo "'$0' options: [(-h|--help)]"
}

try_confirm() {
  declare message="$1"
  declare answer
  read -r -n 1 -p "$message [y/n]: " answer
  echo

  if [[ ! $answer =~ [yn] ]]; then
    answer=n
  fi

  if [[ $answer == n ]]; then
    return 1
  fi

  return 0
}

declare IGNORE_FILE="$HOME/.config/fix_pages/ignore"

try_create_ignore_file() {
  declare directory="$(dirname "$IGNORE_FILE")"
  if [[ ! -d $directory ]]; then
    mkdir --parents "$directory" || {
      echo "Failed: to create ignore file." >&2
      exit 1
    }
    touch "$IGNORE_FILE"
  fi
}

clear_ignore_file() {
  echo > "$IGNORE_FILE" || echo "Failed: to clear ignore file." >&2
}

is_ignored() {
  declare page="$1"
  if grep -- "$page" "$IGNORE_FILE" > /dev/null; then
    return 0;
  fi
  return 1
}

ignore() {
  declare page="$1"
  echo "$page" >> "$IGNORE_FILE"
}

# Use `stdin`, `stdout`, `stderr` keywords.
fix_io_stream_names_action() {
  for directory in *; do
    for page in "$directory"/*.md; do
      declare stream="^- (.*[^\`])([\"']?)std(in|out|err)\2"
      if grep --ignore-case --extended-regexp -- "$stream" "$page" > /dev/null; then
        echo -n "'$page' broken: stream name is incorrectly quoted, fixing... "
        if sed --in-place --regexp-extended "s/$stream/- \1\`std\L\3\E\`/gi" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi
    done
  done
}

# Use `{{path/to/file}}` generic placeholders.
fix_generic_file_placeholders_action() {
  for directory in *; do
    for page in "$directory"/*.md; do
      declare with_extension='\{\{[^/ {]*file[^/ {]*([[:digit:]]*)\.([^ ]+)\}\}'
      if grep --extended-regexp "$with_extension" "$page" > /dev/null; then
        echo -n "'$page' broken: path placeholders (with extension) with invalid content, fixing... "
        if sed --in-place --regexp-extended "s/$with_extension/{{path\/to\/file\1.\2}}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare without_extension='\{\{[^/ {]*file[^/ {]*([[:digit:]]*)\}\}'
      if grep --extended-regexp "$without_extension" "$page" > /dev/null; then
        echo -n "'$page' broken: path placeholders with invalid content, fixing... "
        if sed --in-place --regexp-extended "s/$without_extension/{{path\/to\/file\1}}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi
    done
  done
}

# Use `{{path/to/directory}}` generic placeholders.
fix_generic_directory_placeholders_action() {
  for directory in *; do
    for page in "$directory"/*.md; do
      declare without_extension='\{\{[^/ {]*dir(ectory)?[^/ {]*([[:digit:]]*)\}\}'
      if grep --extended-regexp "$without_extension" "$page" > /dev/null; then
        echo -n "'$page' broken: path placeholders with invalid content, fixing... "
        if sed --in-place --regexp-extended "s/$without_extension/{{path\/to\/directory\2}}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi
    done
  done
}

# Use `{{path/to/source}}`, `{{path/to/executable}}` placeholders.
fix_file_placeholders_action() {
  for directory in *; do
    for page in "$directory"/*.md; do
      if is_ignored "$page"; then
        echo "'$page' ignored: to stop ignoring it remove it from '$IGNORE_FILE'."
        continue
      fi
      
      declare with_extension='\{\{[^/ {]*(source|executable)[^/ {]*([[:digit:]]*)\.([^ ]+)\}\}'
      if grep --extended-regexp "$with_extension" "$page" > /dev/null; then
        echo "'$page' possible broken: 'source' or 'executable' path without extension is invalid..."
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi

        if sed --in-place --regexp-extended "s/$with_extension/{{path\/to\/\1\2.\3}}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare without_extension='\{\{[^/ {]*(source|executable)[^/ {]*([[:digit:]]*)\}\}'
      if grep --extended-regexp "$without_extension" "$page" > /dev/null; then
        echo "'$page' possible broken: 'source' or 'executable' path with extension is invalid..."
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi

        if sed --in-place --regexp-extended "s/$without_extension/{{path\/to\/\1\2}}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi
    done
  done
}

# Remove quotes for generic file placeholders.
# Assumption: placeholder contents are already fixed.
fix_generic_file_placeholder_quoting_action() {
  for directory in *; do
    for page in "$directory"/*.md; do
      declare with_extension="([\"'])(\{\{path\/to\/file[[:digit:]]*\.[^ ]+\}\})\1"
      if grep --extended-regexp "$with_extension" "$page" > /dev/null; then
        echo -n "'$page' broken: file placeholder (with extension) quoting is broken, fixing... "
        if sed --in-place --regexp-extended "s/$with_extension/\2/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare without_extension="([\"'])(\{\{path\/to\/file[[:digit:]]*\}\})\1"
      if grep --extended-regexp "$without_extension" "$page" > /dev/null; then
        echo -n "'$page' broken: file placeholder quoting is broken, fixing... "
        if sed --in-place --regexp-extended "s/$without_extension/\2/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi
    done
  done
}

# Remove quotes for generic directory placeholders.
# Assumption: placeholder contents are already fixed.
fix_generic_directory_placeholder_quoting_action() {
  for directory in *; do
    for page in "$directory"/*.md; do
      declare without_extension="([\"'])(\{\{path\/to\/directory[[:digit:]]*\}\})\1"
      if grep --extended-regexp "$without_extension" "$page" > /dev/null; then
        echo -n "'$page' broken: directory placeholder quoting is wrong, fixing... "
        if sed --in-place --regexp-extended "s/$without_extension/\2/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi
    done
  done
}

# Use `{{placeholder1 placeholder2 ...}}` syntax.
# Asks confirmation as some commands don't require such change: it may break there syntax.
# Warning: placeholder must not contain spaces to be recignized valid for substitution.
fix_placeholder_ellipsis_action() {
  for directory in *; do
    for page in "$directory"/*.md; do
      if is_ignored "$page"; then
        echo "'$page' ignored: to stop ignoring it remove it from '$IGNORE_FILE'."
        continue
      fi

      declare placeholder_with_plural_word_and_extension="\{\{(.+)\(s\)\.([^ ]+)\}\}"
      if grep --extended-regexp -- "$placeholder_with_plural_word_and_extension" "$page" > /dev/null; then
        echo "'$page' possibly broken in placeholder with extension: '(s)' is invalid: use '...'"
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi
        
        if sed --in-place --regexp-extended "s/$placeholder_with_plural_word_and_extension/\{\{\11.\2 \12.\2 ...\}\}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare placeholder_with_plural_word_and_without_extension="\{\{(.+)\(s\)\}\}"
      if grep --extended-regexp -- "$placeholder_with_plural_word_and_without_extension" "$page" > /dev/null; then
        echo "'$page' possibly broken in placeholder without extension: '(s)' is invalid: use '...'"
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi
        
        if sed --in-place --regexp-extended "s/$placeholder_with_plural_word_and_without_extension/\{\{\11 \12 ...\}\}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare placeholder_with_brace_expansion_and_extension="\{\{([^ {}]+)\{[[:digit:]]+(,[[:digit:]]+)*\}\.([^ ]+)\}\}"
      if grep --extended-regexp -- "$placeholder_with_brace_expansion_and_extension" "$page" > /dev/null; then
        echo "'$page' possibly broken in placeholder with extension: brace expansion is invalid: use '...'"
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi
        
        if sed --in-place --regexp-extended "s/$placeholder_with_brace_expansion_and_extension/\{\{\11.\3 \12.\3 ...\}\}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare placeholder_with_brace_expansion_and_without_extension="\{\{([^ {}]+)\{[[:digit:]]+(,[[:digit:]]+)*\}\}\}"
      if grep --extended-regexp -- "$placeholder_with_brace_expansion_and_without_extension" "$page" > /dev/null; then
        echo "'$page' possibly broken in placeholder without extension: brace expansion is invalid: use '...'"
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi
        
        if sed --in-place --regexp-extended "s/$placeholder_with_brace_expansion_and_without_extension/\{\{\11 \12 ...\}\}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare consecutive_placeholder_pair_with_numbering_with_extension="\{\{(.+)1\.([^ ]+)\}\} +\{\{\12\.\2\}\}( +\{\{\1[[:digit:]]+\.\2\}\})*"
      if grep --extended-regexp -- "$consecutive_placeholder_pair_with_numbering_with_extension" "$page" > /dev/null; then
        echo "'$page' possibly broken in placeholder with extension: repeating placeholders for 0..more values is invalid: use '...'"
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi
        
        if sed --in-place --regexp-extended "s/$consecutive_placeholder_pair_with_numbering_with_extension/\{\{\11.\2 \12.\2 ...\}\}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare consecutive_placeholder_pair_with_numbering_without_extension="\{\{(.+)1\}\} +\{\{\12\}\}( +\{\{\1[[:digit:]]+\}\})*"
      if grep --extended-regexp -- "$consecutive_placeholder_pair_with_numbering_without_extension" "$page" > /dev/null; then
        echo "'$page' possibly broken in placeholder without extension: repeating placeholders for 0..more values is invalid: use '...'"
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi
        
        if sed --in-place --regexp-extended "s/$consecutive_placeholder_pair_with_numbering_without_extension/\{\{\11 \12 ...\}\}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare consecutive_placeholder_pair_with_broken_numbering_with_extension="\{\{(.+)\.([^ ]+)\}\} +\{\{\12\.\2\}\}( +\{\{\1[[:digit:]]+\.\2\}\})*"
      if grep --extended-regexp -- "$consecutive_placeholder_pair_with_broken_numbering_with_extension" "$page" > /dev/null; then
        echo "'$page' possibly broken in placeholder with extension: repeating placeholders for 0..more values is invalid: use '...'"
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi
        
        if sed --in-place --regexp-extended "s/$consecutive_placeholder_pair_with_broken_numbering_with_extension/\{\{\11.\2 \12.\2 ...\}\}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi

      declare consecutive_placeholder_pair_with_broken_numbering_without_extension="\{\{(.+)\}\} +\{\{\12\}\}( +\{\{\1[[:digit:]]+\}\})*"
      if grep --extended-regexp -- "$consecutive_placeholder_pair_with_broken_numbering_without_extension" "$page" > /dev/null; then
        echo "'$page' possibly broken in placeholder without extension: repeating placeholders for 0..more values is invalid: use '...'"
        code "$page"

        if ! try_confirm "Do you want to fix '$page'?"; then
          ignore "$page"
          continue
        fi
        
        if sed --in-place --regexp-extended "s/$consecutive_placeholder_pair_with_broken_numbering_without_extension/\{\{\11 \12 ...\}\}/g" "$page"; then
          echo "Done."
        else
          echo "Failed: check whether file can be overridden."
        fi
      fi
    done
  done
}

declare -i HELP_INFO=1
declare -i WRONG_DIRECTORY_ERROR=1

for option in "$@"; do
  case "$option" in
    -h|--help)
      help
      exit $HELP_INFO
    ;;
  esac
done

shopt -s globstar
cd ../pages || {
  echo "Script must be run from the directory where '../pages' subdirectory exists." >&2
  exit $WRONG_DIRECTORY_ERROR
}

# Actions without confirmation
echo "Fixing stream names in code descriptions..."
fix_io_stream_names_action
echo "Fixing generic file placeholders in code examples..."
fix_generic_file_placeholders_action
echo "Fixing generic directory placeholders in code examples..."
fix_generic_directory_placeholders_action
echo "Fixing generic file placeholder quoting in code examples..."
fix_generic_file_placeholder_quoting_action
echo "Fixing generic directory placeholder quoting in code examples..."
fix_generic_directory_placeholder_quoting_action
echo "Fixing file placeholders in code examples..."
fix_file_placeholders_action

# Actions with confirmation and ignore file
echo "Trying to initialize new '$IGNORE_FILE'..."
try_create_ignore_file
echo "Fixing ellipsis usage in code descriptions..."
fix_placeholder_ellipsis_action