# wireguard-ui-setup

A simple script to install [Wireguard](https://www.wireguard.com/) and [Wireguard-ui](https://github.com/ngoduykhanh/wireguard-ui)

## Features

- Automate minimal installation of Wirguard and Wireguard-ui
- Make wireguard-ui as service
- Setup quite strict firewall (Optional)
  - Default policy => DROP
  - Allow loopback ipv4 & ipv6
  - Allow Outgoing SSH, HTTPs, HTTP, DNS, Ping
  - Allow Ingoing SSH, Wireguard ($wg_port)
  - Allow everything needed by wireguard
- Save iptables rules in /etc/iptables/
  - Load them at boot via /etc/network/if-up.d/iptables
  - Backup actual rules in /etc/iptables/rules.v[4-6].bak

## Requirement and Warning note

- Be sure that the **server is fully up to date**.
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


# Troubleshooting

## wg-quick<!-- -->@wg0.service failed to start

Please check that linux-headers-$(uname -r) was installed propely.

# Tested on

- Debian Buster
- Debian Bulseye
- Ubuntu 20.04
- Ubuntu 20.10

# Credits

- Wireguard:
   - https://www.wireguard.com
   - https://github.com/WireGuard
- Wireguard-ui:
   - https://github.com/ngoduykhanh/wireguard-ui
