#!/bin/bash

# Wrapper to launch SSH in a new tab with correct variables for iTerm.app
# Written by Adam Shand <adam@shand.net> on 27 April 2004
# 20110305 added -4 -C -c blowfish-cbc by recommendation to speed up things
# 20110306 added exec (doh, obvious!) and autossh logic
# 20190404 open ssh in new iTerm tab
# 20200423 support for new tabs in gnome-terminal and guake
# 20200512 ssh to multiple hosts at once
# 20200513 add support for an ssh jumphost
# 20230409 add support for opening in new WezTerm tab

## USAGE
# add alias to bash/zsh start up scripts, eg: alias s='~/bin/ssh.sh'
# or call manually as ssh.sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/opt/homebrew/bin
#SSH_OPTIONS="-A -4C -e ^"
SSH_OPTIONS="-A"

unset DEBUG
#DEBUG="true"; #set -x

usage() {
  echo "ssh to one (or more) hosts in a new terminal tab"
  echo "usage: ssh.sh [-djv] [-J jumphost] <hostname> [hostname ...]"
  echo "      -d; disables opening in new tab"
  echo "      -h; usage"
  echo "      -j; uses $SSH_JUMPHOST"
  echo "      -J <jumphost>"
  echo "      -v; puts ssh in verbose mode"
  exit
}

if [ -z "$1" ]; then
  usage
fi

if [ "${OSTYPE:0:6}" == "darwin" ]; then
  SSH_OPTIONS="$SSH_OPTIONS -o UseKeychain=yes"
  # supports both iTerm.app and Apple_Terminal
  APP="${TERM_PROGRAM}"
elif [ "${OSTYPE:0:5}" == "linux" ]; then
  SSH_OPTIONS="$SSH_OPTIONS -Y"
  # export DISPLAY=":0"
  if [ -n "${GIO_LAUNCHED_DESKTOP_FILE}" ]; then
    APP="Guake"
  elif [ -n "$GNOME_TERMINAL_SCREEN" ]; then
    APP="Gnome"
  elif [ "$TERM_PROGRAM" == "WezTerm" ]; then
    APP="WezTerm"
  else
    APP="Unknown"
  fi
fi

test $DEBUG && echo -e "# APP: $APP"

while getopts dhjJv: option; do
  case "${option}" in
    d) APP="Disabled"
        shift
        ;;
    j) JUMPHOST="-J ${SSH_JUMPHOST:=kauri.local}" # unless already defined set to kauri.local
       shift
       ;;
    J) JUMPHOST="-J ${OPTARG}"
       shift 2
       ;;
    v) SSH_OPTIONS="${SSH_OPTIONS} -v"
       APP="Disabled" # do not open in new tab
       shift
       ;;
    h) usage
       ;;
    *) usage
       ;;
  esac
done

SSH_OPTIONS="$SSH_OPTIONS $JUMPHOST"
SSH_HOSTS="$@" # can't do this higher because need to shift off args

echo "# ssh [${SSH_OPTIONS}] [${SSH_HOSTS}] [${APP}]"

