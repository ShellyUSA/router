#!/bin/bash
#Shelly bash auto provision script
#Gen 1 & 2 compatible

#Gen 2 devices are fully provisioned in one successful pass 
#with a final AP close call

#NOTE: GEN 1 Disables AP after WIFI config API call [DB20230520- and successfull connection]
#sometimes the device does not register the enable parameter
#and will require two passes, this inheritently fixes itself

#V1.0.0 DBarba 20230412 Gen1 provisioning 
#V2.0.0 DBarba 20230414 Gen2 provisioning added
#V2.0.1 DBarba 20230414 bug fix: Gen2 provision causes internet connectivity lost
#V2.0.2 DBarba 20230428 refactor: better sed editing of /etc/config/wireless config file
#V3.0.0 DBarba 20230428 proper temp file saving config in poor exit, clean up script made (restore_wifi_config.sh)
#V3.0.1 DBarba 202305xx loop runs through all current available devices and other small refactors
#V3.0.2 DBarba 20230517 refactoring sed to uci RPC and proper exiting with new config set method, deprecate gen1 wifi check final
#V3.1.0 DBarba 20230522 new scanning tool (tool 2 method, tool 1 was iw dec <interface> scan ) and better configuration refresh tool
#V3.0.2 DBarba 20230523 Refactored rm -r commands to only delete with sed cmds, leaving thme in place but still clearing them

#pipe all stdout/stderr to log file
#comment out to see response in local terminal
exec >> /usr/shelly/scan_wifi.log 2>&1

#Delay between API and other commands
delay=1

echo "scan_wifi is initializing..."

#bring in config.json, must live in this directory
json=$(cat /usr/shelly/config.json)

#Extract the values of the "server", "ssid", "username", and "password" keys
ROUTER_SSID=$(echo "$json" | jq -r '.ROUTER_SSID')
ROUTER_PASS=$(echo "$json" | jq -r '.ROUTER_PASS')
MQTT_USER=$(echo "$json" | jq -r '.MQTT_USER')
MQTT_PASS=$(echo "$json" | jq -r '.MQTT_PASS')
MQTT_SERVER=$(echo "$json" | jq -r '.MQTT_SERVER')
MQTT_PROVISION=$(echo "$json" | jq -r '.MQTT_PROVISION')

# Your provision config files
# echo "Parameters from file (config.json)"
# echo "ROUTER_SSID: $ROUTER_SSID"
# echo "ROUTER_PASS: $ROUTER_PASS"
# echo "MQTT_USER: $MQTT_USER"
# echo "MQTT_PASS: $MQTT_PASS"
# echo "MQTT_SERVER: $MQTT_SERVER"
# echo "MQTT_PROVISION: $MQTT_PROVISION"

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

# Your wifi config files
# echo "Parameters from file (default_shelly_interface.json)"
# echo "WIFI_IFACE: $WIFI_IFACE"
# echo "IFNAME: $IFNAME"
# echo "DEVICE: $DEVICE"
# echo "NETWORK: $NETWORK"
# echo "MODE: $MODE"
# echo "SSID: $SSID"
# echo "ENCRYPTION: $ENCRYPTION"
# echo "KEY: $KEY"

echo "scan_wifi is monitoring..."

