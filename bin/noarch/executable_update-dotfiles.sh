#!/bin/bash

# Written by Adam Shand <adam@shand.net> 29 Jan 2024
# Pull any changes from GitHub and apply them to the local system excluding files that have local changes.

PATH=/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin:${HOME}/bin/noarch

if [[ "$OSTYPE" = "linux-gnu" || "$OSTYPE" = "linux" ]]; then
  PATH=${PATH}:${HOME}/bin/linux
elif [[ "$OSTYPE" = "darwin"* ]]; then
  PATH=${PATH}:${HOME}/bin/darwin
else
  echo "Unknown OS: $OSTYPE" 1>&2
  exit 1
fi

if ! chezmoi git remote -v | grep -q chezmoi ; then
  # important because ssh keys aren't available on remote systems
  echo "## Adding HTTP git remote" 1>&2
  chezmoi git remote add chezmoi https://github.com/adamshand/dotfiles.git
fi

echo "## Pulling latest from GitHub"
chezmoi git pull chezmoi main

# get a list of files to update that don't have local changes
FILES=$(chezmoi status | awk '/^ / {print $2}')

echo -e "\n## Updating files without local changes"
if [ "$FILES" ]; then
  for f in $FILES; do
    echo "... $f"
    chezmoi apply ~/${f}
  done
else
  echo "No files to update"
fi

if [ "$1" = "notify" ]; then
  echo -e "\n## Files with local changes that need commiting"
  chezmoi status 1>&2
fi
