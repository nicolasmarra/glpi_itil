user=glpi ; password=glpi ; authtoken=$(echo -n "$user:$password" | base64)
APPTOKEN='0pT7enJY2P4RkIOmbFXozuANsAnrZ9yBAUw2g5UI'
APIURL='http://localhost/glpi/apirest.php'
curl -s -X GET \
-H 'Content-Type: application/json' -H "Authorization: Basic $authtoken" \
-H "App-Token: $APPTOKEN" "$APIURL/initSession"



