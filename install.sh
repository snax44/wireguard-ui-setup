#!/bin/bash
###
#
# Author: Maël
# Date: 2021/03/14
# Desc:
#   - Install WireGuard without any configuration. Everything will be done through Wireguard-UI
#   - Install WireGuard-UI
#       - For a maximum security it will be use through ssh tunnel (ssh -L 5000:localhost:5000 user@vpn.domain.tld)
#       - Please customise /opt/wgui/db/server/users.json after first login
#   - Configure strict firewall
#       - DROP any ipv4 & ipv6 requests
#       - Allow loopback ipv4 & ipv6
#       - Allow Outgoing SSH, HTTPs, HTTP, DNS, Ping
#       - Allow Ingoing SSH, Wireguard ($wg_port)
#       - Allow everything needed by wireguard
#   - Save iptables rules in /etc/iptables/
#       - Load them at boot via /etc/network/if-up.d/iptables
#
# Sources:
#   - Wireguard:
#       - https://www.wireguard.com
#       - https://github.com/WireGuard
#   - Wireguard-ui:
#       - https://github.com/ngoduykhanh/wireguard-ui
#
###
OS_DETECTED="$(awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }')"
CONTINUE_ON_UNDETECTED_OS=false                                                                                         # Set true to continue if OS is not detected properly (not recommended)
WGUI_LINK="https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.5.2/wireguard-ui-v0.5.2-linux-amd64.tar.gz" # Link to the last release
WGUI_PATH="/opt/wgui"                                                                                                   # Where Wireguard-ui will be install
WGUI_BIN_PATH="/usr/local/bin"                                                                                          # Where the symbolic link will be make
SYSTEMCTL_PATH="/usr/bin/systemctl"
SYS_INTERFACE_GUESS=$(ip route show default | awk '/default/ {print $5}')
PUBLIC_IP="$(curl -s icanhazip.com)"

