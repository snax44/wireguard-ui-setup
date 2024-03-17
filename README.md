:exclamation: Since I do not use that script so much anymore it might slowly get buggy and out of date.  
You've been warned.  

# wireguard-ui-setup

A simple script to install [Wireguard](https://www.wireguard.com/) and [Wireguard-ui](https://github.com/ngoduykhanh/wireguard-ui).
Like commercial VPN provider, here the firewall is setup to forward all traffic from clients.

:fr: [French version](README_fr.md)

## Features

- Automate minimal installation of Wirguard and Wireguard-ui
- Make wireguard-ui as service
- Setup quite strict firewall (Optional)
  - Default policy => DROP
  - Allow loopback ipv4 & ipv6
  - Allow Outgoing SSH, HTTPs, HTTP, DNS, ICMP
  - Allow Ingoing SSH, Wireguard ($wg_port)
  - Allow everything needed by wireguard
- Save iptables rules in /etc/iptables/
  - Load them at boot via /etc/network/if-up.d/iptables
  - Backup actual rules in /etc/iptables/rules.v[4-6].bak

## Requirement and Warning note

- Make sure the **server is fully up to date**.
- If the server is doing something else, please at the question "Set the strict firewall" select `n`

# Usage

## Download and execute the script on your server  

```bash
bash <(curl -s https://gitlab.com/snax44/wireguard-ui-setup/-/raw/master/install.sh)
```
Just answer 6 questions and take a coffee.  

## Enjoy your new VPN

**Open a new ssh connection with port forwarding:**  
In command line:
```bash
ssh -L 5000:localhost:5000 user@vpn_server_ip
```
or directly in your SSH config file:  
```
Host myserver
	hostname myserver.domain.tld
	IdentityFile ~/.ssh/myprivatekey
	user myuser
	LocalForward 5000 localhost:5000
```

**Browse to Wireguard UI:**  

Browse http://localhost:5000  
(username/password = admin)  

:bulb: Default password can be changed in /opt/wgui/db/server/users.json  

# Troubleshooting

## wg-quick<!-- -->@wg0.service failed to start

Please check that linux-headers-$(uname -r) was installed propely.

## OS undetected on Distro suppose to work

If you get the message `[ ERROR ] Unable to detect os and CONTINUE_ON_UNDETECTED_OS is set to false` on a system that is suppose to work fine,  
Make sure the command `awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }'` returns only one line containing the distro name (e.g debian, ubuntu etc...).  
If not, it might be caused by an other release file in `/etc` such as `/etc/cloud-release`.  

As a quick fix you can force the script to only look at `/etc/os-release` instead of `/etc/*-release`.  

**1. Download the script**
```
curl -s https://gitlab.com/snax44/wireguard-ui-setup/-/raw/master/install.sh -O install.sh
```

**2. Modify the script (Line 28) with vim, nano or whatever editor you like.**

From:
```
OS_DETECTED="$(awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }')"
```
To
```
OS_DETECTED="$(awk '/^ID=/' /etc/os-release | awk -F'=' '{ print tolower($2) }')"
```

**3. Run the script**
```
bash install.sh
```

# Tested on Amd64

- Debian Buster
- Debian Bullseye
- Debian Bookworm (Recommended)
- Ubuntu 20.04
- Ubuntu 20.10
- Ubuntu 21.04
- Ubuntu 21.10

# Credits

- Wireguard:
   - https://www.wireguard.com
   - https://github.com/WireGuard
- Wireguard-ui:
   - https://github.com/ngoduykhanh/wireguard-ui