#infinite loop script always searching and provisioning
while true; do

  #Search for possible shelly devices and save to queue if found

  #Tool 2 method
  iwlist $IFNAME scan | grep -i "shelly" > /tmp/provision_queue
  
  #runs script for each SSID that is stored in /tmp/provision_queue
  while read shelly_device; do

    echo "ENTER SCRIPT"

    #display devices detected
    echo "Devices detected(list):"
    echo $(cat /tmp/provision_queue)

    #marks yes to reset wifi config for EXIT and in case of user/software/power interruptions
    echo "YES" > /usr/shelly/config_needs_reset
   
    #-------------------determine device GEN 1/2 (Tool 2 method)----------------------
    #Parse out only SSID
    shelly_ssid=$(echo "$shelly_device" | sed 's/.*"\(.*\)".*/\1/')

    #Check if GEN 1
    if echo "$shelly_ssid" | grep "shelly";  then
      echo "GEN 1 detected!"
    fi
    #Check if GEN 2
    if echo "$shelly_ssid" | grep "Shelly";  then
      echo "GEN 2 detected!"
    fi

    #-----Pass into SCRIPT if a Gen 1 or 2 device is detected---------
    if echo "$shelly_ssid" | grep -qi "shelly";  then
      
      while true
      do
          echo "Initializing script for $shelly_ssid on $IFNAME..."

          echo "Setting wifi config for provisioning..."

          # uci set wireless.$WIFI_IFACE.ifname=$IFNAME
          # uci set wireless.$WIFI_IFACE.device=$DEVICE
          uci set wireless.$WIFI_IFACE.network='wwan'
          uci set wireless.$WIFI_IFACE.mode='sta'
          uci set wireless.$WIFI_IFACE.ssid=$shelly_ssid
          uci set wireless.$WIFI_IFACE.encryption='none'
          uci set wireless.$WIFI_IFACE.key=''

          #commit settings for provisioning interface
          uci commit wireless

          echo "Reloading wifi..."
          wifi reload
          sleep 3

          echo "Requesting IPv4 lease and host IP..."
          udhcpc -i $IFNAME

          #-----------------------GEN 1 API calls----------------------------

          echo "Testing for GEN1 device..."
          checkForGEN1=$(curl --max-time 3 http://192.168.33.1/settings)    

      if echo "$checkForGEN1" | grep -qi "$shelly_ssid"; then

        #--------------------GEN 1 SET MQTT CONFIG API CALL---------------------
        if echo "$MQTT_PROVISION" | grep -qi "true";  then
          echo "GEN1 Setting MQTT config..."
          curl -X POST --max-time 1 --silent --output /dev/null http://192.168.33.1/settings?mqtt_server=$MQTT_SERVER\&mqtt_user=$MQTT_USER\&mqtt_pass=$MQTT_PASS\&mqtt_enable=1
          sleep $delay

          echo "GEN1 CONFIRMING MQTT config..."
          confirmGEN1Mqtt=$(curl --max-time 5 http://192.168.33.1/settings)
          
          if echo "$confirmGEN1Mqtt" | grep -q "$MQTT_SERVER"; then
            echo "MQTT SERVER: OK!"
            if echo "$confirmGEN1Mqtt" | grep -q "$MQTT_USER"; then
              echo "MQTT USER: OK!"
            else 
              echo "MQTT USER: Not set..." 
              break
            fi
          else
            echo "MQTT SERVER: Not set..."
            break
          fi

        fi 

        #--------------------GEN 1 CHECK WIFI CONFIG API CALL---------------------
        echo "GEN1 CHECKING current WIFI config..."
        checkGEN1Wifi=$(curl --max-time 5 http://192.168.33.1/settings/sta)
        
        if echo "$checkGEN1Wifi" | grep -q "$ROUTER_SSID"; then
          echo "WIFI SSID: OK!"
          if echo "$checkGEN1Wifi" | grep -qi "$ROUTER_PASS"; then
            echo "WIFI PASS: OK!"
            echo "Note: GEN 1 needs to connect to wifi to shut off AP"
            echo "shut off $shelly_ssid and turn on after script EXITS"
            break
          else 
            echo "WIFI PASS: Not set..."
          fi
        else
          echo "WIFI SSID: Not set..."
        fi

        #--------------------GEN 1 SET WIFI CONFIG API CALL---------------------
        echo "GEN1 Setting WIFI config..."
        curl -X POST --max-time 1 --silent --output /dev/null http://192.168.33.1/settings/sta?ssid=$ROUTER_SSID\&enabled=1\&key=$ROUTER_PASS

        #--------------------GEN 1 CHECK WIFI CONFIG API CALL---------------------
        echo "OK!"
        #deprecated - not useful/functional
        #GEN 1 auto shuts off AP when connected to a wifi AP

        #--------------------GEN 1 SHUT OFF API CALL---------------------
                      #deprecated - not needed
        break
      else
        echo "GEN1 API timed out: Testing for GEN2 device..."
      fi
        
          #------------------------------------GEN 2 API calls----------------------------------

          #--------------------GEN 2 SET MQTT CONFIG API CALL---------------------
          if echo "$MQTT_PROVISION" | grep -qi "true";  then
              echo "GEN 2 Setting MQTT config..."
              checkGEN2Mqtt=$(curl --max-time 5 -X POST -d "{\"id\":1,\"method\":\"MQTT.SetConfig\",\"params\":{\"config\":{\"enable\":true,\"server\":\"$MQTT_SERVER\",\"user\":\"$MQTT_USER\",\"pass\":\"$MQTT_PASS\"}}}" http://192.168.33.1/rpc)
              
              if echo "$checkGEN2Mqtt" | grep -q "shelly"; then
                echo "OK!"
              else
                break
              fi
          fi

          #--------------------GEN 2 SET WIFI CONFIG API CALL---------------------
          echo "GEN2 Setting WIFI config..."
          checkGEN2Wifi=$(curl --max-time 5 -X POST -d "{\"id\":1,\"method\":\"WiFi.SetConfig\",\"params\":{\"config\":{\"sta\":{\"ssid\":\"$ROUTER_SSID\",\"pass\":\"$ROUTER_PASS\",\"enable\":true}}}}" http://192.168.33.1/rpc)
          
          if echo "$checkGEN2Wifi" | grep -q "shelly"; then
            echo "OK!"
          else
            break
          fi

          #--------------------GEN 2 SHUT OFF AP API CALL---------------------
          echo "Shut off AP..."
          checkGEN2Exit=$(curl --max-time 5 -X POST -d "{\"id\":1,\"method\":\"WiFi.SetConfig\",\"params\":{\"config\":{\"ap\":{\"is_open\":false,\"enable\":false}}}}" http://192.168.33.1/rpc)
          
          if echo "$checkGEN2Exit" | grep -q "shelly"; then
            echo "OK!"
          else
            break
          fi

      break
      done 

    else 
      echo "*SSID* *$shelly_ssid* was determined to not be a shelly device..."
    fi

    #end of script for one device
  done < /tmp/provision_queue 
    
    if [ -z "$(cat /usr/shelly/config_needs_reset)" ]; then
      sleep 0
    else 
      echo "EXIT"
      
      echo "Returning to default wifi config..." 

      #produces a random key for the default interface
      random_key=$RANDOM$RANDOM$RANDOM$RANDOM

      # uci set wireless.$WIFI_IFACE.ifname=$IFNAME
      # uci set wireless.$WIFI_IFACE.device=$DEVICE
      uci set wireless.$WIFI_IFACE.network=$NETWORK
      uci set wireless.$WIFI_IFACE.mode=$MODE
      uci set wireless.$WIFI_IFACE.ssid=$SSID
      uci set wireless.$WIFI_IFACE.encryption=$ENCRYPTION
      uci set wireless.$WIFI_IFACE.key=$random_key

      #commit settings for default wifi configuration
      uci commit wireless

      #clear config_needs_reset
      sed -i '1,$d' /usr/shelly/config_needs_reset

      #clear provision_queue
      sed -i '1,$d' /tmp/provision_queue

      echo "Reloading wifi..."
      wifi reload

      echo "Refreshing eth0..."
      ifconfig eth0 down && ifconfig eth0 up

      echo "Success!"

      time_stamp=$(date +"%r")
      echo "scan_wifi is monitoring(finished scripting at: $time_stamp )..."
    
    fi
  
  #delay between network sweep of all possible shelly devices
  #keep this somewhat long, 20+ sec in order to allow GEN1 devices 
  #time to seek and find wifi to shut off AP post provision
  sleep 30
     
done