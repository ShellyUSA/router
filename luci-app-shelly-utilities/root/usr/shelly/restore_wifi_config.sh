#!/bin/bash
#Shelly bash auto provision script fix poor exit
#This program restores default wifi config settings 
#from a bad exit, i.e. stopping shelly auto provision mid provisioning

#V1.0.0 DBarba 202304xx cleans up poor exits
#V1.0.1 DBarba 20230518 fixing wifi interuption with targetted interface reset to shelly interface only
#v2.0.0 DBarba 20230519 replaces sed commands with UCI RPC properly check if script needs poor exit fix
#V2.0.2 DBarba 20230523 Refactored rm -r commands to only delete with sed cmds, leaving thme in place but still clearing them

  echo "Defaulting radio to default shelly interface(if needed)..."
      
      if [ -z "$(cat /usr/shelly/config_needs_reset)" ]; then

        echo "EXIT"
        echo "Not needed!"

      else 

        #bring in default_wifi.json, must live in this directory
        wifijson=$(cat /usr/shelly/default_shelly_interface.json)

        #Extract the values of the interface being used and it's parameters for provisioning
        WIFI_IFACE=$(echo "$wifijson" | jq -r '.WIFI_IFACE')
        IFNAME=$(echo "$wifijson" | jq -r '.IFNAME')
        DEVICE=$(echo "$wifijson" | jq -r '.DEVICE')
        NETWORK=$(echo "$wifijson" | jq -r '.NETWORK')
        MODE=$(echo "$wifijson" | jq -r '.MODE')
        SSID=$(echo "$wifijson" | jq -r '.SSID')
        ENCRYPTION=$(echo "$wifijson" | jq -r '.ENCRYPTION')
        #KEY=$(echo "$wifijson" | jq -r '.KEY')

        echo "Returning default config..." 
        random_key=$RANDOM$RANDOM$RANDOM$RANDOM
        # uci set wireless.$WIFI_IFACE.ifname=$IFNAME
        uci set wireless.$WIFI_IFACE.device=$DEVICE
        uci set wireless.$WIFI_IFACE.network=$NETWORK
        uci set wireless.$WIFI_IFACE.mode=$MODE
        uci set wireless.$WIFI_IFACE.ssid=$SSID
        uci set wireless.$WIFI_IFACE.encryption=$ENCRYPTION
        uci set wireless.$WIFI_IFACE.key=$random_key
        uci commit wireless
     
        #clear config_needs_reset
        sed -i '1,$d' /usr/shelly/config_needs_reset

        #clear provision_queue
        sed -i '1,$d' /tmp/provision_queue

        echo "Reloading wifi..."
        wifi reload
  
        echo "EXIT"
        echo "Success!"
 
  fi
