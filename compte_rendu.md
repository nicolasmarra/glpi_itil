# TP4 - Nicolas MARRA (3A - RIO)

## 1. Introduction 

Après avoir téléchargé la machine virtuelle, la connexion à la machine **ops** s'est effectuée via SSH à l'aide de la commande suivante : 
 

```bash 
ssh tprli@192.168.57.98
```


J'ai ensuite vérifié l'accès à **GLPI** en utilisant l'URL suivante :  

```http
http://192.168.57.98/glpi/
```

Les identifiants utilisés pour se connecter à GLPI sont :  
**Utilisateur :** `glpi`  
**Mot de passe :** `tprli`


Pour permettre à la machine **ops** d'accéder à Internet, j'ai configuré les règles **iptables** suivantes (script disponible Moodle fourni par l'enseignant) : 

```bash
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -j MASQUERADE  
iptables -t nat -A POSTROUTING -s 192.168.56.0/24 -j MASQUERADE  
iptables -t nat -A POSTROUTING -s 192.168.57.0/24 -j MASQUERADE  

echo 1 > /proc/sys/net/ipv4/ip_forward
```

## 2. Installation de l'agent fusioninventory

Pour cette partie, j'ai utilisé un **playbook Ansible** afin de déployer et configurer l'agent **FusionInventory** sur trois machines (pc1, pc2, pc3).

### 2.1 Configuration d'Ansible

Dans un premier temps, j'ai configuré Ansible en modifiant le fichier `/home/tprli/.ansible.cfg` pour ignorer les vérifications des clés SSH et utiliser **root** comme utilisateur par défaut :  

```cfg
[defaults]
host_key_checking = False
remote_user = root
inventory = /home/tprli/hosts
```

J'ai aussi créé un fichier d'inventaire `inventory.ini`, où j'ai listé les machines cibles :  


```ini
[pcs]
pc1
pc2
pc3
```

### 2.2 Déploiement de l'agent FusionInventory

Le déploiement de l'agent a été réalisé grâce au fichier `fusioninventory.yml`(**playbook**) suivant :  

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
---

### 2.3 Résolution des problèmes 

Avant d'exécuter le **playbook**, je devais me connecter manuellement à chaque machine (pc1, pc2, pc3) pour lancer la commande `apt update`. Afin d'automatiser cette tâche, j'ai ajouté une commande de mise à jour du système dans le **playbook**, permettant ainsi d'éviter toute intervention manuelle.  

### 2.4 Vérification dans GLPI 


Après l'installation et la configuration de l'agent, j'ai vérifié que les machines étaient correctement ajoutées à l'inventaire de GLPI. Pour cela, je me suis rendu à l'URL suivante :  

```http
http://192.168.57.98/glpi/plugins/fusioninventory/front/menu.php
```
Voici une illustration de l'inventaire GLPI :  

![Illustration de l'inventaire GLPI](/images/image-1.png)


## 3. Utilisation de l'API de GLPI


Dans cette partie, l'objectif est d'utiliser l'API proposée par **GLPI** pour accéder aux données de l'inventaire. L'accès à cette API se fait en deux étapes :  
1. **Authentification**  
2. **Requête à l'API**  


Un script en Python a été écrit pour effectuer ces deux étapes et renvoyer la liste de tous les ordinateurs enregistrés dans la base d'inventaire.

### 3.1 Obtention de l'APPTOKEN

Pour interagir avec l'API, un **client API** a été créé dans GLPI, qui génère une clé **APPTOKEN**. Cette clé est utilisée pour s'authentifier et accéder à l'API.  


Le token généré est :  

```bash
utIjN6j9JMsPiaqsfUOFd4xyH5H4OsTlMICriKnZ
```

En complément, l'identifiant utilisateur (`glpi`) et le mot de passe (`tprli`) utilisés pour l'accès au dashboard GLPI sont aussi requis pour l'authentification.


### 3.2 Script Python

Ce script permet :  
1. De s'authentifier à l'API GLPI.  
2. De récupérer la liste des ordinateurs présents dans l'inventaire. 

(Cliquez ici pour voir le script : [script.py](/script.py))

Le script a permis de récupérer la liste des ordinateurs présents dans l'inventaire GLPI. Voici un aperçu des résultats affichés :  


![Illustration des résultats obtenus avec l'API GLPI](/images/image-2.png)

## 4. Inventaire dynamique

Dans cette partie, j'ai modifié le script précédant pour qu'il joue le rôle d'in script d'inventaire, l'API de GLPI doit servir de source d'inventaire à Ansible. 

Dans cette partie, l'objectif est de modifier le script Python précédent pour qu'il génère un inventaire compatible avec **Ansible**, en utilisant l'API de GLPI comme source d'inventaire dynamique.

### 4.1 Script Python modifié

Le script Python a été adapté afin de produire une sortie JSON conforme au format attendu par Ansible. 

**Lien vers le script complet :** [script_ansible.py](/script_ansible.py)

Le script produit une sortie JSON de ce type :

![Sortie produite par le Script Python](/images/image-3.png)

---

### 4.2 Script Shell alternatif

En raison de contraintes sur la machine ops (notamment l'impossibilité d'installer `pip` pour ajouter la bibliothèque `requests`), un script en **Shell** a été créé pour générer un inventaire équivalent.  

**Lien vers le script complet :** [script_ansible.sh](/script_ansible.sh)

> **Remarque** : Avec `apt`, il aurait été possible d’installer la bibliothèque `requests` sans utiliser `pip`, ce qui aurait permis de maintenir la version Python du script. 

---

### 4.3 Permissions et exécution du script

Après création, les permissions d'exécution ont été ajoutées au script Shell avec la commande suivante :  

```bash
chmod +x script_ansible.sh
```

Le script a ensuite été utilisé comme inventaire dynamique pour Ansible via la commande :  

```bash
ansible -i script_ansible.sh -m ping all
```

Résultats : 

```bash
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
---

![Illustration de l'inventaire dynamique  avec le script](/images/image-4.png)


## 5. Supervision avec Nagios

L'objectif est de surveiller les machines à l'aide de **Nagios**, qui a été préinstallé sur la machine **ops**.

### 5.1 Configuration des hôtes

Pour surveiller les machines, il est nécessaire de créer un fichier de configuration `pc.cfg` dans le répertoire `/etc/nagios4/objects/` pour chaque machine de l'inventaire. Ce fichier doit respecter le format suivant :


```cfg
define host{
 use linux-server
 host_name pc1
 check_interval 1
 }
 ```

### 5.2 Script Shell pour la génération des fichiers de configuration

Afin de générer ce fichier pour toutes les machines, j'ai adapté le script Shell précédent. Le script **script_nagios.sh** permet de créer automatiquement les fichiers de configuration pour chaque machine à partir des informations récupérées via l'API de GLPI :


**Lien vers le script  :** [script_nagios.sh](/script_nagios.sh)


Ce script génère le fichier `pc.cfg` dans le répertoire `/etc/nagios4/objects/`, contenant les informations de toutes les machines.

Ce script créé le fichier pc.cfg dans le /etc/nagios4/objects, le fichier contient donc toutes les machines.

![Fichier de configuration Nagios généré par le script](/images/image-5.png)


### 5.3 Activation et configuration dans Nagios

Une fois le fichier de configuration généré, il a été ajouté dans les fichiers de configuration de Nagios pour qu'il soit pris en compte lors du redémarrage du service. J'ai ajouté la ligne suivante dans le fichier `/etc/nagios4/nagios.cfg` :

```bash
#Definitions for monitoring our pcs 
cfg_file=/etc/nagios4/objects/pc.cfg
```

![Ajout du fichier pc.cfg au fichier de configuration](/images/image-6.png)

Ensuite, j'ai relancé le service **Nagios** avec la commande suivante :

```bash
sudo systemctl restart nagios4
```
Les machines sont désormais visibles dans la liste des hôtes de l'interface Nagios.

On peut voir que les machines sont visibles sur la liste des hosts de l'interface de Nagios.

![Liste des hôtes dans Nagios](/images/image-7.png)


### 5.4 Vérification de la détection des changements d'état


Pour tester la détection des changements d'état dans Nagios, j'ai arrêté les machines **pc2** et **pc3** :

```bash
root@deb:~# lxc-ls --running
dhcp fw1  ns   ops  pc1  pc2  pc3  srv3 
root@deb:~# lxc-stop pc3
root@deb:~# lxc-stop pc2
root@deb:~# lxc-ls --running
dhcp fw1  ns   ops  pc1  srv3 
```

![Arrêt des machines pc2 et pc3](/images/image-8.png)

Les machines **pc2** et **pc3** sont maintenant détectées comme **DOWN** dans l'interface de Nagios :

![Machines détectées comme DOWN](/images/image-9.png)

### 5.5 Restauration de l'état des machines

Après avoir redémarré les machines **pc2** et **pc3**, elles sont de nouveau détectées comme étant **ON** dans Nagios :


```bash
root@deb:~# lxc-start pc3
root@deb:~# lxc-start pc2
root@deb:~# lxc-ls --running
dhcp fw1  ns   ops  pc1  pc2  pc3  srv3 
```

![Machines détectées comme ON](/images/image-10.png)

## 6. Check Nagios

Dans cette section, nous allons ajouter un service permettant de vérifier si le service SMTP fonctionne sur la machine `ops` en utilisant la commande `check_smtp` dans Nagios.

### 6.1 Ajout de la commande de vérification SMTP**


La première étape a consisté à ajouter la commande `check_smtp` dans le fichier de configuration des commandes Nagios situé à `/etc/nagios4/objects/commands.cfg`. Voici la définition de la commande :  

```bash
define command{
	command_name check_smtp
	command_line /usr/lib/nagios/plugins/check_smtp -H $HOSTADRESS$$
}
```

### 6.2. Création du host dans Nagios


Ensuite, il faut créer un *host* dans Nagios pour superviser le service SMTP. Dans notre cas, le *host* est `localhost`, que nous avons ajouté au fichier `/etc/nagios4/objects/localhost.cfg`. Voici la définition du *host* :  


```bash
define host{
        use                     linux-server            ; Name of host template to use
                                                        ; This host definition will inherit all variables that are defined
                                                        ; in (or inherited by) the linux-server host template definition.
        host_name               localhost
        alias                   localhost
        address                 127.0.0.1
        check_interval          1
        }
```

Le *host* existait déjà, mais j'ai ajouté l'intervalle de vérification avec une valeur de `1`.

### 6.3. Création du service SMTP



Ensuite, nous avons créé un service pour superviser le port SMTP de la machine `ops`. Ce service a été ajouté également dans le fichier `localhost.cfg` situé à `/etc/nagios4/objects/localhost.cfg` :  

```bash
# Define a service to check SMTP on the local machine

define service{
        use                             local-service
        service_description             Verify if SMTP is responding
        host_name                       localhost
        check_interval                  1
        check_command                   check_smtp
}
```

### 6.4. Renommage de la commande

Après avoir vérifié la configuration de Nagios, une erreur a été détectée : il existait déjà une commande nommée `check_smtp`. J'ai donc renommé la commande en `smtp-active` :  

```bash
define command{
        command_name smtp-active
        command_line /usr/lib/nagios/plugins/check_smtp -H $HOSTADRESS$$
}
```

### 6.5. Modification du service

J'ai ensuite mis à jour la configuration du service pour utiliser la nouvelle commande `smtp-active` dans le fichier `localhost.cfg` :  


```bash
# Define a service to check SMTP on the local machine

define service{
        use                             generic-service
        service_description             Verify if SMTP is responding
        host_name                       localhost
        check_interval                  1
        check_command                   smtp-active
}

```

### 6.6. Vérification et correction de la configuration

Après avoir vérifié la configuration de Nagios avec la commande suivante :  


```bash
sudo nagios4 -v /etc/nagios4/nagios.cfg
```

Tout semblait correct, mais il y a eu une petite erreur : j'avais mal écrit la variable `$HOSTADDRESS$` avec un seul `D`. La commande correcte doit être :  


```bash
define command{
        command_name smtp-active
        command_line /usr/lib/nagios/plugins/check_smtp -H $HOSTADDRESS$
}
```


En raison de cette erreur, le service SMTP ne fonctionne

![Service SMTP n'était pas détecté](/images/image-12.png)


### 6.7. Redémarrage du service Nagios


Après avoir corrigé l'erreur, j'ai relancé le service Nagios pour appliquer les modifications :  

```bash
sudo systemctl restart nagios4
```

Une fois la configuration corrigée, j'ai pu vérifier, depuis l'interface de Nagios, que le service SMTP était correctement supervisé. Voici l'état du service dans l'interface de Nagios :  


![Service SMTP fonctionnel - image 1](/images/image-13.png)

![Service SMTP fonctionnel - image 2](/images/image-14.png)


## 7 SNMP

Dans cette section, je vais configurer e SNMP sur chaque machine via Ansible pour vérifier l'état de ces dernières.

### 7.1 Déploiement de l'agent SNMP avec Ansible

Tout d'abord, l'agent SNMP a été déployé sur chaque PC via Ansible et un inventaire dynamique. Le playbook suivant permet d'installer et de configurer SNMP pour écouter sur toutes les interfaces (y compris l'IPv6).


```bash 
- name: Déployer l'agent SNMP
  hosts: pcs
  become: true
  tasks:
  - name: Installer le daemon SNMP
    apt: 
     name: snmpd
     state: present

  - name: Mettre l'agent à l'écoute sur toutes les interfaces
    lineinfile: 
      path: /etc/snmp/snmpd.conf
      regexp: '^agentAddress'
      line: 'agentAddress udp:161,udp6[::1]:161'
 
  - name: Mettre la communité example
    lineinfile: 
      path: /etc/snmp/snmpd.conf
      regexp: '^rocommunity'
      line: 'rocommunity example'
 
  - name: Redémarrer l'agent SNMPD
    service:
      name: snmpd
      state: restarted
```

### 7.2 Modification du playbook et exécution

Lors de l'exécution, j'ai remarqué un problème concernant l'inventaire des hôtes : il était nécessaire de remplacer `hosts` par `pcs` dans le script. J'ai aussi modifié le playbook pour remplacer l'option `hosts` par `all`.

Extrait du playbook modifié pour le déploiement de FusionInventory et de SNMP :


```yml
- name: Déployer l'agent FusionInventory
  hosts: all
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

- name: Déployer l'agent SNMP
  hosts: all
  become: true
  tasks:
  - name: Installer le daemon SNMP
    apt: 
     name: snmpd
     state: present

  - name: Mettre l'agent à l'écoute sur toutes les interfaces
    lineinfile: 
      path: /etc/snmp/snmpd.conf
      regexp: '^agentAddress'
      line: 'agentAddress udp:161,udp6[::1]:161'
 
  - name: Mettre la communité example
    lineinfile: 
      path: /etc/snmp/snmpd.conf
      regexp: '^rocommunity'
      line: 'rocommunity example'
 
  - name: Redémarrer l'agent SNMPD
    service:
      name: snmpd
```

Le playbook a été exécuté sans erreurs, et les étapes suivantes ont été réalisées sur chaque machine :

```bash
ansible-playbook -i script_ansible.sh fusioninventory.yml 
```


### 7.3 Vérification du statut de SNMP

Une fois le playbook terminé, j'ai vérifié le statut de l'agent SNMP via la commande suivante :


```bash
systemctl status snmpd
```


Cependant, une erreur liée à IPv6 est apparue. Pour résoudre cela, j'ai modifié la configuration pour que l'agent SNMP écoute uniquement sur les interfaces IPv4 :

**Lien vers le playbook complet :** [fusioninventory.yml](/files_ops/fusioninventory.yml)


```yml
- name: Déployer l'agent FusionInventory et SNMP
  hosts: all
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

  - name: Installer le daemon SNMP
    apt: 
     name: snmpd
     state: present

  - name: Mettre l'agent à l'écoute sur toutes les interfaces (IPv4 uniquement)
    lineinfile: 
      path: /etc/snmp/snmpd.conf
      regexp: '^agentAddress'
      line: 'agentAddress udp:161'
 
  - name: Mettre la communité example
    lineinfile: 
      path: /etc/snmp/snmpd.conf
      regexp: '^rocommunity'
      line: 'rocommunity example'
 
  - name: Redémarrer l'agent SNMPD
    service:
      name: snmpd
      state: restarted
```

Une fois cette modification effectuée, l'agent SNMP a été redémarré et fonctionne correctement sur toutes les machines.


En vérifiant le status de snmpd, c'est possible de constater qu'il est activé sur toutes les machines.

![Status de SNMPD](/images/image-15.png)


Ensuite, il  a fallu  déterminer l'OID numérique complet de la variable hrSystemProcesses (groupe hrSystem) de la MIB 'HOST-RESOURCES-MIB' sur la RFC-2790

L'OID numérique complet de la variable `hrSystemProcesses` est `1.3.6.1.2.1.25.1.6.0`. Voici la signification de chaque composant :

- `1.3.6.1` : Correspond à l'ISO, l'organisation DOD (Department of Defense) et l'internet.
- `1.3.6.1.2.1.25` : Le chemin dans l'hiérarchie des OIDs pour atteindre `HOST-RESOURCES-MIB`.



J'ai utilisé la commande suivante pour interroger la variable hrSystemProcesses avec SNMP sur pc1:

```bash
nmpget -v2c -c public pc1 .1.3.6.1.2.1.25.1.6.0
HOST-RESOURCES-MIB::hrSystemProcesses.0 = Gauge32: 10
tprli@ops:~$ snmpget -v2c -c example pc1 .1.3.6.1.2.1.25.1.6.0
HOST-RESOURCES-MIB::hrSystemProcesses.0 = Gauge32: 10
```


## 8. Check SNMP dans Nagios

Cette section couvre deux étapes principales pour configurer la supervision SNMP du processus sleep dans Nagios.

---

### 8.1. Configuration de l'agent SNMP pour détecter le processus `sleep`

Pour que l'agent SNMP puisse surveiller le processus `sleep`, une modification de la configuration SNMP a été intégrée dans un playbook Ansible. La tâche suivante configure l'agent pour écouter sur l'adresse IP `0.0.0.0` au port UDP `161`, définit une communauté `example` en mode lecture seule, et ajoute une directive `proc` pour surveiller le processus `sleep` :


**Lien vers le playbook complet :** [fusioninventory.yml](/files_ops/fusioninventory.yml)

```yml
  - name: Détecter les processus sleep
    copy:
      dest: /etc/snmp/snmpd.conf
      content: |
        agentAddress udp:0.0.0.0:161
        rocommunity example default
        proc sleep
      owner: root
      group: root
```

Une fois la configuration modifiée, le service SNMPD a été redémarré avec Ansible :

```bash
ansible-playbook -i script_ansible.sh fusioninventory.yml 
```

Pour vérifier que la configuration fonctionne, deux commandes ont été exécutées pour interroger l'agent SNMP sur la machine `pc1` :

```bash
snmpwalk -v2c -c example pc1 UCD-SNMP-MIB::prTable
snmptable -v2c -c example pc1 UCD-SNMP-MIB::prTable
```


```bash
snmpwalk -v2c -c example pc1 UCD-SNMP-MIB::prTable
UCD-SNMP-MIB::prIndex.1 = INTEGER: 1
UCD-SNMP-MIB::prNames.1 = STRING: sleep
UCD-SNMP-MIB::prMin.1 = INTEGER: 1
UCD-SNMP-MIB::prMax.1 = INTEGER: 0
UCD-SNMP-MIB::prCount.1 = INTEGER: 1
UCD-SNMP-MIB::prErrorFlag.1 = INTEGER: noError(0)
UCD-SNMP-MIB::prErrMessage.1 = STRING: 
UCD-SNMP-MIB::prErrFix.1 = INTEGER: noError(0)
UCD-SNMP-MIB::prErrFixCmd.1 = STRING: 
```


En complément, la commande `snmptable` affiche une table SNMP structurée :

```bash
tprli@ops:~$ snmptable -v2c -c example pc1 UCD-SNMP-MIB::prTable
SNMP table: UCD-SNMP-MIB::prTable

 prIndex prNames prMin prMax prCount prErrorFlag prErrMessage prErrFix prErrFixCmd
       1   sleep     1     0       1     noError               noError
```

Ces résultats montrent que la configuration est fonctionnelle. 

###  8.2. Création d’un service de supervision dans Nagios

L’objectif ici est de configurer un service dans Nagios pour vérifier le nombre d’occurrences du processus `sleep`. Une alerte doit se déclencher lorsque ce nombre dépasse un seuil de 10.

#### - Ajout d’un hostgroup

Dans le fichier `/etc/nagios4/objects/localhost.cfg`, un groupe d’hôtes `pcs` a été défini pour regrouper plusieurs machines supervisées :

```bash
define hostgroup{
        hostgroup_name pcs
        alias           All PCs
        members         pc1, pc2, pc3
}
```

#### - Définition du service

Dans le même fichier, un service a été ajouté pour surveiller les processus `sleep` :

```bash
define service{
	use                             generic-service
	hostgroup_name			            pcs
	service_description		          Sleep Process Check
	check_command			              check-snmp-processes!example!1!10
}

```

#### - Création de la commande


Une commande personnalisée `check-snmp-processes` a été définie dans `/etc/nagios4/objects/commands.cfg` :


```bash
define command{
        command_name check-snmp-processes
        command_line $USER1$/check_snmp -H $HOSTADDRESS$ -C $ARG1$ -o UCD-SNMP-MIB::prCount.$ARG2$ -w $ARG3$
}
```
#### - Vérification et redémarrage**

Pour vérifier la configuration, la commande suivante a été exécutée :

```bash
sudo nagios4 -v /etc/nagios4/nagios.cfg
```

Après vérification , le service Nagios a été redémarré :

```bash
sudo systemctl restart nagios4
```


#### - Test sur l’interface web


Sur l’interface Nagios, le service de supervision est disponible.

![Interface Nagios - Exemple 1](/images/image-18.png)
![Interface Nagios - Exemple 2](/images/image-19.png)


Pour vérifier que tout marche vraiment,  15 processus `sleep` ont été lancés en tâche de fond sur la machine `pc1` :



```bash
for i in {1..15}; do sleep 1000 & done
[1] 19888
[2] 19889
[3] 19890
[4] 19891
[5] 19892
[6] 19893
[7] 19894
[8] 19895
[9] 19896
[10] 19897
[11] 19898
[12] 19899
[13] 19900
[14] 19901
[15] 19902
```

Une fois cela fait, une interrogation de l’agent SNMP confirme que le compteur est bien à 16 :


```bash
snmpwalk -v2c -c example pc1 UCD-SNMP-MIB::prTable
UCD-SNMP-MIB::prIndex.1 = INTEGER: 1
UCD-SNMP-MIB::prNames.1 = STRING: sleep
UCD-SNMP-MIB::prMin.1 = INTEGER: 1
UCD-SNMP-MIB::prMax.1 = INTEGER: 0
UCD-SNMP-MIB::prCount.1 = INTEGER: 16
UCD-SNMP-MIB::prErrorFlag.1 = INTEGER: noError(0)
UCD-SNMP-MIB::prErrMessage.1 = STRING: 
UCD-SNMP-MIB::prErrFix.1 = INTEGER: noError(0)
UCD-SNMP-MIB::prErrFixCmd.1 = STRING:
```
La variable `UCD-SNMP-MIB::prCount.1 = INTEGER: 16` montre que le compteur est à 16.

Pour garantir un suivi en temps réel, un intervalle de vérification de 1 minute a été ajouté au service Nagios :


```bash
check_interval 1
```

Suite à ces modifications, une alerte s’est déclenchée pour la machine `pc1`, visible dans l’interface Nagios :

![Alerte Nagios - Exemple 1](/images/image-20.png)
![Alerte Nagios - Exemple 2](/images/image-21.png)

--- 

La supervision SNMP du processus `sleep` a été configurée  dans Nagios. 