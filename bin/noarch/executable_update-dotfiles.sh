#!/bin/bash

echo "## Pulling latest from GitHub"
chezmoi git pull

# get a list of files to update that don't have local changes
FILES=$(chezmoi status | awk '/^ / {print $2}')

echo -e "\n## Updating files without local changes"

for f in $FILES; do
  echo "... $f"
  chezmoi apply ~/${f}
done

echo -e "\n## Files with local changes that need adding"
chezmoi status 1>&2
