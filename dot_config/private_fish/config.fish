# Hide the fish greeting
set fish_greeting ""

fish_add_path -p ~/bin/noarch

if status is-interactive
  set -g myhostname   (string split "." $hostname)[1]
  set -g masterhost   chimera

  set -g debug ""
  if test $myhostname = "chimeraX"
      set -g debug "true"
  end

  set -x BC_ENV_ARGS  ~/.bc
  set -x EDITOR       vim
  set -x EZA_ARG      "-F"
  set -x EZAL_ARG     "-lh --sort=modified --time-style=long-iso"
  set -x LESS         -FXR
  set -x PAGER        less
  set -x SUDO_PROMPT  "Sudo Password: "

  set platform (uname)
  if test $platform = "Darwin"
    test $debug; and echo "OS: Darwin"
    set -g L_ARG  "-lhPO"
    set -g PS_ARG "auxww"
    source ~/.config/fish/conf.d/darwin.include

  else if test $platform = "Linux"
    test $debug; and echo "OS: Linux"
    set -g L_ARG  "-lh"
    set -g PS_ARG "-efww"
    source ~/.config/fish/conf.d/linux.include

  else
    test $debug; and echo "OS: Unknown"
  end

  #########################################################
  ### ALIASES

  abbr cp "cp -vi"
  abbr mv "mv -vi"

  # alias edpro "cme ~/.zshrc && cm re-add ~/.zshrc && exec zsh"
  alias egrep   "egrep --color=auto"
  alias grep    "grep --color=auto"
  alias l       "ls $L_ARG"
  alias ls      "ls -F"
  alias mkdir   "mkdir -p"
  alias more    "less -F"
  alias nano    "nano -zbx"
  alias mkroot  "sudo -E fish"
  alias pwgen   "bw generate -cp --words 2 --separator . --includeNumber | tee /dev/stderr | pbcopy"

  if type -q eza
    test debug; and echo "FOUND: eza"
    set COMMON  "--git --git-repos --group --group-directories-first --hyperlink"
    alias l   "eza $COMMON $EZAL_ARG"
    alias ls  "eza $COMMON $EZA_ARG"
  end

  #########################################################
  ## CHEZMOI
  alias cm     "chezmoi"
  alias cma    "chezmoi add"
  alias cmra   "chezmoi re-add"
  alias cme    "chezmoi edit"
  alias cmf    "chezmoi forget"
  alias cmg    "chezmoi git"
  alias cmst   "chezmoi status"
  alias cmu    "chezmoi update"
  alias cmi    "nano ~/.local/share/chezmoi/.chezmoiignore"
  alias cminit "sh -c \"(curl -fsLS get.chezmoi.io)\" -- init --apply adamshand --ssh --purge-binary"

  #########################################################
  ## DOCKER
  if type -q docker-compose
    alias dc "docker-compose"
  else
    alias dc "docker compose"
  end

  alias dl  "docker logs --follow --timestamps"
  alias dcl "dc logs --follow --since 1h --timestamps"

  function dcu
    dc up -d $argv; and dcl $argv
  end

  function dcd
    dc down $argv
  end

  function dcdu
    dcd; and dcu
  end

  function dv
    docker volume $argv
  end

  function dps
    docker ps --format "table {{.Names}}\t {{.Size}}\t {{.Status}}\t {{.Ports}}" | sed -e 's/0.0.0.0://g' -e 's/, :::[0-9]*->[0-9]*\/[tu][cd][p]//g'
  end

  function de -d "Exec a command in a container"
    set DCMD 'sh'
    set CONTAINER $argv[1]

    if set -q argv[2]
      set DCMD $argv[2]
    end

    # remove first and second arguments from $argv
    set -e argv[1..2]
    docker exec -it $CONTAINER $DCMD $argv
  end

  #########################################################
  ## GENERAL ALIASES & FUNCTIONS

  function flaunt -a search -d "Highlight matching text"
    egrep "($search|\$)"
  end

  function gcp
    git status -s; and echo -n "Commit message: "
    read -l MSG
    and git pull
    and git commit -a -m "gcp: $MSG"
    and git push
  end

  function mcd
      mkdir -p $argv[1]; and cd $argv[1]
  end

  function p -a string -d "Search for matching processes"
    if test $string
      ps $PS_ARG | grep -i "[^]]$string"
    else
      ps $PS_ARG | less
    end
  end

  function s -d "Use ssh.sh instead of ssh"
    if [ "$USER" = "adam" -a -x ssh.sh ]
        ssh.sh $argv
    else
      echo "# skipping ssh.sh (using ssh)"
      ssh $argv
    end
  end

  function showip
    # curl -4 ifconfig.co
    dig -4 +short myip.opendns.com a @resolver1.opendns.com
    dig -6 +short myip.opendns.com aaaa @resolver1.opendns.com
  end

  #########################################################
  ## PER-HOST OVERRIDES

  if test $myhostname = "chimera"
    test $debug; and echo "HOST: chimera"

  else if test $myhostname = "kauri"
    test $debug; and echo "HOST: kauri"

    set -x RESTIC_PASSWORD_FILE "/home/adam/etc/restic.txt"
    set -x RESTIC_REPOSITORY    "/vol/obelix/restic/"

  else if test $myhostname = "beam"; or test $myhostname = "ch-test1"
    test $debug; and echo "HOST: beam or ch-test1"
    functions -e mkroot
  end

end #is-interactive

### DISABLED
# function fish_prompt -d "Adam's standard prompt"
#   printf '\n%s%s%s\n[%s] %s@%s> ' (set_color $fish_color_cwd) (prompt_pwd) (set_color normal) (date +%I:%M%p) (whoami) (hostname | cut -d . -f 1)
# end

# vadedoku () { curl --silent "http://doku.adam.nz/vade?do=export_text" | egrep -v "(^ *$)" | sed -e 's/^ *//' | egrep -A 1 "^#.*(${1}).*$"; }
# function vade -a search -d "Search adam.nz/vade for matches"
#   links -dump -width 512 http://adam.nz/vade/ | egrep -v '^ *\$' | egrep --color=auto -A2 "^ # .*$search.*\$"
# end