function main() {
  cat <<EOM

###########################################################################
  - Please make sure that your system is fully up to date and rebooted
      - The current running kernel must be the same as installed
      - No pending reboot
      - You can run the command below and then run again this script
          apt update && apt full-upgrade -y && init 6

  - Press Ctrl^C to exit or ignore this message and continue.
###########################################################################

EOM

  while [[ -z $ENDPOINT ]]; do
    echo "---"
    read -p "Enpoint [$PUBLIC_IP](fqdn possible as well): " ENDPOINT
    ENDPOINT=${ENDPOINT:-$PUBLIC_IP}
  done
  while ! [[ $WG_PORT =~ ^[0-9]+$ ]]; do
    echo "---"
    read -p "Wireguard port ? [51820]: " WG_PORT
    WG_PORT=${WG_PORT:-"51820"}
  done
  while ! [[ $WG_NETWORK =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; do
    echo "---"
    read -p "Wireguard network ? [10.252.1.0/24]: " WG_NETWORK
    WG_NETWORK=${WG_NETWORK:-"10.252.1.0/24"}
  done
  while [[ -z $WG_INTERFACE ]]; do
    echo "---"
    read -p "Wireguard interface ? [wg0]: " WG_INTERFACE
    WG_INTERFACE=${WG_INTERFACE:-"wg0"}
  done
  while [[ -z $SYS_INTERFACE ]]; do
    echo "---"
    read -p "System network interface ? [$SYS_INTERFACE_GUESS]: " SYS_INTERFACE
    SYS_INTERFACE=${SYS_INTERFACE:-$SYS_INTERFACE_GUESS}
  done
  while ! [[ $STRICT_FIREWALL =~ ^(y|n)$ ]]; do
    echo "---"
    read -p "Set the strict firewall ? [y/N]: " STRICT_FIREWALL
    STRICT_FIREWALL=${STRICT_FIREWALL:-"n"}
  done
  if [ "$STRICT_FIREWALL" == "y" ]; then
    while ! [[ $SSH_PORT =~ ^[0-9]+$ ]]; do
      echo "---"
      read -p "SSH port ? [22]: " SSH_PORT
      SSH_PORT=${SSH_PORT:-"22"}
    done
  fi

  install
  network_conf
  firewall_conf
  wg_conf
  wgui_conf

  cat <<EOM

##################################################################################
                            Setup done.

  - Your iptables rules have been saved just in case in:
      - /etc/iptables/rules.v4.bak
      - /etc/iptables/rules.v6.bak


  - To access your wireguard-ui please open a new ssh connexion
      - ssh -L 5000:localhost:5000 user@myserver.domain.tld
      - And browse to http://localhost:5000

##################################################################################"

EOM
}

function install() {

  # Wireguard is not available in Buster, so take it from backports (only if Debian Buster has been detected in detect_os)
  if [ ! -z  "$BACKPORTS_REPO" ]; then
    if ! grep -q "^$BACKPORTS_REPO" /etc/apt/sources.list /etc/apt/sources.list.d/* > /dev/null 2>&1 ; then
      echo ""
      msg info "Enable Backports for Debian Buster"
      echo $BACKPORTS_REPO >> /etc/apt/sources.list
    fi
  fi

  echo ""
  echo "### Update & Upgrade"
  apt -qq update && apt -qq full-upgrade -y

  echo ""
  echo "### Installing WireGuard"
  apt -qq install wireguard -y

  echo ""
  echo "### Installing Wireguard-UI"
  if [ ! -d $WGUI_PATH ]; then
    mkdir -m 077 $WGUI_PATH
  fi

  wget -qO - $WGUI_LINK | tar xzf - -C $WGUI_PATH

  if [ -f $WGUI_BIN_PATH/wireguard-ui ]; then
    rm $WGUI_BIN_PATH/wireguard-ui
  fi
  ln -s $WGUI_PATH/wireguard-ui $WGUI_BIN_PATH/wireguard-ui
}

function network_conf() {
  echo ""
  echo "### Enable ipv4 Forwarding"
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  sysctl -p
}

function firewall_conf() {
  echo ""
  echo "### Firewall configuration"

  if [ ! $(which iptables)  ]; then
    echo ""
    msg info "iptables is required. Let's install it."
    apt -qq install iptables -y
  fi

  if [ ! $(which ifup)  ]; then
    echo ""
    msg info "ifupdown is required. Let's install it."
    apt -qq install ifupdown -y
  fi

  if [ ! -d /etc/iptables ]; then
    mkdir -m 755 /etc/iptables
  fi

  # Stop fail2ban if it present to not save banned IPs
  if [ $(which fail2ban-client) ]; then
    fail2ban-client stop
  fi

  # Backup actual firewall configuration
  /sbin/iptables-save > /etc/iptables/rules.v4.bak
  /sbin/ip6tables-save > /etc/iptables/rules.v6.bak

  if [ "$STRICT_FIREWALL" == "n" ]; then
    RULES_4=(
    "INPUT -i $WG_INTERFACE -m comment --comment wireguard-network -j ACCEPT"
    "INPUT -p udp -m udp --dport $WG_PORT -i $SYS_INTERFACE -m comment --comment external-port-wireguard -j ACCEPT"
    "FORWARD -s $WG_NETWORK -i $WG_INTERFACE -o $SYS_INTERFACE -m comment --comment Wireguard-traffic-from-$WG_INTERFACE-to-$SYS_INTERFACE -j ACCEPT"
    "FORWARD -d $WG_NETWORK -i $SYS_INTERFACE -o $WG_INTERFACE -m comment --comment Wireguard-traffic-from-$SYS_INTERFACE-to-$WG_INTERFACE -j ACCEPT"
    "POSTROUTING -t nat -s $WG_NETWORK -o $SYS_INTERFACE -m comment --comment wireguard-nat-rule -j MASQUERADE"
    )
  elif [ "$STRICT_FIREWALL" == "y" ]; then
    RULES_4=(
    "INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"
    "INPUT -i lo -m comment --comment localhost-network -j ACCEPT"
    "INPUT -i $WG_INTERFACE -m comment --comment wireguard-network -j ACCEPT"
    "INPUT -p tcp -m tcp --dport $SSH_PORT -j ACCEPT"
    "INPUT -p icmp -m icmp --icmp-type 8 -m comment --comment Allow-ping -j ACCEPT"
    "INPUT -p udp -m udp --dport $WG_PORT -i $SYS_INTERFACE -m comment --comment external-port-wireguard -j ACCEPT"
    "FORWARD -s $WG_NETWORK -i $WG_INTERFACE -o $SYS_INTERFACE -m comment --comment Wireguard-traffic-from-$WG_INTERFACE-to-$SYS_INTERFACE -j ACCEPT"
    "FORWARD -d $WG_NETWORK -i $SYS_INTERFACE -o $WG_INTERFACE -m comment --comment Wireguard-traffic-from-$SYS_INTERFACE-to-$WG_INTERFACE -j ACCEPT"
    "FORWARD -p tcp --syn -m limit --limit 1/second -m comment --comment Flood-&-DoS -j ACCEPT"
    "FORWARD -p udp -m limit --limit 1/second -m comment --comment Flood-&-DoS -j ACCEPT"
    "FORWARD -p icmp --icmp-type echo-request -m limit --limit 1/second -m comment --comment Flood-&-DoS -j ACCEPT"
    "FORWARD -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -m comment --comment Port-Scan -j ACCEPT"
    "OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"
    "OUTPUT -o lo -m comment --comment localhost-network -j ACCEPT"
    "OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT"
    "OUTPUT -p tcp -m tcp --dport 80 -j ACCEPT"
    "OUTPUT -p tcp -m tcp --dport 22 -j ACCEPT"
    "OUTPUT -p udp -m udp --dport 53 -j ACCEPT"
    "OUTPUT -p tcp -m tcp --dport 53 -j ACCEPT"
    "OUTPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT"
    "POSTROUTING -t nat -s $WG_NETWORK -o $SYS_INTERFACE -m comment --comment wireguard-nat-rule -j MASQUERADE"
    )

    RULES_6=(
    "INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"
    "INPUT -i lo -m comment --comment localhost-network -j ACCEPT"
    "OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"
    "OUTPUT -o lo -m comment --comment localhost-network -j ACCEPT"
    )

    # Change default policy to DROP instead ACCEPT
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT DROP
  fi

  # Apply rules only if they are not already present
  if [ ! -z "$RULES_4" ]; then
    for e in "${RULES_4[@]}"; do
      iptables -C $e > /dev/null 2>&1 || iptables -A $e
    done
  fi

  if [ ! -z "$RULES_6" ]; then
    for e in "${RULES_6[@]}"; do
      ip6tables -C $e > /dev/null 2>&1 || ip6tables -A $e
    done
  fi

  # Backup allrules (old and new)
  /sbin/iptables-save > /etc/iptables/rules.v4
  /sbin/ip6tables-save > /etc/iptables/rules.v6

  # Restart Fail2ban
  if [ $(which fail2ban-client) ]; then
    fail2ban-client start
  fi

  # Make a script for a persistent configuration
  echo "#!/bin/sh
  /sbin/iptables-restore < /etc/iptables/rules.v4
  /sbin/ip6tables-restore < /etc/iptables/rules.v6" > /etc/network/if-up.d/iptables
  chmod 755 /etc/network/if-up.d/iptables
}

function wg_conf() {
  echo ""
  echo "### Making default Wireguard conf"
  umask 077 /etc/wireguard/
  touch /etc/wireguard/$WG_INTERFACE.conf
  $SYSTEMCTL_PATH enable wg-quick@$WG_INTERFACE.service
}

function wgui_conf() {

  echo ""
  echo "### Wiregard-ui Services"
  echo "[Unit]
  Description=Wireguard UI
  After=network.target

  [Service]
  Type=simple
  WorkingDirectory=$WGUI_PATH
  ExecStart=$WGUI_BIN_PATH/wireguard-ui -bind-address 127.0.0.1:5000

  [Install]
  WantedBy=multi-user.target" > /etc/systemd/system/wgui_http.service

  $SYSTEMCTL_PATH enable wgui_http.service
  $SYSTEMCTL_PATH start wgui_http.service

  echo "[Unit]
  Description=Restart WireGuard
  After=network.target

  [Service]
  Type=oneshot
  ExecStart=$SYSTEMCTL_PATH restart wg-quick@$WG_INTERFACE.service" > /etc/systemd/system/wgui.service

  echo "[Unit]
  Description=Watch /etc/wireguard/$WG_INTERFACE.conf for changes

  [Path]
  PathModified=/etc/wireguard/$WG_INTERFACE.conf

  [Install]
  WantedBy=multi-user.target" > /etc/systemd/system/wgui.path

  $SYSTEMCTL_PATH enable wgui.{path,service}
  $SYSTEMCTL_PATH start wgui.{path,service}
}

function msg(){

  local GREEN="\\033[1;32m"
  local NORMAL="\\033[0;39m"
  local RED="\\033[1;31m"
  local PINK="\\033[1;35m"
  local BLUE="\\033[1;34m"
  local WHITE="\\033[0;02m"
  local YELLOW="\\033[1;33m"

  if [ "$1" == "ok" ]; then
    echo -e "[$GREEN  OK  $NORMAL] $2"
  elif [ "$1" == "ko" ]; then
    echo -e "[$RED ERROR $NORMAL] $2"
  elif [ "$1" == "warn" ]; then
    echo -e "[$YELLOW WARN $NORMAL] $2"
  elif [ "$1" == "info" ]; then
    echo -e "[$BLUE INFO $NORMAL] $2"
  fi
}

function not_supported_os(){
  msg ko "Oops This OS is not supported yet !"
  echo "    Do not hesitate to contribute for a better compatibility
            https://gitlab.com/snax44/wireguard-ui-setup"
}

function detect_os(){
  if [[ "$OS_DETECTED" == "debian" ]]; then
    if grep -q "bullseye" /etc/os-release; then
      msg info "OS detected : Debian 11 (Bullseye)"
      main
    elif grep -q "buster" /etc/os-release; then
      msg info "OS detected : Debian 10 (Buster)"
      BACKPORTS_REPO="deb https://deb.debian.org/debian/ buster-backports main"
      main
    fi

  elif [[ "$OS_DETECTED" == "ubuntu" ]]; then
    if grep -q "focal" /etc/os-release; then
      msg info "OS detected : Ubuntu Focal (20.04)"
      main
    elif grep -q "groovy" /etc/os-release; then
      msg info "OS detected : Ubuntu Groovy (20.10)"
      main
    elif grep -q "hirsute" /etc/os-release; then
      msg info "OS detected : Ubuntu Hirsute (21.04)"
      main
    elif grep -q "impish" /etc/os-release; then
      msg info "OS detected : Ubuntu Impish (21.10)"
      main
    fi

  elif [[ "$OS_DETECTED" == "fedora" ]]; then
    msg info "OS detected : Fedora"
    not_supported_os
  elif [[ "$OS_DETECTED" == "centos" ]]; then
    msg info "OS detected : Centos"
    not_supported_os
  elif [[ "$OS_DETECTED" == "arch" ]]; then
    msg info "OS detected : Archlinux"
    not_supported_os
  else
    if $CONTINUE_ON_UNDETECTED_OS; then
      msg warn "Unable to detect os. Keep going anyway in 5s"
      sleep 5
      main
    else
      msg ko "Unable to detect os and CONTINUE_ON_UNDETECTED_OS is set to false"
      exit 1
    fi
  fi
}

if ! [ $(id -nu) == "root" ]; then
  msg ko "Oops ! Please run this script as root"
  exit 1
fi

detect_os
