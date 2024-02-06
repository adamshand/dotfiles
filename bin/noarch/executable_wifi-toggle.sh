#!/bin/bash

# Automatically disable Wi-Fi if ethernet is connected
# This script is run as a launchd agent, and is triggered by network changes

PATH="/bin:/sbin:/usr/bin:/usr/sbin"
DEBUG="yes"

# egrep regex to match interface from: networksetup -listallhardwareports
# Must return a single internface name (you may need to adjust the ETHERNET_MATCH)
# ETHERNET_REGEX="Apple USB Ethernet Adapter"
ETHERNET_REGEX="CalDigit TS3"
WIFI_REGEX="(Wi-Fi|Airport)"

print_error() {
    echo -e "ERROR: $1" >&2
    exit 1
}

print_debug() {
    test -n "$DEBUG" && echo -e "DEBUG: $1" >&2
}

get_interface() {
    test -z "$1" && print_error "get_interface(): no regex provided"
    INTERFACE=$(networksetup -listnetworkserviceorder | egrep -A 1 "$1" | egrep -o "en[0-9]+")

    if [ -z "$INTERFACE" ]; then
      print_error "No Ethernet interface found with regex: $1"
    elif [[ "$INTERFACE" == *$'\n'* ]]; then
      print_error "Multiple Ethernet interfaces found with regex: $1"
    fi

    print_debug "get_interface(): $1 -> $INTERFACE"
    echo $INTERFACE
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

ETHERNET_INTERFACE=$(get_interface "$ETHERNET_REGEX")
WIFI_INTERFACE=$(get_interface "$WIFI_REGEX")

ETHERNET_STATUS=$(is_interface_active "$ETHERNET_INTERFACE")
WIFI_STATUS=$(is_interface_active "$WIFI_INTERFACE")
print_debug "ethernet status: $ETHERNET_STATUS wifi status: $WIFI_STATUS"

if [ "$ETHERNET_STATUS" == "active" ] && [ "$WIFI_STATUS" == "active" ]; then
    echo "Both Ethernet and Wi-Fi are UP, disabling Wi-Fi"
    #networksetup -setairportpower "$WIFI_INTERFACE" off
elif [ "$ETHERNET_STATUS" == "inactive" ] && [ "$WIFI_STATUS" == "inactive" ]; then
    echo "Both Ethernet and WiFi are down, enabling Wi-Fi"
    #networksetup -setairportpower "$WIFI_INTERFACE" on
else
    print_debug "no change, interfaces good."
fi
