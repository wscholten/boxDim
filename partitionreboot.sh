
#!/bin/sh
# Shell script is run at reboot of system, and when the partitionflag is set will reboot system into automatic
# partition restore mode.
# If the  configflag is set this script will run the portiotn that updates the netowkr and overall
# system configuration.
#
# It is possible that the partitionflag as well as the configflag are set.  In that case the partition restore
# occurs first and will go through it's cycle.  The next time after the restor has taken palce, the system
# reboots it will also then run the configuration update.   In general thsi should be avoided!
#
# script Version: v.0.3
# Script Date: 01-03-2020
#
# script version: V.0.4
# Script Date: 01-07-2020
#
# Changes: Can now update just hostname or timezone, only update netowrk settigns if change is 
#          is requested in JSON file
#
# Script version: V.0.5
# Script Date: 01-14-2020
#
#
# Changes: On first boot runs diagnostic script sysconfig.sh and outputting a systemconfig.first diagnostic file
#
# Script version: V.0.6
# Script Date: 02-11-2020
#
# Changes: Added recovery of configupdate.json - if for some reason the production version is lost, at rebooot
#          the factory default version locatd in /var/recovery will be restored to /usr/local/updates/
#
# Script version: V.0.7
# Script Date: 12-21-2020
#
# Changes: Bug fix in line 189 - $newTime to $newTimeZone
#
#
# RETURN CODES need to be still updated - WS 1/3/20
# return codes on script end:
# EXIT 1000	Script ran succesfull
# EXIT 2000	Script is requestion restore operation
# EXIT 2020	Script exited because no restore requested
# EXIT 3000	SHA256 checksum file check passed
# EXIT 3005	Script set grub to reboot in partition restore
# EXIT 3010	Reboot request flag reset, assuming reboot will occur, preventing double run of script
# EXIT 3020	System reboot in process please be patient as restore kicks off
# EXIT 3030	SHA256 checksum file check failed, restore process cancelled

# SCRIPT requires the following files to present as tempaltes in /usr/local/updates/bootupdate:
# network.dhcp		-- dhcp template configuration
# network.static 	-- static template configuration

#set log file location
logfile="/var/elsa/log/partition.log"
configLogfile="/var/elsa/log/config.log"

# lets check if we need to reboot by checking for the flag partitionflag
scriptdir="/usr/local/updates/"
partitionflag="partitionflag"
shafile="mmcblk0p2-update.sha256"
usbdir="/media/usb0/"
recoverydir="/var/recovery"		# for recovery - we store old version of interface fiels here

configflag="configflag"			# configuration update flag
configUpdateDir="bootupdate"		# holds configuration data for update

bootFlag=0			        # request reboot after netowrk reconfig - 0= NO 1=YES
firstBootFlag="firstbootflag"	        # Flag get's set on first boot
systemDiag="/usr/local/updates/systemconfig.diag"
systemFirst="/usr/local/updates/systemconfig.first"

diagScript="/usr/local/updates/sysconfig.sh"

configJson="/usr/local/updates/configupdate.json"	# configuration update file we are expexting
configJsonRecovery="/var/recovery/configupdate.json"	# configuration recovery template

oldHostname=$(hostname)			# grab the current hostname

oldNetworkMode="$(cat /etc/network/interfaces | grep 'iface enp1s0 inet' | cut -f4 -d' ')"

ipaddress=$(ifconfig | grep 'inet addr:' | sed 's/.\{40\}$//' | sed 's/inet addr://g' | tr -d '[:blank:]' | tr --delete '\n')

oldTimeZone=$(cat '/etc/timezone')
					# the following: timedatectl list-timezones
					# system factory setting is UTC - sudo timedatectl set-timezone UTC

# we need some logfile sanity check here - in case they don;t exists we need to create them
if [ -f "$configLogfile" ]; then
   # logfile exists we can append
   echo "Time: $(date). Configuration Logifle active " >> $configLogfile
else
   echo "Time: $(date). Start of new configuration logfile " > $configLogfile
fi

if [ -f "$logfile" ]; then
   # logfile exists we can append
   echo "Time: $(date). Partion Reboot Logifle active " >> $logfile
else
   echo "Time: $(date). Start of new Partition Reboot logfile " > $logfile
fi

# start process - so write timestap to logfile
echo "Time: $(date). Partition Reboot script started" >> $logfile

# ------------- PARTITION RESTORE SCRIPT SECTION -----------------------------------------

