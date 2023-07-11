--Daniel Barba Shelly App API 20230430
--V2.0.0 DBarba 20230519 update for UCI RPC and removing default set config for provisioning feature, added clear log route
--V2.0.1 DBarba 20230520 Removed mosquitto initialization from here, shortened API routes, updated API location
--V2.0.2 DBarba 20230523 Refactored rm -r commands to only delete with sed cmds, leaving thme in place but still clearing them

local sys = require "luci.sys"
local json = require "luci.jsonc"

module("luci.controller.shellyutilities", package.seeall)

function index()
	--Menu name
	entry({"admin", "services", "shellyutilities"}, firstchild(), _("Shelly Utilities"), 5)

	--Utilities/tabs
	entry({"admin", "services", "shellyutilities", "provisioning"}, template("shellyprovision"), _("Provisioning"), 1)
	entry({"admin", "services", "shellyutilities", "broker"}, template("shellymqtt"), _("MQTT Broker"), 2)

	--API routes
	entry({"shellyutilities","api", "saverunconfig"}, call("save_run_config_shelly"), nil, 3).leaf = true
	entry({"shellyutilities","api", "getconfigstatus"}, call("get_config_status_shelly"), nil, 3).leaf = true
	entry({"shellyutilities","api", "runshelly"}, call("refresh_shelly_run"), nil, 3).leaf = true
	entry({"shellyutilities","api", "stopshelly"}, call("stop_shelly_app"), nil, 3).leaf = true
	entry({"shellyutilities","api", "checkservices"}, call("check_service_status"), nil, 3).leaf = true
	entry({"shellyutilities","api", "restorewireless"}, call("restore_wireless"), nil, 3).leaf = true
	entry({"shellyutilities","api", "provisionlog"}, call("get_scan_log"), nil, 3).leaf = true
	entry({"shellyutilities","api", "clearprovisionlog"}, call("clear_log"), nil, 3).leaf = true
end


function save_run_config_shelly()

	-- Pull from payload and format
	local ROUTER_SSID = luci.http.formvalue("router_ssid")  
	local ROUTER_PASS = luci.http.formvalue("router_pass") 
	local MQTT_USER = luci.http.formvalue("mqtt_user") 
	local MQTT_PASS = luci.http.formvalue("mqtt_pass") 
	local MQTT_SERVER = luci.http.formvalue("mqtt_server") 
	local MQTT_PROVISION = luci.http.formvalue("mqtt_provision") 
	local MQTT_BROKER_PASS = luci.http.formvalue("mqtt_broker_pass")
	local MQTT_BROKER_USER = luci.http.formvalue("mqtt_broker_user")
	local MQTT_BROKER_PORT = luci.http.formvalue("mqtt_broker_port")
	local MQTT_BROKER_RUN = luci.http.formvalue("mqtt_broker_run")
	local SHELLY_PROVISION_RUN = luci.http.formvalue("shelly_provision_run")

	--preparing CONFIG into stringified format
	local configTemplate = '{ "ROUTER_SSID":"%s", "ROUTER_PASS":"%s", "MQTT_USER":"%s", "MQTT_PASS":"%s", "MQTT_SERVER":"%s", "MQTT_PROVISION":"%s", "MQTT_BROKER_PASS":"%s","MQTT_BROKER_USER":"%s","MQTT_BROKER_PORT":"%s", "MQTT_BROKER_RUN":"%s", "SHELLY_PROVISION_RUN":"%s"}'
	local CONFIG = string.format(configTemplate, ROUTER_SSID, ROUTER_PASS, MQTT_USER, MQTT_PASS, MQTT_SERVER, MQTT_PROVISION, MQTT_BROKER_PASS, MQTT_BROKER_USER, MQTT_BROKER_PORT, MQTT_BROKER_RUN, SHELLY_PROVISION_RUN)

	-- Stop services
	sys.exec("/etc/init.d/shellyrun stop")

	--save incoming to config.json
	sys.exec("echo '" .. CONFIG .. "' | tee /usr/shelly/config.json >/dev/null")

	-- Refresh/run new commands set on (i.e. true)
	sys.exec("/etc/init.d/shellyrun start")
	
	-- Pull config that was just saved and return to client
	local configFile = io.open("/usr/shelly/config.json", "r")
	local configSettings = configFile:read("*all")
	configFile:close()

	--Check status of services
	local scan_wifi_status = sys.exec("PIDFILE=/var/run/scan_wifi.pid; if [ -f $PIDFILE ] && kill -0 $(cat $PIDFILE) >/dev/null 2>&1; then echo 'RUNNING...'; else echo 'STOPPED'; fi")
	local mqtt_broker_status = sys.exec("PIDFILE=$(pidof mosquitto);if [ -f $PIDFILE ]; then echo 'STOPPED'; else echo 'RUNNING...'; fi")	

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ok       = true,
		configuration  = configSettings,
		scan_wifi_status  = scan_wifi_status,
		mqtt_broker_status  = mqtt_broker_status,
		stdout   = not binary and stdout,
		stderr   = stderr,
		exitcode = rv,
		binary   = binary
	})

end


