# TP4 - Nicolas MARRA (3A - RIO)


## - Introduction 

Après avoir téléchargé la machine virtuelle, je me suis connecté sur la machine ops via ssh, avec la commande suivante : 

```bash 
ssh tprli@192.168.57.98
```


j'ai testé l'accès à GLPI via l'url suivante: 

http://192.168.57.98/glpi/ (identifiant : glpi/tprli)


Pour avoir l'internet sur la machine ops, j'ai utilisé les règles iptables suivantes : 

```bash
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -j MASQUERADE  
iptables -t nat -A POSTROUTING -s 192.168.56.0/24 -j MASQUERADE  
iptables -t nat -A POSTROUTING -s 192.168.57.0/24 -j MASQUERADE  

echo 1 > /proc/sys/net/ipv4/ip_forward
```

## - Installation de l'agent fusioninventory

Dans cette partie, j'ai utilisé un playbook ansible pour le déploiement (installation de paquet, configuration) sur les 3 pcs.

Tout d'abord, j'ai paramétré ansible sur home/tprli/.ansible.cfg pour ignorer les clés machines et utiliser root comme login de connexion ssh, avec les commandes suivantes : 

```cfg
[defaults]
host_key_checking = False
remote_user = root
inventory = /home/tprli/hosts
```

Ensuite, j'ai créé un inventaire nommé inventory.ini contenant donc les pc1, pc2 et pc3: 

```ini
[pcs]
pc1
pc2
pc3
```


Après avoir créé l'inventaire, j'ai déployé l'agent fusion (paquet "fusioninventory-agent"), en paramétrant l'agent (fichier /etc/fusioninventory/agent.cfg) et indiquant l'url de l'API fusion inventory du serveur GLPI, après l'agent s'exécute sur la machine : fusioninventory-agent
Les commandes ont été précisées sur le fichier fusioninventory.yml : 

```yml
- name: Déployer l'agent FusionInventory
  hosts: pcs
  become: true
  tasks:
  - name: Mettre à jour le système de chaque pc
    command: apt update --allow-releaseinfo-change
    
  - name: Installer le paquet FusionInventory-agent
    package:
      name: fusioninventory-agent
      state: present
  - name: Configurer l'agent FusionInventory
    lineinfile:
     path: /etc/fusioninventory/agent.cfg
     regex: '^server'
     line: 'server = http://192.168.57.98/glpi/plugins/fusioninventory/'
  - name: Exécuter l'agent FusionInventory
    command: fusioninventory-agent
```

Une fois tout paramétré, j'ai lancé le playbook avec la commande suivante : 

```bash
ansible-playbook -i inventory.ini fusioninventory.yml
```

Pourque que cela marche, j'ai du me connecter à chaque pc et faire `apt-update`. 
J'ai pu vérifier que les machines et leur configuration ont été ajoutées dans l'inventaire GLPI via l'url suivante : 

```bash
http://192.168.57.98/glpi/plugins/fusioninventory/front/menu.php
```

![Alt text](image.png)
![alt text](image-1.png)


## - Utilisation de l'API de GLPI


Dans cette partie, je vais utiliser l'API propser par GLPI pour accéder aux données de l'inventaire. 
L'accès à cette API se fait en deux étapes :
  - Authentification
  - Requête à l'API

Un script en python sera écrit pour réalise ces deux étapes afin de renvoyer la liste de tous les ordinateurs de la base d'inventaire.

Tout d'abord, un client API doit être créé afin d'obtenir la clé APPTOKEN qui permet de faire l'authentification et d'accéder à l'API. 

Le client api a généré le token suivant : 
```bash
utIjN6j9JMsPiaqsfUOFd4xyH5H4OsTlMICriKnZ
```

Ce token sera utilisé comme clé pour s'authentifier, il faudra utiliser aussi le nom d'utilisateur (glpi) et le mot de passe (tprli) utilisé pour se connecter sur le dashboard GLPI.


Le script suivant permet de s'authentifier à l'API et de récupérer la liste de tous les ordinateurs de l'inventaire. 

