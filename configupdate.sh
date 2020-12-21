#!/bin/sh
# Shell script looks for the the configuratio update file 
# if the file is existst, sets a configupdate request flag.
#
# script Version: v.0.1
# Script Date: 01-03-2020
#
# CODES NEED UPDATING -- 1/3/20 WS
# return codes on script end:
# EXIT 1000	FLASH drive is mounted
# EXIT 1050	FLASH drive not mounted as epected - script aborted
# EXIT 2000	SHA256 file as expected on flashdrive
# EXIT 2025	SHA256 failed checksum verification process - script aborted
# EXIT 2050	SHA256 checksum verification of restore partition passed
# EXIT 2060	PARTITIONFLAG - previous flag removed to start new restore process
# EXIT 2065	PARTITIONFLAG - new partitionflag written to trigger reboot and restore
# EXIT 2200	SHA256 no propper checksum file exists for partoition - script aborted
# EXIT 2300	POWER cycle requests script completed properly


#set log file location
logfile="/var/elsa/log/partition.log"
configLogfile="/var/elsa/log/config.log"

# start process - so write timestap to logfile
echo "Time: $(date). Update Process starting" >> $logfile

# Lets set some needed runtime variables to make script less location dependent
scriptdir="/usr/local/updates/"
configflag="configflag"
configfile="configupdate.json"

# helper functions to check mount points - we leaving here jsut in case although not needed
isMounted    () { findmnt -rno SOURCE,TARGET "$1" >/dev/null;} #path or device
isDevMounted () { findmnt -rno SOURCE        "$1" >/dev/null;} #device only
isPathMounted() { findmnt -rno        TARGET "$1" >/dev/null;} #path   only

# make sure we have logfiles if not create empty ones.
# we need some logfile sanity check here - in case they don;t exists we need to create them
if [ -f "$configLogfile" ]; then
   # logfile exists we can append
   echo "Time: $(date). Configuration Logifle active " >> $configLogfile
else
   echo "Time: $(date). Start of new configuartion logfile " > $configLogfile
fi

if [ -f "$logfile" ]; then
   # logfile exists we can append
   echo "Time: $(date). Partion Reboot Logifle active " >> $logfile
else
   echo "Time: $(date). Start of new Partition Reboot logfile " > $logfile
fi

echo "Time: $(date). Configuration update process initiated" >> $logfile
echo "Time: $(date). Configuration update process initiated" >> $configLogfile

# lets check if we got a configfile
if [ -f "$scriptdir$configfile" ]; then
    echo "Time: $(date). Configuration update JSON file found - continue" >> $configLogfile
    echo "Time: $(date). EXIT 2000" >> $configLogfile

    # Now set the configflag - if the machine was prior upgraded
    # then there is a configflag.old - in whih case we remove it before we create
    # new request flag.
    if [ -f "$scriptdir$configflag.old" ]; then
       # we have a previous run partition flag set, so lets show the date/tiem of last resore
       # prior to setting a new flag
       (echo "Time: $(date). Previous configuration occured on following date/time: "; cat $scriptdir$configflag.old ) >> $configLogfile
       # Now we are going to remove the file
       rm $scriptdir$configflag.old
       echo "Time: $(date). Old configuration update request flag has been removed." >> $configLogfile
       echo "Time: $(date). EXIT 2060" >> $configLogfile
    fi
    touch $scriptdir$configflag
    echo "Time: $(date). Setting Configuration Update flag " >> $configLogfile
    echo "Time: $(date). EXIT 2065" >> $configLogfile

    # Reboot request flag is set - now we need to ask user to power cycle which will start the restore process
    echo "Time: $(date). PLEASE PowerCycle BoxDim unit to start actual configuration process " >> $configLogfile
    echo "Time: $(date). EXIT 2300" >> $configLogfile
    exit 2300
else
   echo "Time: $(date). Configuration Update file: $configfile is NOT found as expected -- ABORTING" >> $configLogfile
   echo "Time: $(date). Configuration Update file: $configfile is NOT found as expected -- ABORTING" >> $logfile
   echo "Time: $(date). EXIT 1050" >> $logfile
   echo "Time: $(date). EXIT 1050" >> $configLogfile
   exit 1050
fi
