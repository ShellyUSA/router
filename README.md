# openwrt-shelly-modules-source

These files and directories are what turn a regular distribution of OpenWrt into the "ShellyWRT"

Here is how to compile a .bin image of openWRT for the ZBT WG108 router


1. Download the OpenWRT from github found [here](https://github.com/openwrt/openwrt)

    Run:
    
     gh repo clone openwrt/openwrt
     

2. cd into /openWrt and git checkout into v19.07.10
    
    This is the only version that has worked
   
    Run:
    
     cd openWrt
     
     git checkout v19.07.10
     

3. Run: 

     ./scripts/feeds update -a   
     
     ./scripts/feeds install -a   
     

4. Add the modules you see into their respect places in /openWrt/feeds/luci:

     /openwrt/feeds/luci/applications/**luci-app-shelly-utilities**
     
     /openwrt/feeds/luci/modules/**luci-mod-network**
     
     /openwrt/feeds/luci/themes/**luci-theme-shelly**
     
     /openwrt/package/**base-files/files/etc/shadow**
     
     /openWrt/.config
    
  
5. Run again: 

     ./scripts/feeds update -a   
     
     ./scripts/feeds install -a  

6. Run: 

     make


7. Image cane be found here: 
     /openwrt/bin/targets/ramips/mt7621/openwrt-ramips-mt7621-zbt-we1326-squashfs-sysupgrade.bin


8. To flash firmware

    a. Connect to ZBT-WG 108 router by ethernet or wifi (if able)
    
    b. Go to browser enter into URL 192.168.1.1
        
        i. If no response, clear cache and try again
        
        ii. If still no response, change the interface on your device that is connecting to the router, change to:
        
            IP address: 192.168.1.100
            
            IP subnet mask: 255.255.255.0
            
            IP gateway: 192.168.1.1 
            
            DNS server 8.8.8.8 and 1.1.1.1 
            
    c. In LuCi interface enter
    
        Username: root
        
        Password: admin
        
    d. Go to System > Backup/Flash Firmware > FLASH IMAGE
    
    c. Upload image and uncheck "keep current configuration"
    
        i. If asked, check "force upgrade" 
        
    f. Press upload to flash and DO NOT power off


9. If flash fails for any reason

    a. Unplug power from router
    
    b. Press and hold "reset" button on back of router neat power jack
    
    c. While pressing and holding button, plug pwoer back on and hold for about 10 seconds
    
    d. Connect to router through 192.168.1.1 and a minimal backup interface to flash router only will appear, use this to re-flash firmware
    
        i. You may need to clear cache in your browser if you do not see the option to do this, 
        be sure to set your interface settings to static like in step 8(b)(ii)