if [ -f "$scriptdir$partitionflag" ]; then
  # we have the partition flag set, so it is time to do a reboot, however we
  # we will also check if we have a flashdrive mounted and there is a sha256 file
  # present, if not we abort
  echo "Time: $(date). Reboot requested to start partition restore" >> $logfile
  echo "Time: $(date). EXIT 2000" >> $logfile
  if [ -f "$usbdir$shafile" ]; then
     echo "Time: $(date). USB flash drive contains proper sha256 file - continue" >> $logfile
     echo "Time: $(date). EXIT 3000" >> $logfile

     # now we can change grub menu for reboot
     /usr/sbin/grub-reboot 3
     echo "Time: $(date). Changed GRUB boot menu item to 3 - requesting reboot" >> $logfile
     echo "Time: $(date). EXIT 3005" >> $logfile

     mv $scriptdir$partitionflag  $scriptdir$partitionflag".old"
     echo "$(date)" >> $scriptdir$partitionflag".old"

     echo "Time: $(date). Resetting reboot request flag to OFF - assuming system will now reboot" >> $logfile
     echo "Time: $(date). EXIT 3010" >> $logfile

     echo "Time: $(date). Rebooting system into restore operation - pleaase give sytem time to complete operation" >> $logfile
     echo "Time: $(date). EXIT 3020" >> $logfile

     systemctl reboot -i

  else
     echo "Time: $(date). USB Flash drive does not contain restore partition or missing file" >> $logfile
     echo "Time: $(date). Expecting $shafile in directory $usbdir " >> $logfile
     echo "Time: $(date). EXIT 3030"
     exit 3030
  fi
else
  echo "Time: $(date). NO Reboot requested to start partition restore" >> $logfile
  echo "Time: $(date). Checking if we need to do configuration update" >> $logfile
  echo "Time: $(date). EXIT 2020" >> $logfile
fi

# ------------- CONFIGURATION UPDATE SCRIPT SECTION -----------------------------------------

