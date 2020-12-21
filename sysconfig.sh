#!/bin/sh
#
#
# Author: 	Willem
# Date:		01-08-2020
# Vesrion:	v0.1
#
# Desciption: 	Extracts core configuration and system diagnostic data as oen single textfile from
#		BoxDim system.
#
# Version: 	v0.2
# Date:		01-09-2020
# Changes:	Added start amd stop indicator line to of script to elsa.log file
#

#set log file location (system diagnostic) output filen
logfile="/usr/local/updates/systemconfig.diag"
elsaLogfile="/var/elsa/log/elsa.log"
update_dir="/usr/local/updates/"
configflag="configflag.old"
partitionflag="partitionflag.old"
pruneflag="prunetime"
version="V0.2 01-09-2020"
fulldump="0"			# Do we do a fulldum - set through -f option call

helpFunction()
{
   echo ""
   echo "Usage: -f -h -v "
   echo "\t-f -- fullDumb "
   echo "\t-v -- version number"
   echo "\t-h -- help screen"
   exit 1 # Exit script after printing help
}

versionFunction()
{
   echo ""
   echo "Current version of script - $version ";
   exit 1 # Exit script after printing help
}


while getopts ":fvh" opt
do
   case "$opt" in
      f ) fulldump=1 ;;
      v ) versionFunction;;
      h ) helpFunction;;
   esac
done


# Start diagnostic script extracting data and writing to daignostic output file
# We will write a statement in to /var/elsa/log/elsa.log of the action
echo "Time: $(date). System Diagnostic and Configuration extract started " >> $elsaLogfile

echo "Time: $(date). Starting System Diagnostic File of BoxDim system " > $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
# system Kernel/OS level
echo "\nTime: $(date). Current Running Kernel / OS " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
uname -a >> $logfile

# patch level
echo "\nTime: $(date). Current BoxDim system version " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
cat /etc/motd >> $logfile

# disk space
echo "\nTime: $(date). Current BoxDim disk usage " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
df -H >> $logfile

# network config
echo "\nTime: $(date). Current BoxDim network hostname " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
hostname >> $logfile

# timezone
echo "\nTime: $(date). Current BoxDim time zone information " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
timedatectl >> $logfile

# network interfaces
echo "\nTime: $(date). Current BoxDim system network configuration " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
cat /etc/network/interfaces >> $logfile

# current IP address
echo "\nTime: $(date). Current BoxDim system network IP address " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
ifconfig | grep 'inet addr:' | sed 's/.\{40\}$//' | sed 's/inet addr://g' | tr -d '[:blank:]' | tr --delete '\n' >> $logfile

# elsa APP system daemon
echo "\n\nTime: $(date). Current BoxDim system ELSA daemon status " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
systemctl status elsa >> $logfile

# INTEL camera firmware
# Do firmware upgrade if needed -- check if firmware is below the new firmware update	         
# We need the Bus and Device the camera is attached to
echo "\nTime: $(date). Current BoxDim system INTEL camera config info " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
bus=`lsusb | grep "Intel Corp." | cut -f1 -d ":" | cut -f2 -d " "`
device=`lsusb | grep "Intel Corp." | cut -f1 -d ":" | cut -f4 -d " "`
echo "Time: $(date). Camera is on Bus: $bus and Device: $device " >> $logfile 
# get the current Firmware version
echo "\nTime: $(date). Camera Firmware and librealsense versioning \n " >> $logfile 
# get detailed camera information including librealsense version
rs-enumerate-devices -s  >> $logfile

# get Librealsense version installed
echo "\nTime: $(date). Current BoxDim system INTEL librealsense version installed " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
libversion=`rs-enumerate-devices --version | grep "version" | cut -f4 -d " "`
echo "Librealsense version installed: $libversion " >> $logfile

# get OpenCV version installed
echo "\nTime: $(date). Current BoxDim system OpenCV version installed " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
opencvVersion=`pkg-config --modversion opencv4`
echo "OpenCV version installed: $opencvVersion " >> $logfile

# get the elsa json (config file)
echo "\nTime: $(date). Current BoxDim system ELSA configuration JSON file " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
cat /usr/local/etc/elsa.d/elsa.json >> $logfile

