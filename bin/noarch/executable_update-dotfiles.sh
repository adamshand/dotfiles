#!/bin/bash
# Pull any changes from GitHub and apply them to the local system excluding files that have local changes.
# Written by Adam Shand <adam@shand.net> 29 Jan 2024
# - 2 Feb 2024: Automatically add HTTP remote if required

PATH="/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin:${HOME}/bin/noarch"
# assumes repo is publically accessible via HTTP
HTTP_REMOTE="https://github.com/adamshand/dotfiles.git"

if [[ "$OSTYPE" = "linux-gnu" || "$OSTYPE" = "linux" ]]; then
  PATH="${PATH}:${HOME}/bin/linux"
elif [[ "$OSTYPE" = "darwin"* ]]; then
  PATH="${PATH}:${HOME}/bin/darwin"
else
  echo "error: unknown OS: $OSTYPE" >&2
  exit 1
fi

if ! command -v chezmoi > /dev/null 2>&1; then
  echo "error: chezmoi not found" >&2
  exit 1
fi

if ! chezmoi git remote -v | grep -q chezmoi ; then
  # important because ssh keys aren't available on remote systems
  echo "## Adding HTTP git remote" >&2
  chezmoi git remote add chezmoi "${HTTP_REMOTE}" || exit 1
fi

echo "## Pulling from GitHub"
if ! chezmoi git -- pull --quiet chezmoi main; then
  echo "error: failed to pull changes from GitHub" >&2
  exit 1
fi

# get a list of files to update that don't have local changes
FILES=$(chezmoi status | awk '/^ / {print $2}')

echo -e "\n## Local files to update"
if [ -n "$FILES" ]; then
  for f in $FILES; do
    echo "$f"
    chezmoi "apply ~/${f}"
  done
else
  echo "none found"
fi

STATUS=$(chezmoi status)
if [ -n "$STATUS" ]; then
  if [ "$1" = "notify" ]; then
    echo -e "\n## Files with local changes" >&2
    echo "${STATUS}" >&2
  else
  echo -e "\n## Files with local changes"
    echo "${STATUS}"
  fi
else
  echo -e "\n## No files with local changes"
fi