for ssh_host in $SSH_HOSTS; do
  test $DEBUG && echo -e "# APP: $APP"

  if echo $ssh_host | grep ":" > /dev/null; then
    SSH_HOST=${ssh_host%:*}
    SSH_DIR=${ssh_host#*:}
  else
    SSH_HOST=${ssh_host}
    SSH_DIR="~"
  fi

  test $DEBUG && echo "# SSH_HOST: $SSH_HOST SSH_DIR: $SSH_DIR"

  if [ "$APP" == "WezTerm" ]; then
    #SSH_OPTIONS="$SSH_OPTIONS -o RequestTTY=yes -o RemoteCommand=\"cd $SSH_DIR; $SHELL -li\""
    #test $DEBUG && echo "# CMD: wezterm cli spawn ssh $SSH_OPTIONS -o RequestTTY=yes -o RemoteCommand=\"cd $SSH_DIR; $SHELL -li\" $SSH_HOST"

    # TODO: quoting breaks when using above SSH_OPTIONS, works as below
    # this works for any host but new panes don't open on ssh host.
    wezterm cli spawn ssh $SSH_OPTIONS -o RequestTTY=yes -o RemoteCommand="cd $SSH_DIR; $SHELL -li" $SSH_HOST

    # this only works for hosts in ~/.ssh/config but new panes open on ssh host.
    # also no way to pass directories (?)
    # wezterm cli spawn --domain-name SSH:mahoe

  elif [ "$APP" == "iTerm.app" ]; then
    SSH_OPTIONS="$SSH_OPTIONS -o RequestTTY=yes -o RemoteCommand=\\\"cd $SSH_DIR; $SHELL -li\\\""
    osascript -e 'tell application "iTerm2"' \
      -e "tell current window" \
      -e "create tab with default profile command \"ssh $SSH_OPTIONS $SSH_HOST\"" \
      -e "end tell" \
      -e "end tell"

  elif [ "$APP" == "Apple_Terminal" ]; then
    SSH_OPTIONS="$SSH_OPTIONS -o RequestTTY=yes -o RemoteCommand=\\\"cd $SSH_DIR; $SHELL -li\\\""
    osascript -e 'tell application "Terminal" to activate' \
      -e 'tell application "System Events" to keystroke "t" using {command down}' \
      -e "tell application \"Terminal\" to do script \"exec ssh $SSH_OPTIONS $SSH_HOST\" in front window" \

  elif [ "$APP" == "Guake" ]; then
    # TODO: untested
    SSH_OPTIONS="$SSH_OPTIONS -o RequestTTY=yes -o RemoteCommand=\"cd $SSH_DIR; $SHELL -li\""
    guake -n foo -e "\ssh $SSH_OPTIONS $SSH_HOST; exit" -r "${USER}@${SSH_HOST}"

  elif [ "$APP" == "Gnome" ]; then
    # TODO: untested
    SSH_OPTIONS="$SSH_OPTIONS -o RequestTTY=yes -o RemoteCommand=\"cd $SSH_DIR; $SHELL -li\""
    gnome-terminal --tab-with-profile=SSH -- \ssh $SSH_OPTIONS $SSH_HOST
    #gnome-terminal --tab -- \ssh $SSH_OPTIONS $SSH_HOST

  else
    test $DEBUG && echo -e "# No Terminal detected: only connecting $SSH_HOST"
    ## FIXME: doesn't support multiple ssh hosts, not sure there's a way to make that work.
    exec \ssh -o RequestTTY=yes -o RemoteCommand="cd $SSH_DIR; $SHELL -li" "$SSH_HOST"

  fi
done

# changed to using osascript -e because I don't like having the EOF break the indents
#    osascript -i << EOF
#      tell application "iTerm2"
#         tell current window
#          # what profile is set to doesn't matter as iTerm Automatic Profile Switching will override it
#          create tab with default profile command "ssh $SSH_OPTIONS $SSH_HOST"
#        end tell
#      end tell
#EOF

## Don't need to do this because iTerm Automatic Profile Switching can do it
#RESTORE_PROFILE=${ITERM_PROFILE}
# echo -e "\033]50;SetProfile=ssh_profile\a"  # moved to _bash_profile because it has to run after sshing
# don't need to reset because happens in new tab now
# echo -e "\033]50;SetProfile=${RESTORE_PROFILE}\a"
# echo -e "\033];${RESTORE_PROFILE}\007"

## not using autossh anymore but should i want to again ...
# if [ "${1//.*/}" == "maxx" -a -x "$(which autossh)" -a ! -e $SOCKET ]; then 
#	# ! -e $SOCKET helps make sure that autossh only runs once
#	SOCKET="/Users/adam/.ssh/sockets/adam@maxx.shmoo.com:22"
#	exec autossh -M 2000 $SSH_OPTIONS $*