# lets get the contents of the log directory
echo "\nTime: $(date). Current BoxDim system content of log directory " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
ls -l /var/elsa/log >> $logfile

# What packages are installed - look for v0000
echo "\nTime: $(date). Current BoxDim system packages installed " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
ls -l /usr/local/updates/ | grep 'v0' >> $logfile

# What was the last time a partition was restored
echo "\nTime: $(date). Current BoxDim last / (root) partition restored " >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
if [ -f  $update_dir$partitionflag ]; then
   lastpartitionupdate=$(cat $update_dir$partitionflag)
   echo "Time: $(date).  Last partition restore: $lastpartitionupdate " >> $logfile
else
   echo "Time: $(date).  No partiton restore of / (root) has taken place " >> $logfile
fi

# What was the last time configuration was updated
echo "\nTime: $(date). Current BoxDim last runtime configuration update" >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
if [ -f  $update_dir$configflag ]; then
   lastconfigupdate=$(cat $update_dir$configflag)
   echo "Time: $(date).  Last configuration update: $lastconfigupdate " >> $logfile
else 
   echo "Time: $(date).  No system re-configuration has taken place " >> $logfile
fi

# What was the last time disk /var/elsa was pruned
echo "\nTime: $(date). Current BoxDim disk pruning status of /var/elsa" >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
if [ -f  $update_dir$pruneflag ]; then
   lastpruneupdate=$(cat $update_dir$pruneflag)
   echo "Time: $(date).  Last disk pruning of /var/elsa took place at: $lastpruneupdate " >> $logfile
else 
   echo "Time: $(date).  No disk pruning has taken place yet " >> $logfile
fi

# Get the last entries in the kern.log file 
echo "\nTime: $(date). Current BoxDim system - kernel errors" >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
tail /var/log/kern.log >> $logfile

# Get the last entries in the syslog file 
echo "\nTime: $(date). Current BoxDim system - last syslog entries" >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
tail /var/log/syslog >> $logfile

# last time the logs were rotated
# Get the last entries in the syslog file 
echo "\nTime: $(date). Current BoxDim system ELSA logrotate run" >> $logfile
echo "------------------------------------------------------------------------------------------" >> $logfile
cat /var/elsa/log/logrotate-state >> $logfile


# check if we are needing todo a full log file dump as part of this call.
if [ $fulldump -eq "1" ]; then
   echo "\nTime: $(date). Dumping full contents of latest elsa.log " >> $logfile
   echo "------------------------------------------------------------------------------------------" >> $logfile
   cat /var/elsa/log/elsa.log >> $logfile

   echo "\nTime: $(date). Dumping full contents of latest syslog " >> $logfile
   echo "------------------------------------------------------------------------------------------" >> $logfile
   cat /var/log/syslog >> $logfile

   echo "\nTime: $(date). Dumping full contents of latest update log " >> $logfile
   echo "------------------------------------------------------------------------------------------" >> $logfile
   cat /var/elsa/log/update.log >> $logfile

   echo "\nTime: $(date). Dumping full contents of latest disk pruning log " >> $logfile
   echo "------------------------------------------------------------------------------------------" >> $logfile
   cat /var/elsa/log/diskprune.log >> $logfile

   echo "\nTime: $(date). Dumping full contents of latest partition restore log " >> $logfile
   echo "------------------------------------------------------------------------------------------" >> $logfile
   cat /var/elsa/log/partition.log >> $logfile

   echo "\nTime: $(date). Dumping full contents of latest update log " >> $logfile
   echo "------------------------------------------------------------------------------------------" >> $logfile
   cat /var/elsa/log/update.log >> $logfile

   echo "\nTime: $(date). Dumping full contents of latest system reconfiguration log " >> $logfile
   echo "------------------------------------------------------------------------------------------" >> $logfile
   cat /var/elsa/log/config.log >> $logfile

   # if called with -f option we alwasy will zip up the file
   tar cvfz systemconfig.diag.tgz systemconfig.diag > /dev/null 2>&1

   echo "Time: $(date). FULL System Diagnostic and Configuration extract completed" >> $elsaLogfile
fi

# Lets tell elsa log filethat we are done.
echo "Time: $(date). System Diagnostic and Configuration extract completed " >> $elsaLogfile


