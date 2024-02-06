#!/bin/bash

# Automatically toggle macOS Wi-Fi based on ethernet status (uses launchd).
# If ethernet is active, Wi-Fi is disabled. If ethernet is inactive, Wi-Fi is enabled.
# Written by Adam Shand <adam@shand.net> on 7 Feb 2024

PATH="/bin:/sbin:/usr/bin:/usr/sbin"
LAUNCHD_SERVICE="nz.haume.wifi-toggle"
LAUNCHD_FILE="${HOME}/Library/LaunchAgents/${LAUNCHD_SERVICE}.plist"

# Regexes must match a single interface from `networksetup -listnetworkserviceorder`
# eg. "(2) CalDigit TS3" or "(1) Apple USB Ethernet Adapter"
ETHERNET_REGEX="CalDigit TS3"
# ETHERNET_REGEX="Apple USB Ethernet Adapter"
# ETHERNET_REGEX="Ethernet"
WIFI_REGEX="(Wi-Fi|Airport)"

print_usage() {
  echo -e "Automatically toggle macOS Wi-Fi based on ethernet status (uses launchd)\n"
  echo "Usage: $(basename $0) [ off | debug | help ]"
  echo "       off   - stop automatically toggling Wi-Fi"
  echo "       debug - print debugging information"
  exit 0
}

print_error() {
  echo -e "ERROR: $1" >&2
  exit 1
}

print_debug() {
  test -n "$DEBUG" && echo -e "DEBUG: $1" >&2
}

send_notification() {
  # Configure notifications in: System Settings > Notifications > Script Editor
  osascript -e "display notification \"by $(basename $0)\" with title \"$1\""
}

is_launchd_loaded() {
  if launchctl list | grep -q "$LAUNCHD_SERVICE"; then
    print_debug "is_launchd_loaded(): $LAUNCHD_SERVICE already loaded"
    return 0
  else
    print_debug "is_launchd_loaded(): $LAUNCHD_SERVICE not loaded"
    return 1
  fi
}

enable_launchd() {
  echo "Creating launchd service: $LAUNCHD_FILE"
  cat <<EOF > "$LAUNCHD_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LAUNCHD_SERVICE}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>ProgramArguments</key>
  <array>
    <string>$(realpath "$0")</string>
  </array>
  <key>WatchPaths</key>
  <array>
    <string>/Library/Preferences/SystemConfiguration</string>
  </array>
</dict>
</plist>
EOF
  echo "Enabling launchd service: $LAUNCHD_SERVICE"
  launchctl load "$LAUNCHD_FILE"
}

disable_launchd() {
  echo "Disabling launchd service: $LAUNCHD_SERVICE"
  launchctl unload "$LAUNCHD_FILE"
  rm "$LAUNCHD_FILE"
  exit 0
}

get_interface() {
  test -z "$1" && print_error "get_interface(): no regex provided"
  INTERFACE=$(networksetup -listnetworkserviceorder | grep -E -A 1 "^\([0-9]+\).* $1" | grep -E -o "en[0-9]+")

  if [ -z "$INTERFACE" ]; then
    print_error "No ethernet interface matches: $1"
  elif [[ "$INTERFACE" == *$'\n'* ]]; then
    print_error "Multiple ethernet interfaces match: $1"
  fi

  print_debug "get_interface(): regex '$1' -> interface '$INTERFACE'"
  echo "$INTERFACE"
}

is_interface_active() {
  test -z "$1" && print_error "is_interface_active(): no interface provided"

  if ifconfig "$1" 2>&1 | grep -q "status: active"; then
    echo -n "active"
    return 0
  else
    echo -n "inactive"
    return 1
  fi
}

if [ "${OSTYPE:0:6}" != "darwin" ]; then
  print_error "This script only runs on macOS"
elif [ "$1" == "help" ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  print_usage
elif [ "$1" == "off" ]; then
  disable_launchd
elif [ "$1" == "debug" ]; then
  DEBUG="yes"
  print_debug "Debugging enabled"
fi

if ! is_launchd_loaded; then
  enable_launchd
fi

ETHERNET_INTERFACE=$(get_interface "$ETHERNET_REGEX")
WIFI_INTERFACE=$(get_interface "$WIFI_REGEX")

ETHERNET_STATUS=$(is_interface_active "$ETHERNET_INTERFACE")
WIFI_STATUS=$(is_interface_active "$WIFI_INTERFACE")
print_debug "ethernet status: '$ETHERNET_STATUS', wifi status: '$WIFI_STATUS'"

if [ "$ETHERNET_STATUS" == "active" ] && [ "$WIFI_STATUS" == "active" ]; then
  print_debug "disabling wifi"
  networksetup -setairportpower "$WIFI_INTERFACE" off
  send_notification "Wi-Fi Disabled"
elif [ "$ETHERNET_STATUS" == "inactive" ] && [ "$WIFI_STATUS" == "inactive" ]; then
  print_debug "enabling wifi"
  networksetup -setairportpower "$WIFI_INTERFACE" on
  send_notification "Wi-Fi Enabled"
else
  print_debug "no change to wifi"
fi
