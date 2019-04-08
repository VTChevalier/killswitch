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
INPUT=$@                              # Grab input
SETUP="no"                            # change to yes after updating script
NET_DEV="eth0"                        # Default etwork device
LOCAL_NET="192.168.0.0/24"            # Local network subnet
NET_TUN="tun0"                        # VPN connection device
PORT=443                              # Port used by VPN
SERVICE="apache2"                     # Service used with openvpn
VPN_IP=""                             # This will be obtained
LOGFILE="/var/log/killswitch/vpn.log" # Log file location
mkdir -p /var/log/killswitch

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

if [ $SETUP != "yes" ]; then
  echo -e "Please update variables in /usr/sbin/killswitch.sh"
  exit 1;
fi

if [ "$INPUT" == "up" ]; then
  # Set up the firewall and block all connections
  /usr/sbin/ufw default deny outgoing
  /usr/sbin/ufw default deny incoming

  # allow vpn device
  /usr/sbin/ufw allow out on $NET_TUN
  /usr/sbin/ufw allow in on $NET_TUN

  # allow port for vpn over network device
  /usr/sbin/ufw allow out on $NET_DEV to any port $PORT
  /usr/sbin/ufw allow in on $NET_DEV from any port $PORT

  # allow DNS
  /usr/sbin/ufw allow out on $NET_TUN to any port 53
  /usr/sbin/ufw allow in on $NET_TUN to any port 53

  # Allow local network connections
  /usr/sbin/ufw allow out on $NET_DEV from any to $LOCAL_NET
  /usr/sbin/ufw allow in on $NET_DEV from $LOCAL_NET to any
  
  /usr/sbin/ufw enable
elif [ "$INPUT" == "up" ]; then
  /usr/sbin/ufw enable

elif [ "$INPUT" == "check" ]; then
  while [ 1 ]; do
    if [ "`/bin/ping -c1 -I $NET_TUN google.com`" == "" ]; then
      /bin/systemctl stop $SERVICE

      echo "*** [Restarting openvpn: `/bin/hostname` @ `/bin/date`] ***" >> $LOGFILE

      while [ "`/bin/ping -c1 -I $NET_TUN google.com`" == "" ]; do
        /usr/bin/pkill openvpn
        /usr/sbin/ufw disable

        if [ "inactive" != "`/usr/sbin/ufw status | cut -f2 -d \" \" | grep active`" ]; then
          /sbin/reboot
        fi

        while [ "`/sbin/ifconfig | grep 192.168.15`" == "" ]; do
          # waiting for eth to be assigned ip
          sleep 60
        done

        /usr/sbin/openvpn --daemon --config /etc/openvpn/ipvanish.conf
        sleep 30
        /usr/sbin/ufw enable

      done

      /bin/systemctl start $SERVICE

      echo "-----------------------------------------------------------------" >> $LOGFILE
    fi
    sleep 60
  done
elif [ "$INPUT" == "down" ]; then
  /usr/sbin/ufw disable

elif [ "$INPUT" == "install" ]; then
  # install cron montior

  # install init script
  echo "" > /etc/init.d/killswitch

  # start script

else
  info
fi

exit 0;

