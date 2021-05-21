# wireguard-ui-setup

Un simple script pour installer [Wireguard](https://www.wireguard.com/) et [Wireguard-ui](https://github.com/ngoduykhanh/wireguard-ui) simplement et rapidement.

## Fonctionnalitées

- Automatise l'installation de Wirguard et Wireguard-ui
- Fait de Wireguard-UI un service avec systemd
- Configure un parfeu pluôt strict (en option)
  - Par défaut tout est ignoré
  - Autorise loopback ipv4 & ipv6
  - Autorise les connexions SSH, HTTPs, HTTP, DNS, Ping sortantes
  - Autorise les connexions SSH, Wireguard ($wg_port) entrantes
  - Autorise tout ce qui est necessaire pour wireguard
- Sauvegarde des règles dans /etc/iptables/
  - Chargement des règles au démarrage via le script `/etc/network/if-up.d/iptables`
  - Par sécurité la configuration actuelle du parefeu est sauvegardé dans  `/etc/iptables/rules.v[4-6].bak`

## Les prérequis et points d'attention

- Soyez sur que le **server totalement à jour**.  
- Si votre parfeu est déjà configuré, selectionnez `n` à la question "Set the strict firewall".  

# Utilisation

## Télécharger puis éxécutez le script sur votre serveur

```bash
bash <(curl -s https://gitlab.com/snax44/wireguard-ui-setup/-/raw/master/install.sh)
```
Répondez aux 6 questions puis buvez un (petit) café.  

## Profitez de votre nouveau VPN

**Ouvrez une connexion ssh avec le port forwarding:**  

En ligne de commande:
```bash
ssh -L 5000:localhost:5000 user@vpn_server_ip
```
ou configurez directement votre ~/.ssh/config
```
Host myserver
	hostname myserver.domain.tld
	IdentityFile ~/.ssh/myprivatekey
	user myuser
	LocalForward 5000 localhost:5000
```

**Connectez vous à l'interface web Wireguard UI:**  

Browse http://localhost:5000  
(utilisateur/mdp = admin)  
