#!/bin/bash
# http://blog.andrew.net.au/2005/02/16#ipt_recent_and_ssh_attacks
# another more recent option https://www.cyberciti.biz/tips/linux-unix-bsd-openssh-server-best-practices.html

iptables -F

TRUSTED_HOSTS="127.0.0.1 205.134.188.171 121.73.22.207 64.142.74.74 210.55.0.161 205.134.188.169 205.134.188.162 207.115.69.58 12.17.141.65 67.207.134.156"

iptables -N SSH_WHITELIST

iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -j SSH_WHITELIST
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j ULOG --ulog-prefix SSH_brute_force
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j DROP

for host in $TRUSTED_HOSTS; do
  iptables -A SSH_WHITELIST -s $host -m recent --remove --name SSH -j ACCEPT
done

iptables -L -n