if [ -f "$scriptdir$configflag" ]; then
  # we have the configuration flag set, so it is time to change some of the 
  # system configurations - hostname, IP to manual if needed
  echo "Time: $(date). Reboot requested to start configuration update" >> $logfile
  echo "Time: $(date). EXIT 2000" >> $logfile

  echo "Time: $(date). Reboot requested to start configuration update" >> $configLogfile
  echo "Time: $(date). EXIT 2000" >> $configLogfile


  # we need to check if we have a configupdate.json file - if not we can not do a configuration update!
  if [ -f "$configJson" ]; then
     # we have a config update so we caa start processing
     echo "Time: $(date). We have a $configJson file to process" >> $configLogfile

     # we now need to parse the JSON file to and set the appropriate variabels for post processing
     newHostname=$(jshon -F $configJson -e hostname -u) 
     echo "Time: $(date). New Hostname from Config File:  $newHostname " >> $configLogfile
     newNetworkMode=$(jshon -F $configJson -e network -u)
     echo "Time: $(date). New Interface Mode from Config File:  $newNetworkMode " >> $configLogfile
     newTimeZone=$(jshon -F $configJson -e timezone -u)
     echo "Time: $(date). New time zone from Config File:  $newTimeZone " >> $configLogfile

     if [ -z $newHostname ]; then
	echo "Time: $(date). No hostname update required - skipping hostname config section " >> $configLogfile
     else
	echo "Time: $(date). Hostname update required " >> $configLogfile
        # lets check if we need todo a hostname change / setup - for that hosts and hostname must exist
        if [ $newHostname = $oldHostname ]; then
           # no HOSTNAME Change required
	   echo "Time: $(date). No hostname update needed - current hostname: $oldHostname is the same as new: $newHostname " >> $configLogfile	 
        else 
           # we need to update hastname
	   # we got both hosts and hostname so we can update
	   echo "Time: $(date). Can update hosts and hostname, new hostname will be: $newHostname " >> $configLogfile
           echo $newHostname > /etc/hostname
           sed "s/$oldHostname/$newHostname/g" /etc/hosts > $scriptdir$configUpdateDir/hosts
           cp $scriptdir$configUpdateDir/hosts /etc/hosts
	   echo "Time: $(date). Create updated hosts and hostname files ready to move into place " >> $configLogfile
           # set boot request flag to active changes
           bootFlag=1
        fi
     fi

     # set TIMEZONE settings 
     # factory setting will be UTC and does need to be set tovalid optins.  Timezones must be one
     # on the list generated when issuing the timedatectl list-timezones command
     if [ -z $newTimeZone ]; then
        echo "Time: $(date). No TimeZone update required keeping current setting of $oldTimeZone " >> $configLogfile
     else
        echo "Time: $(date). TimeZone update required - processing " >> $configLogfile
        echo "Time: $(date). Old (current) Timezone is: $oldTimeZone New Timezone will be: $newTimeZone " >> $configLogfile
        # lets check if we need to update or not
        if [ $oldTimeZone = $newTimeZone ]; then
           # nothing to change!
           echo "Time: $(date). No timezone update required - current and new timezone the same" >> $configLogfile
        else
           # we need to update timzone
           timedatectl set-timezone $newTimeZone
	   # now ;ets get the settings
           echo "Time: $(date). $(timedatectl) " >> $configLogfile
           # set boot request flag to active changes
           bootFlag=1
        fi
     fi

     # We should only touch the network settings if the $newNetworkMode is set, so we need to check for it being empty
     if [ -z $newNetworkMode ]; then
        echo "Time: $(date). Change to network mode is blank, skillipn netowrk configuration section" >> $configLogfile
     else
        # We need to potentially to a netowrk config change
        # if the new network interface type is STATIC then we need to get also the
        # static IP address info from the json file
        if [ $newNetworkMode = "static" ]; then
           newIpaddress=$(jshon -F $configJson -e ip -u) 
           echo "Time: $(date). New IP Address from Config File:  $newIpaddress " >> $configLogfile
           gateway=$(jshon -F $configJson -e gateway -u)
           echo "Time: $(date). New IP gateway from Config File:  $gateway " >> $configLogfile
           broadcast=$(jshon -F $configJson -e broadcast -u)
           echo "Time: $(date). New IP broadcast address from Config File:  $broadcast " >> $configLogfile
           netmask=$(jshon -F $configJson -e netmask -u)
           echo "Time: $(date). New IP netmask address from Config File:  $netmask " >> $configLogfile
           dns1=$(jshon -F $configJson -e dns1 -u)
           echo "Time: $(date). New IP DNS 1 from Config File:  $dns1 " >> $configLogfile
           dns2=$(jshon -F $configJson -e dns2 -u)
           echo "Time: $(date). New IP DNS 2 from Config File:  $dns2 " >> $configLogfile
           domain=$(jshon -F $configJson -e domain -u)
           echo "Time: $(date). New search Domain name from Config File:  $domain " >> $configLogfile
        fi

        # check if the configuration directory exists, if not we can not do a config change
        if [ -d "$scriptdir$configUpdateDir" ]; then
           # we have directory whihc may contain update fiels/config information 
           # we will now process the various updates based on the existence of data
           echo "Time: $(date). Configuration update directory exists - can proceed " >> $configLogfile
           echo "Time: $(date). EXIT 2000" >> $configLogfile


           # Next section checks and configure IP addressing - it is assuemd that the system is operating in DHCP
           # more, BUT it maybe set to static IP if needed.
           # first we check to see if new mode request is differnet then current mode request - if already dhcp 
           # and requesting dhcp - no change.  If static request change - even if already static, we need to update
           # IP address info.
           # The variable  $newNetworkMode 

           echo "Time: $(date). Current IP of machine is: $ipaddress " >> $configLogfile

           if [ $newNetworkMode = "static" ]; then
              echo "Time: $(date). STATIC IP - update to static IP - old status was: $oldNetworkMode  " >> $configLogfile
              if [ $newNetworkMode = $oldNetworkMode ]; then
                 # we were already set to static and our new mode will be static to, so we need to update IP
                 # addresses as they may have changed
                 echo "Time: $(date). Interface was already set to STATIC and will continue to be STATIC" >> $configLogfile
	         # create a NEW network.update file -- single '>' 
	         cat $scriptdir$configUpdateDir/network.static > $scriptdir$configUpdateDir/network.update
              else 
 	         # changing to static from dhcp
                 echo "Time: $(date). Interface was set to DHCP and will change to be STATIC" >> $configLogfile
	         # create a NEW network.update file -- single '>' 
	         cat $scriptdir$configUpdateDir/network.static > $scriptdir$configUpdateDir/network.update
              fi
              # now we need to add the static network configuration to template
              echo "address $newIpaddress" >> $scriptdir$configUpdateDir/network.update
              echo "netmask $netmask" >> $scriptdir$configUpdateDir/network.update
              echo "broadcast $broadcast" >> $scriptdir$configUpdateDir/network.update
              echo "gateway $gateway" >> $scriptdir$configUpdateDir/network.update
	      # DNS1 is required DNS2 is optional
              if [ -z $dns2]; then
                 echo "dns-nameservers $dns1" >> $scriptdir$configUpdateDir/network.update
              else
                 echo "dns-nameservers $dns1, $dns2" >> $scriptdir$configUpdateDir/network.update           
              fi
              # we need to set the dns-search if the domain is set
              if [ -z $domain ]; then
                 # search domain is not set
                 echo "Time: $(date). Interface has no search domain set ignoring in configuration" >> $configLogfile
              else
                 echo "dns-search $domain" >> $scriptdir$configUpdateDir/network.update
              fi
              echo "Time: $(date). Interface IP information has been created" >> $configLogfile
              cat $scriptdir$configUpdateDir/network.update >> $configLogfile
           fi

           if [ $newNetworkMode = "dhcp" ]; then
              echo "Time: $(date). DHCP IP - update to dhcp mode - old status was: $oldNetworkMode  " >> $configLogfile
              if [ $newNetworkMode = $oldNetworkMode ]; then
	         # was already DHCP so leave it alone 
                 echo "Time: $(date). Interface was already set to DHCP leaving it set to DHCP" >> $configLogfile
              else 
                 echo "Time: $(date). Interface being set to DHCP" >> $configLogfile
	         cat $scriptdir$configUpdateDir/network.dhcp > $scriptdir$configUpdateDir/network.update
              fi
           fi
        
	   # now we need to install the networking file - it needs to go to /etc/network/interfaces
           if [ -f "$scriptdir$configUpdateDir/network.update"  ]; then
              echo "Time: $(date). Moving network configuration to place - preserving old config first" >> $configLogfile
              cp /etc/network/interfaces /etc/network/interfaces.$(date +'%Y%m%d%H%M')
	      # also move this backup to the recovery directory just in case
              cp /etc/network/interfaces $recoverydir/interfaces.$(date +'%Y%m%d%H%M')
              cp $scriptdir$configUpdateDir/network.update /etc/network/interfaces
              echo "Time: $(date). Moved network config to /etc/network/interfaces" >> $configLogfile
              # set boot request flag to active changes
              bootFlag=1
           else
              echo "Time: $(date). ERROR no network.update file can not change network settings" >> $configLogfile
           fi
        else
           echo "Time: $(date). ERROR Can not update no config update directory: $scriptdir$configUpdateDir " >> $logfile
        fi
     fi

     if [ $bootFlag -eq 1 ]; then
        # We only reboot if we have any changes
        mv $scriptdir$configflag  $scriptdir$configflag".old"
        echo "$(date)" >> $scriptdir$configflag".old"

        # We need to tell the partitionlogfile that we are doen settign configurations
        echo "Time: $(date). FINISHED configuration updates stage " >> $logfile
        echo "Time: $(date). FINISHED configuration updates stage " >> $configLogfile

        echo "Time: $(date). Rebooting system to activate configuration change - pleaase give sytem time to complete operation" >> $logfile
        echo "Time: $(date). EXIT 3020" >> $logfile
        echo "Time: $(date). Rebooting system to activate configuration change - pleaase give sytem time to complete operation" >> $configLogfile
        echo "Time: $(date). EXIT 3020" >> $configLogfile

        systemctl reboot -i
      else 
        echo "Time: $(date). FINISHED NO configuration updates staged " >> $logfile
        echo "Time: $(date). FINISHED NO configuration updates staged " >> $configLogfile
      fi
   else 
      # DO NOT have a configuration update json file
      echo "Time: $(date). ERROR Can not update no config update file - $configJson " >> $logfile
   fi