```python
import requests
import base64

user = "glpi"
password = "tprli"
APPTOKEN = "utIjN6j9JMsPiaqsfUOFd4xyH5H4OsTlMICriKnZ"
APIURL = "http://192.168.57.98/glpi/apirest.php"

# 1- Authentification
auth_token = base64.b64encode(f"{user}:{password}".encode('utf-8')).decode('utf-8')

headers = {
    'Content-Type': 'application/json',
    'Authorization': f'Basic {auth_token}',
    'App-Token': APPTOKEN
}

response = requests.get(f"{APIURL}/initSession", headers=headers)

if response.status_code == 200:
    session_token = response.json().get('session_token')
else:
    print(f"Erreur d'authentification : {response.status_code}")
    exit()

# 2- Récupérer la liste des ordinateurs
headers = {
    'Content-Type': 'application/json',
    'Session-Token': session_token,
    'App-Token': APPTOKEN
}

response = requests.get(f"{APIURL}/Computer", headers=headers)

if response.status_code == 200:
    computers = response.json()
    print("Liste des ordinateurs récupérée: ")
    
    for computer in computers:
        print(computer.get('name'))
else:
    print(f"Erreur de récupération des ordinateurs : {response.status_code}")

```

![alt text](image-2.png)

## - Inventaire dynamique

Dans cette partie, j'ai modifié le script précédant pour qu'il joue le rôle d'in script d'inventaire, l'API de GLPI doit servir de source d'inventaire à Ansible. 

J'ai modifié le code afin qu'il produise la sortie suivante, comptabile avec Ansible :

voici le code modifié : 

```python 
import requests
import base64
import json

user = "glpi"
password = "tprli"
APPTOKEN = "utIjN6j9JMsPiaqsfUOFd4xyH5H4OsTlMICriKnZ"
APIURL = "http://192.168.57.98/glpi/apirest.php"

# 1- Authentification
auth_token = base64.b64encode(f"{user}:{password}".encode('utf-8')).decode('utf-8')

headers = {
    'Content-Type': 'application/json',
    'Authorization': f'Basic {auth_token}',
    'App-Token': APPTOKEN
}

response = requests.get(f"{APIURL}/initSession", headers=headers)

if response.status_code == 200:
    session_token = response.json().get('session_token')   
else:
    print(f"Erreur d'authentification : {response.status_code}")
    exit()

# 2- Récupérer la liste des ordinateurs
headers = {
    'Content-Type': 'application/json',
    'Session-Token': session_token,
    'App-Token': APPTOKEN
}

response = requests.get(f"{APIURL}/Computer", headers=headers)

if response.status_code == 200:
    computers = response.json()
    inventory = {
        "all": {
            "hosts": [computer.get('name') for computer in computers]
        }
    }
    
    print(json.dumps(inventory, indent=4))
else:
    print(f"Erreur de récupération des ordinateurs : {response.status_code}")
```

![alt text](image-3.png)

Malheureusement j'ai dû faire ce script en shell, car je n'arrivais pas à installer pip sur la machine ops.

J'ai donc transformé ce script en shell : 

```sh
#!/bin/sh

USER="glpi"
PASSWORD="tprli"
APPTOKEN="utIjN6j9JMsPiaqsfUOFd4xyH5H4OsTlMICriKnZ"
APIURL="http://localhost/glpi/apirest.php"

# 1- Authentification
AUTH_TOKEN=$(echo -n "$USER:$PASSWORD" | base64)

response=$(curl -s -w "%{http_code}" -o response.json -X GET "$APIURL/initSession" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $AUTH_TOKEN" \
  -H "App-Token: $APPTOKEN")

if [ "$response" -eq 200 ]; then
  session_token=$(jq -r '.session_token' response.json)
else
  echo "Erreur d'authentification : $response"
  exit 1
fi

# 2- Requete pour récupérer les ordinateurs
response=$(curl -s -w "%{http_code}" -o response.json -X GET "$APIURL/Computer" \
  -H "Content-Type: application/json" \
  -H "Session-Token: $session_token" \
  -H "App-Token: $APPTOKEN")

if [ "$response" -eq 200 ]; then
  computers=$(jq -r '.[].name' response.json)
  
  inventory="{\"all\": {\"hosts\": ["
  
  first=1
  for computer in $computers; do
    if [ $first -eq 1 ]; then
      first=0
    else
      inventory="$inventory,"
    fi
    inventory="$inventory\"$computer\""
  done

  inventory="$inventory]}}"
  
  echo "$inventory" | jq .
else
  echo "Erreur de récupération des ordinateurs : $response"
  exit 1
fi
```

Ensuite j'ai ajouté les permissions d'exécution pour le script :

```bash
chmod +x script_ansible.sh
```

Juste après, je l'ai testé avec la commande suivante :

```bash
ansible -i script_ansible.sh -m ping all
pc3 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
pc1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
pc2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

![alt text](image-4.png)

## - Supervision avec Nagios



