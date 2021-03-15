#!/bin/bash
###
#
# Author: Maël
# Date: 2021/03/14
# Desc:
#   - Install WireGuard without any configuration. Everything will be done through Wireguard-UI
#   - Install WireGuard-UI
#       - Wireguard is a very good project but not ended yet (security).
#       - For a maximum security it will be use through ssh tunnel (ssh -L 5000:localhost:5000 user@vpn.domain.tld)
#       - Please customise /opt/wgui/db/server/users.json after first login
#   - Configure strict firewall
#       - DROP any ipv4 & ipv6 requests
#       - Allow loopback ipv4 & ipv6
#       - Allow Outgoing SSH, HTTPs, HTTP, DNS, Ping
#       - Allow Ingoing SSH, Wireguard ($wg_port)
#       - Allow everything needed by wireguard
#   - Save iptables rules with iptables-persistent
#
# Sources:
#   - Wireguard:
#       - https://www.wireguard.com
#       - https://github.com/WireGuard
#   - Wireguard-ui:
#       - https://github.com/ngoduykhanh/wireguard-ui 
#
###

if ! [ $(id -nu) == "root" ]; then
  echo "Please run this script as root"
  exit 1
fi

if [ "$(lsb_release -is)" != "Debian" ] && [ "$(lsb_release -rs)" != "10" ]
  then
    echo "This script was made for on Debian10 only."
    exit 1
fi

endpoint="server.domain.tld"
wg_port="51820"
wg_network="10.252.1.0/24"
wg_interface="wg0"
system_interface="ens18"
ssh_port="22"
admin_ip="client.domain.tld"
wgui_link="https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.2.7/wireguard-ui-v0.2.7-linux-amd64.tar.gz"
wgui_path="/opt/wgui"
wgui_bin_path="/usr/local/bin"
systemctl_path="/usr/bin/systemctl"
deb_backport="deb https://deb.debian.org/debian/ buster-backports main"


function install() {

  if ! grep -q "^$deb_backport" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    echo ""
    echo "### Enable debian-backports"
    echo "deb https://deb.debian.org/debian/ buster-backports main" >> /etc/apt/sources.list
  fi

  echo ""
  echo "### Update & Upgrade"
  apt update && apt full-upgrade -y

  echo ""
  echo "### Installing WireGuard"
  apt install linux-headers-$(uname --kernel-release) wireguard -y

  echo ""
  echo "### Installing Wireguard-UI"
  mkdir $wgui_path
  umask 077 $wgui_path
  wget -qO - $wgui_link | tar xzf - -C $wgui_path
  ln -s $wgui_path/wireguard-ui $wgui_bin_path/wireguard-ui
}

function network_conf() {
  echo ""
  echo "### Enable ipv4 Forwarding"
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  sysctl -p
}

function firewall_conf() {
  if [ "$(which iptables)" = "" ]; then
    echo ""
    echo "### iptables is required. Let's install it."
    apt install iptables -y
  fi

  echo ""
  echo "### Firewall IPV4 configuration"
  iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -A INPUT -i lo -m comment --comment localhost-network -j ACCEPT
  iptables -A INPUT -i $wg_interface -m comment --comment wireguard-network -j ACCEPT
  iptables -A INPUT -p tcp -m tcp --dport $ssh_port -j ACCEPT
  iptables -A INPUT -s $admin_ip -p icmp -m icmp --icmp-type 8 -m comment --comment "Ping-from-$admin_ip" -j ACCEPT
  iptables -A INPUT -p udp -m udp --dport $wg_port -m comment --comment "external-port-wireguard" -j ACCEPT
  iptables -A FORWARD -s $wg_network -i $wg_interface -o $system_interface -m comment --comment "Wireguard traffic from $wg_interface to $system_interface" -j ACCEPT
  iptables -A FORWARD -d $wg_network -i $system_interface -o $wg_interface -m comment --comment "Wireguard traffic from $system_interface to $wg_interface" -j ACCEPT
  iptables -A FORWARD -d $wg_network -i $wg_interface -o $wg_interface -m comment --comment "Wireguard traffic inside $wg_interface" -j ACCEPT
  iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -A OUTPUT -o lo -m comment --comment localhost-network -j ACCEPT
  iptables -A OUTPUT -o $wg_interface -m comment --comment wireguard-network -j ACCEPT
  iptables -A OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT
  iptables -A OUTPUT -p tcp -m tcp --dport 80 -j ACCEPT
  iptables -A OUTPUT -p tcp -m tcp --dport 22 -j ACCEPT
  iptables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
  iptables -A OUTPUT -p tcp -m tcp --dport 53 -j ACCEPT
  iptables -A OUTPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
  iptables -t nat -A POSTROUTING -s $wg_network -o $system_interface -m comment --comment wireguard-nat-rule -j MASQUERADE
  iptables -P INPUT DROP
  iptables -P FORWARD DROP
  iptables -P OUTPUT DROP

  echo ""
  echo "### Firewall IPV6 configuration"
  ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
  ip6tables -A INPUT -i lo -m comment --comment localhost-network -j ACCEPT
  ip6tables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
  ip6tables -A OUTPUT -o lo -m comment --comment localhost-network -j ACCEPT
  ip6tables -P INPUT DROP
  ip6tables -P FORWARD DROP
  ip6tables -P OUTPUT DROP

  if [ "$(which netfilter-persistent)" = "" ]; then
    echo ""
    echo "### iptables-persistent is required. Let's install it."
    echo "iptables-persistent iptables-persistent/autosave_v4	boolean	true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6	boolean	true" | debconf-set-selections
    apt install iptables-persistent -y
  fi
  
  echo ""
  echo "### Saving firewall rules"
  service netfilter-persistent save
}

function wg_conf() {
  echo ""
  echo "### Making default Wireguard conf"
  umask 077 /etc/wireguard/
  touch /etc/wireguard/$wg_interface.conf
  systemctl enable wg-quick@$wg_interface.service
}

function wgui_conf() {

  echo ""
  echo "### Wiregard-ui Services"
  echo "[Unit]
  Description=Wireguard UI
  After=network.target

  [Service]
  Type=simple
  WorkingDirectory=$wgui_path
  ExecStart=$wgui_bin_path/wireguard-ui

  [Install]
  WantedBy=multi-user.target" > /etc/systemd/system/wgui_http.service

  systemctl enable wgui_http.service
  systemctl start wgui_http.service

  echo "[Unit]
  Description=Restart WireGuard
  After=network.target

  [Service]
  Type=oneshot
  ExecStart=$systemctl_path restart wg-quick@$wg_interface.service" > /etc/systemd/system/wgui.service

  echo "[Unit]
  Description=Watch /etc/wireguard/$wg_interface.conf for changes

  [Path]
  PathModified=/etc/wireguard/$wg_interface.conf

  [Install]
  WantedBy=multi-user.target" > /etc/systemd/system/wgui.path

  systemctl enable wgui.{path,service}
  systemctl start wgui.{path,service}
}

install
network_conf
firewall_conf
wg_conf
wgui_conf