fi


# ------------- FIRSTBOOT SCRIPT SECTION -----------------------------------------

if [ -f "$scriptdir$firstBootFlag" ]; then
  # system already ran firstboo script - normal mode
  echo "Time: $(date). Reboot requested but there is no need to run First Boot Script" >> $logfile

else
  # This is our first boot request, so we need to run firstboot script section
  echo "Time: $(date). Reboot requested - running First Boot Script" >> $logfile
  echo "Time: $(date). Running sysconfig.sh script and creating systemconfig.first file" >> $logfile
  . "$diagScript"
  # write flag
  echo "$(date)" > $scriptdir$firstBootFlag
  mv $systemDiag $systemFirst
fi

# ---------- CONFIG SCRIPT RECOVERY ----------------------------------------------

if [ -f "$configJson" ]; then
   # normal mode - configupdate.json template exists
   echo "Time: $(date). Reboot requested - configupdate.json file is in correct place - no restore required" >> $logfile
else 
   # for some reason the configupdate.json template has been removed, we are goign to put a recovered version back
   # into place.  This will do a reset ot factory configuration.
   echo "Time: $(date). Reboot requested - configuopdate.json file corrupted/missing " >> $logfile
   echo "Time: $(date). Recovering to factory default." >> $logfile
   cp $configJsonRecovery $configJson
fi

