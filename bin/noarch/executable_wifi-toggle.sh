#!/bin/bash

# Automatically disable Wi-Fi if ethernet is connected
# This script is run as a launchd agent, and is triggered by network changes

PATH="/bin:/sbin:/usr/bin:/usr/sbin"
DEBUG="yes"

LAUNCHD_SERVICE="com.haume.wifi-toggle"

# egrep regex to match interface from: networksetup -listallhardwareports
# Must return a single internface name (you may need to adjust the ETHERNET_MATCH)
ETHERNET_REGEX="CalDigit TS3"
# ETHERNET_REGEX="Apple USB Ethernet Adapter"
WIFI_REGEX="(Wi-Fi|Airport)"

print_error() {
  echo -e "ERROR: $1" >&2
  exit 1
}

print_debug() {
  test -n "$DEBUG" && echo -e "DEBUG: $1" >&2
}

is_launchd_loaded() {
  if launchctl list | grep -q "$LAUNCHD_SERVICE"; then
    print_debug "is_launchd_loaded(): $LAUNCHD_SERVICE loaded"
    return 0
  else
    print_debug "is_launchd_loaded(): $LAUNCHD_SERVICE not loaded"
    return 1
  fi
}

install_launchd() {
  SERVICE="${HOME}/Library/LaunchAgents/${LAUNCHD_SERVICE}.plist"
  echo "Creating launchd service: $SERVICE"
  cat <<EOF > "$SERVICE"
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
  echo "Loading launchd service: $LAUNCHD_SERVICE"
  launchctl load "$SERVICE"
}


send_notification() {
  osascript -e "display notification \"by $(basename $0)\" with title \"$1\""
}

get_interface() {
  test -z "$1" && print_error "get_interface(): no regex provided"
  INTERFACE=$(networksetup -listnetworkserviceorder | grep -E -A 1 "$1" | grep -E -o "en[0-9]+")

  if [ -z "$INTERFACE" ]; then
    print_error "No Ethernet interface found with regex: $1"
  elif [[ "$INTERFACE" == *$'\n'* ]]; then
    print_error "Multiple Ethernet interfaces found with regex: $1"
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

if ! is_launchd_loaded; then
  install_launchd
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


# xx_install_launchd() {
#   SERVICE="${HOME}/Library/LaunchAgents/com.haume.wifi-toggle.plist"
#   echo "Installing launchd agent"
#   cat <<EOF > "$SERVICE"
#   <?xml version="1.0" encoding="UTF-8"?>
#   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
#   <plist version="1.0">
#   <dict>
#     <key>Label</key>
#     <string>com.mine.toggleairport</string>
#     <key>OnDemand</key>
#     <true/>
#     <key>ProgramArguments</key>
#     <array>
#       <string>$(realpath $)</string>
#     </array>
#     <key>WatchPaths</key>
#     <array>
#       <string>/Library/Preferences/SystemConfiguration</string>
#     </array>
#   </dict>
#   </plist>
#   EOF
#   launchctl load "$SERVICE"
# }
