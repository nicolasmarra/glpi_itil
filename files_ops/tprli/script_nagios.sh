#!/bin/sh

USER="glpi"
PASSWORD="tprli"
APPTOKEN="utIjN6j9JMsPiaqsfUOFd4xyH5H4OsTlMICriKnZ"
APIURL="http://192.168.57.98/glpi/apirest.php"

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

    # 3- Création du fichier de configuration Nagios pour chaque machine
    config_file="/etc/nagios4/objects/pc.cfg"

    echo "define host{" >> "$config_file"
    echo "    use linux-server" >> "$config_file"
    echo "    host_name $computer" >> "$config_file"
    echo "    check_interval 1" >> "$config_file"
    echo "}" >> "$config_file"
    
  done

  inventory="$inventory]}}"
  
  echo "$inventory" | jq .
else
  echo "Erreur de récupération des ordinateurs : $response"
  exit 1
fi

