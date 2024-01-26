#!/bin/bash

# pull down latest changes to ~/.local/share/chezmoi/
chezmoi git pull

# get a list of files to update that don't have local changes
FILES=$(chezmoi status | awk '/^ / {print $2}')

echo $FILES

for f in $FILES; do
  echo chezmoi apply $f
done

chezmoi status
