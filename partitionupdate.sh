#!/bin/sh
# Shell script looks for the partition update to be present on a flashdrive inserted in the USB connector
# This script verifies that the partition file is not corrupt, and then sets a reboot request flag.
#
# script Version: v.0.1
# Script Date: 09-13-2019
#
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

# make sure logifle exists
if [ -f "$logfile" ]; then
   # logfile exists we can append
   echo "Time: $(date). Partion Reboot Logifle active " >> $logfile
else
   echo "Time: $(date). Start of new Partition Reboot logfile " > $logfile
fi

# start process - so write timestap to logfile
echo "Time: $(date). Update Process starting" >> $logfile

# Lets set some needed runtime variables to make script less location dependent
scriptdir="/usr/local/updates/"
partitionflag="partitionflag"
shafile="mmcblk0p2-update.sha256"
restoredir="mmcblk0p2-update"
usbdir="/media/usb0/"
devdir="/dev/sda1"

# helper functions to check mount points
isMounted    () { findmnt -rno SOURCE,TARGET "$1" >/dev/null;} #path or device
isDevMounted () { findmnt -rno SOURCE        "$1" >/dev/null;} #device only
isPathMounted() { findmnt -rno        TARGET "$1" >/dev/null;} #path   only

# lets check if we got a flashdrive mounted
if isMounted "$devdir"; then
   echo "Time: $(date). Flashdrive is mounted as expected" >> $logfile
   echo "Time: $(date). EXIT 1000" >> $logfile

   # now we need to check if we got the right content on the flash drive
  if [ -f "$usbdir$shafile" ]; then
     echo "Time: $(date). USB flash drive contains proper sha256 file - continue" >> $logfile
     echo "Time: $(date). EXIT 2000" >> $logfile

    # now we need to check if the checksum is passing 
    # we need to change into the falshdrive directory, followed by checksum check
    # this process takes a bit of time - BE PATIENT
    cd $usbdir$restoredir
    echo "Time: $(date). Performing SHA256 checksum check - BE PATIENT" >> $logfile

    if ! sha256sum --status -c $usbdir$shafile > /dev/null 2>&1; then 
       echo "Time: $(date). Update ABORTED checksum verification FAILED" >> $logfile
       echo "Time: $(date). EXIT 2025" >> $logfile
       cd $scriptdir
       exit 2025
    else
       echo "Time: $(date). Update checksum verification succeeded" >> $logfile
       echo "Time: $(date). EXIT 2050" >> $logfile
       cd $scriptdir

       # Now set the partitionflag - if the machine was prior upgraded
       # then there is a partitionflag.old - in whih case we remove it before we create
       # new request flag.
       if [ -f "$scriptdir$partitionflag.old" ]; then
          # we have a previous run partition flag set, so lets show the date/tiem of last resore
	  # prior to setting a new flag
          (echo "Time: $(date). Previous restore occured on following date/time: "; cat $scriptdir$partitionflag.old ) >> $logfile
          # Now we are going to remove the file
          rm $scriptdir$partitionflag.old
          echo "Time: $(date). Old reboot request flag has been removed." >> $logfile
          echo "Time: $(date). EXIT 2060" >> $logfile

       fi
       touch $scriptdir$partitionflag
       echo "Time: $(date). Setting Reboot request flag " >> $logfile
       echo "Time: $(date). EXIT 2065" >> $logfile

       # Reboot request flag is set - now we need to ask user to power cycle which will start the restore process
       echo "Time: $(date). PLEASE PowerCycle BoxDim unit to start actual restore process " >> $logfile
       echo "Time: $(date). DO NOT REMOVE flash drive untill full update cycle has completed!! " >> $logfile
       echo "Time: $(date). EXIT 2300" >> $logfile
       exit 2300
    fi
  else 
     echo "Time: $(date). USB flash drive does NOT contain proper sha256 file - ABORTING" >> $logfile
     echo "Time: $(date). EXIT 2200" >> $logfile
     exit 2200
  fi
else
   echo "Time: $(date). Flashdrive is NOT mounted as expected -- ABORTING" >> $logfile
   echo "Time: $(date). EXIT 1050" >> $logfile
   exit 1050
fi
