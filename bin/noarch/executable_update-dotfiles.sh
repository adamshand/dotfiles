#!/bin/bash

# Pull any changes from GitHub and apply them to the local system excluding files that have local changes.

# Written by Adam Shand <adam@shand.net> 29 Jan 2024
# - 2 Feb 2024: Remote pulls via HTTP so SSH keys aren't required

PATH="/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin:${HOME}/bin/noarch"

if [[ "$OSTYPE" = "linux-gnu" || "$OSTYPE" = "linux" ]]; then
  PATH="${PATH}:${HOME}/bin/linux"
elif [[ "$OSTYPE" = "darwin"* ]]; then
  PATH="${PATH}:${HOME}/bin/darwin"
else
  echo "Unknown OS: $OSTYPE" >&2
  exit 1
fi

if ! chezmoi git remote -v | grep -q chezmoi ; then
  # important because ssh keys aren't available on remote systems
  echo "## Adding HTTP git remote" >&2
  chezmoi git remote add chezmoi https://github.com/adamshand/dotfiles.git
fi

echo "## Pulling latest from GitHub"
if ! chezmoi git pull chezmoi main; then
  echo "Failed to pull changes from GitHub" >&2
  exit 1
fi

# get a list of files to update that don't have local changes
FILES=$(chezmoi status | awk '/^ / {print $2}')

echo -e "\n## Updating …"
if [ -n "$FILES" ]; then
  for f in $FILES; do
    echo "  -> $f"
    chezmoi apply ~/${f}
  done
else
  echo "No files to update"
fi

STATUS=$(chezmoi status)
if [ "$1" = "notify" ]; then
  echo -e "\n## Files with local changes that need commiting"
  chezmoi status >&2
fi
