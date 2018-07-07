#!/bin/bash
#
# /usr/sbin/killswitch.sh v 0.01
#
# Copyright (C) 2018 Free Software Foundation, Inc.
# This is free software.  You may redistribute copies of it under the terms of
# the GNU General Public License .
# There is NO WARRANTY, to the extent permitted by law.
#
# Written by Victor T. Chevalier
#
# Designed for use with openvpn on Ubuntu 18.04/16.04 LTS
#
INPUT=$@                   # Grab input
SETUP="no"                 # change to yes after updating script
NET_DEV="eth0"             # Default etwork device
LOCAL_NET="192.168.0.0/24" # Local network subnet
NET_TUN="tun0"             # VPN connection device
PORT=443                   # Port used by VPN
SERVICE="apache2"          # Service used with openvpn
VPN_IP=""                  # This will be obtained

# info about usage
info()
{
  echo -e "Usage: killswitch.sh up/down/check\n"
  echo -e "killswitch.sh is designed to config ufw based on vars in the script\n"
  echo -e "Options :"
  echo -e "  up      configures ufw based on new vpn device"
  echo -e "  down    clears ufw ALL rules"
  echo -e "  check   monitors your vpn for changes, used in crontab\n"
  echo -e "An argument must be provided or you will receive this message"
}

# ufw force reset function
ufwreset()
{
  ufw --force reset
}

if [ $SETUP != "yes" ]; then
  echo -e "Please update variables in /usr/sbin/killswitch.sh"
  exit 1;
fi

if [ "$INPUT" == "up" ]; then
  ufwreset

  # Set up the firewall and block all connections
  ufw default deny outgoing
  ufw default deny incoming

  # allow vpn device
  ufw allow out on $NET_TUN
  ufw allow in on $NET_TUN

  # allow port for vpn over network device
  ufw allow out on $NET_DEV to any port $PORT
  ufw allow in on $NET_DEV from any port $PORT

  # allow DNS
  ufw allow out on $NET_TUN to any port 53
  ufw allow in on $NET_TUN to any port 53

  # Allow local network connections
  ufw allow out on $NET_DEV from any to $LOCAL_NET
  ufw allow in on $NET_DEV from $LOCAL_NET to any

  ufw enable
elif [ "$INPUT" == "check" ]; then
  while [ 1 ]; do
    if [ "`/bin/ping -c1 -I $NET_TUN google.com`" == "" ]; then
      echo "Error detected with openvpn, restarting openvpn and $SERVICE..."
      /bin/systemctl start $SERVICE
      /bin/systemctl stop openvpn
      ufwreset
      /bin/systemctl start openvpn
      /bin/sleep 5
      /usr/sbin/killswitch.sh up
      /bin/systemctl start $SERVICE
      echo "killswitch.sh restored."
    fi
    /bin/sleep 15
  done
elif [ "$INPUT" == "down" ]; then
  ufwreset
else
  info
fi

exit 0;