function get_config_status_shelly()

	-- Retrive config.json and send as string JSON
	local configFile = io.open("/usr/shelly/config.json", "r")
	local configSettings = configFile:read("*all")
	configFile:close()

	--Check status of services
	local scan_wifi_status = sys.exec("PIDFILE=/var/run/scan_wifi.pid; if [ -f $PIDFILE ] && kill -0 $(cat $PIDFILE) >/dev/null 2>&1; then echo 'RUNNING...'; else echo 'STOPPED'; fi")
	local mqtt_broker_status = sys.exec("PIDFILE=$(pidof mosquitto);if [ -f $PIDFILE ]; then echo 'STOPPED'; else echo 'RUNNING...'; fi")

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ok       = true,
		configuration  = configSettings,
		scan_wifi_status  = scan_wifi_status,
		mqtt_broker_status  = mqtt_broker_status,
		stdout   = not binary and stdout,
		stderr   = stderr,
		exitcode = rv,
		binary   = binary
	})

end


function check_service_status()

	--Check status of services
	local scan_wifi_status = sys.exec("PIDFILE=/var/run/scan_wifi.pid; if [ -f $PIDFILE ] && kill -0 $(cat $PIDFILE) >/dev/null 2>&1; then echo 'RUNNING...'; else echo 'STOPPED'; fi")
	local mqtt_broker_status = sys.exec("PIDFILE=$(pidof mosquitto);if [ -f $PIDFILE ]; then echo 'STOPPED'; else echo 'RUNNING...'; fi")

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ok       = true,
		scan_wifi_status  = scan_wifi_status,
		mqtt_broker_status  = mqtt_broker_status,
		status  = response,
		stdout   = not binary and stdout,
		stderr   = stderr,
		exitcode = rv,
		binary   = binary
	})
end



function refresh_shelly_run()

	--Refresh services if set on (i.e. true)
	sys.exec("/etc/init.d/shellyrun start")

	-- Check status of services
	local scan_wifi_status = sys.exec("PIDFILE=/var/run/scan_wifi.pid; if [ -f $PIDFILE ] && kill -0 $(cat $PIDFILE) >/dev/null 2>&1; then echo 'RUNNING...'; else echo 'STOPPED'; fi")
	local mqtt_broker_status = sys.exec("PIDFILE=$(pidof mosquitto);if [ -f $PIDFILE ]; then echo 'STOPPED'; else echo 'RUNNING...'; fi")	

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ok       = true,
		message  = "Shelly App services refreshed...",
		scan_wifi_status  = scan_wifi_status,
		mqtt_broker_status  = mqtt_broker_status,
		stdout   = not binary and stdout,
		stderr   = stderr,
		exitcode = rv,
		binary   = binary
	})
end


function stop_shelly_app()

	sys.exec("/etc/init.d/shellyrun stop")

	-- Check status of services
	local scan_wifi_status = sys.exec("PIDFILE=/var/run/scan_wifi.pid; if [ -f $PIDFILE ] && kill -0 $(cat $PIDFILE) >/dev/null 2>&1; then echo 'RUNNING...'; else echo 'STOPPED'; fi")
	local mqtt_broker_status = sys.exec("PIDFILE=$(pidof mosquitto);if [ -f $PIDFILE ]; then echo 'STOPPED'; else echo 'RUNNING...'; fi")

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ok       = true,
		message  = "All Shelly App services stopped",
		scan_wifi_status  = scan_wifi_status,
		mqtt_broker_status  = mqtt_broker_status,
		stdout   = not binary and stdout,
		stderr   = stderr,
		exitcode = rv,
		binary   = binary
	})
end

function use_default_wireless()

	--restores default wireless parameters
	sys.exec("cp -fv /usr/shelly/default_wireless /etc/config/wireless")
	sys.exec("sed -i '1,$d' /tmp/provision_queue")
	sys.exec("sed -i '1,$d' /usr/shelly/config_needs_reset")

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ok       = true,
		message  = "Wireless config restored to default!",
		stdout   = not binary and stdout,
		stderr   = stderr,
		exitcode = rv,
		binary   = binary
	})
end

--If shelly scripts, the user, or both send the wireless configuration down the tubes this route is here for us all
function restore_wireless()

	use_default_wireless()

	--reset peripherals
	sys.exec("wifi")
	sys.exec("ifconfig eth0 down && ifconfig eth0 up")

end

function get_scan_log()

	-- Pull provision log and return to client
	local scanWifiFile = io.open("/usr/shelly/scan_wifi.log", "r")
	local scanWifiLog = scanWifiFile:read("*all")
	scanWifiFile:close()

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ok       = true,
		scan_wifi_log  = scanWifiLog,
		stdout   = not binary and stdout,
		stderr   = stderr,
		exitcode = rv,
		binary   = binary
	})

end


function clear_log()

	-- Clear scan_wifi.log without breaking scan_wifi stdout/stderr pipe
	sys.exec("sed -i '1,$d' /usr/shelly/scan_wifi.log")
	
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ok       = true,
		message  = "Successfully cleared log!",
		stdout   = not binary and stdout,
		stderr   = stderr,
		exitcode = rv,
		binary   = binary
	})

end
