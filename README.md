# wireguard-ui-setup

A simple script to install Wireguard and Wirguard-ui

**Warning:**  
- This script was made for on Debian10 only.  
- If the server is doing something else, please be carrefull about firewall rules.
  - Just in case all rules will be saved in /etc/iptables/rules.v4.bak & /etc/iptables/rules.v4.bak

## Features

- Automate minimal installation of Wirguard and Wireguard-ui
- Setup firewall
- Make wireguard-ui as service

# Usage

Be sure that the server is fully up to date.  

**Download the script on your server:**  
```bash
bash <(curl -s https://gitlab.com/maelj/wireguard-ui-setup/-/raw/master/install.sh)
```

**Open a new ssh connection with port forwarding:**  
```bash
ssh -L 5000:localhost:5000 user@vpn_server_ip
```

Access http://localhost:5000 from your favorite browser.  
(username/password = admin)  

# Troubleshooting

## wg-quick<!-- -->@wg0.service failed to start

Please check that linux-headers-$(uname -r) was installed propely.

# Credits

- Wireguard:
   - https://www.wireguard.com
   - https://github.com/WireGuard
- Wireguard-ui:
   - https://github.com/ngoduykhanh/wireguard-ui
