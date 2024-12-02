#!/bin/bash

USER="glpi"
PASSWORD="tprli"
APPTOKEN="utIjN6j9JMsPiaqsfUOFd4xyH5H4OsTlMICriKnZ"
APIURL="http://localhost/glpi/apirest.php"

# 1- Authentification avec l'API
AUTH_TOKEN=$(echo -n "$USER:$PASSWORD" | base64)

response=$(curl -s -w "%{http_code}" -o response.json -X GET "$APIURL/initSession" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $AUTH_TOKEN" \
  -H "App-Token: $APPTOKEN")

if [ "$response" -ne 200 ]; then
  echo "Erreur d'authentification : $response"
  exit 1
fi

session_token=$(jq -r '.session_token' response.json)

# 2- Requête pour récupérer la liste des ordinateurs
response=$(curl -s -w "%{http_code}" -o response.json -X GET "$APIURL/Computer" \
  -H "Content-Type: application/json" \
  -H "Session-Token: $session_token" \
  -H "App-Token: $APPTOKEN")

if [ "$response" -ne 200 ]; then
  echo "Erreur de récupération des ordinateurs : $response"
  exit 1
fi

computers=$(jq -r '.[].name' response.json)

echo "[pcs]"
for computer in $computers; do
  echo "$computer"
done

