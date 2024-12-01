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
