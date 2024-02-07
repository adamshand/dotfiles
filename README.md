dotfiles and scripts managed by [chezmoi](https://www.chezmoi.io/).

A there are a few scripts which might be of particular interest.

- [bin/darwin/wifi-toggle.sh](https://github.com/adamshand/dotfiles/blob/main/bin/darwin/executable_wifi-toggle.sh) - automatically toggles macOS wifi on and off based on whether the ethernet port is active.
- [bin/noarch/backup-docker-sqlite.sh](https://github.com/adamshand/dotfiles/blob/main/bin/noarch/executable_backup-docker-sqlite.sh) - finds all SQLite databases in the top two levels of every Docker volume and backs them up to `/var/backups/db`.
- [bin/noarch/ssh.sh](https://github.com/adamshand/dotfiles/blob/main/bin/noarch/executable_ssh.sh) - a wrapper around ssh which allows you to open multiple ssh sessions as tabs in your terminal app, also allows you start ssh session in a particular directory (eg. `ssh.sh serverA:/tmp serverB serverC:/etc`).  Supports Apple Termina, iTerm, WezTerm, Gnome Terminal, & Guake. 
- [bin/noarch/sshfp2cf.sh](https://github.com/adamshand/dotfiles/blob/main/bin/noarch/private_executable_sshfp2cf.sh) - automatically add SSHFP DNS records to Cloudflare ([details](https://adam.nz/sshfp-cloudflare)).
