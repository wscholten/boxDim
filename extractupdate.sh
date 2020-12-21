#!/bin/sh
# Shell script looks for the update package with the extension tgz, it assuems that there is ONLY one  tgz package
# left in the update directory - then install script should on completion delete the update package from the system
#
# script Version: v.0.1
# Script Date: 08-07-2019
#
# Script Version: v.0.2
# Script Date: 08-29-2019
# Script Changes: added sha256 checksum verification
#
# Script Version v.0.3
# Script Date: 09-24-2019
# Script Change: added ability to update the scripts, update firmware, DB schema.  New EXIT status codes added
#		 script also performs critial backups of certain fiels it replaces.   It expects now the update
#		 to come over in a new filename: update-v000x.tgz

# Script Date: 10-10-2019
# Script Changes: addedd full Camera firmware update routine, and it has been checked and does do a firmware forced
# 		  update. This should make it possible to replace same firmware in case of corruption
#
# Left to complete:	We need better EXIT code status, and reorganize EXIT codes in a more sensible 

# Script Date:	10-23-2019
# Script Changes: Reorganized EXIT codes to be more module aligned and more descriptive.
#		 Update locations of files/directories to match new Master image layout of system
#

# Script Date:	01-03-2020
# Script Changes: Added upgrade of the configupdate.sh script to the script update routine. Also added
# 		sanity check to make sure that in case of none existing logfile, one is created first
#

# Author:	Willem Scholten
# 		On behalf of Ioline Corperation

#
# return codes on script end:
#
# RETURN code EXIT 1000 is what we shoudl expect anything else as the last line  means we failed!!!

# EXIT 1000    SUCCESS Update complete - please power cylce unit
# EXIT 1030    Update ABORTED no update package found
#
#        Verification of integrity of elsaupdate-v000x.tgz package
#
# EXIT 2000    SUCCESS Checksum verification succeeded - continue to next step
# EXIT 2010    Update ABORTED checksum verification FAILED
# EXIT 2020    Update ABORTED no checksum file found
#
#        Verifying update and can it be installed
#
# EXIT 3010    Update already installed can not continue
# EXIT 3020    Processing - extracting files
# EXIT 3030    Update version in archive mismatch - no update directory - update aborted
# EXIT 3040    Update ABORTED update package does not exist
# EXIT 3400    Update ABORTED pre-requisite prior package not installed
#
#
#        Checking if scripts itself need updating
#
# EXIT 4000    SUCCESS Script file named moved into place
# EXIT 4010    No SCRIPTS directory found - will not process script updates
#
#        Checking in binary update required
#
# EXIT 5000    SUCCESS Binaries updated
# EXIT 5010    Need to update binaries total files
# EXIT 5020    No binaries to update
#
#        Checking of configuration update is needed
#
# EXIT 6000    SUCCESS configurations are updated
# EXIT 6010    Need to update config files
# EXIT 6020    No configurations to update
#
# EXIT 7000    RESERVED for now for DB update routine
#
#        Checking if camera requires updates
#
# EXIT 8000    SUCCESS Firmware has been updates succesfully
# EXIT 8010    Need to update Camera Firmware - firmware package found - checking version
# EXIT 8015    Firmware package exist
# EXIT 8020    Current firmware has higher or equal major number - so we are NOT updating
# EXIT 8030    Processing FIRMWARE update for Camera
# EXIT 8035    Need to update Camera Firmware - firmware package found - getting bin file
# EXIT 8040    No camera firmware update to be performed...skipping update
# EXIT 8045    No camera firmware update version found....skipping update
#


#set log file location
logfile="/var/elsa/log/update.log"
updatefile="elsaupdate-"
recovery_dir="/var/recovery"

bindir_target="/usr/local/bin"
etcdir_target="/usr/local/etc"
elsaconf_dir="elsa.d"
script_dir="scripts"

# prequisite patch level
prereq="required"		

# motd update file and drectory
motdedit="motd.add"
motd_dir="/usr/local/etc/"

# script array used to check which scripts may be updated. 
# NOTE ubuntu DASH shell does not support array's
scriptArray0="extractupdate.sh" 
scriptArray1="partitionreboot.sh" 
scriptArray2="partitionupdate.sh"
scriptArray3="configupdate.sh"

# we need some logfile sanity check here - in case they don;t exists we need to create them
if [ -f "$logfile" ]; then
   # logfile exists we can append
   echo "Time: $(date). Update Logifle active " >> $logfile
else
   echo "Time: $(date). Starting new Update Logfile " > $logfile
fi
 
# start process - so write timestap to logfile
echo "Time: $(date). Update Process starting" >> $logfile

# check if we have an update package or not....
# file should be called update-v000x.tgz
files=$(ls *.tgz 2> /dev/null | wc -l)
if [ "$files" != "0" ]
then
  echo "Time: $(date). Update Package Found..." >> $logfile

  for i in `ls *.tgz`
  do
    echo "Time: $(date). Update Package is: $i " >> $logfile
    version=`echo $i | cut -f1 -d'.' | cut -f2 -d'-' `
    echo "Time: $(date). Update Package Version: $version " >> $logfile
  done

  # now we need to unpack this update file, when done, rename it
  echo "Time: $(date). Processing update package: $i - extracting files " >> $logfile
  tar xvfz $i > /dev/null 2>&1

  # lests check we have gotten the expacted set of two files
  # elsaupdate-$version.tgz  and elsaupdate-$version.tgz.sha256
  shafile="$updatefile$version.tgz.sha256"
  extractfile="$updatefile$version.tgz"
  echo "Time: $(date). Checking for SHA256 file: $shafile " >> $logfile
  
  if [ -f "$shafile" ]; then
     # we have a  checksum file so lets compare and check if file is correct.
     if ! sha256sum --status -c $shafile > /dev/null 2>&1; then 
       echo "Time: $(date). Update ABORTED checksum verification FAILED" >> $logfile
       echo "Time: $(date). EXIT 2010" >> $logfile
       exit 2010
     else
       echo "Time: $(date). Update checksum verification succeeded" >> $logfile
       echo "Time: $(date). EXIT 2000" >> $logfile
     fi
  else
     # we got no checksum file so abort
     echo "Time: $(date). Update ABORTED no checksum file $shafile found" >> $logfile
     echo "Time: $(date). EXIT 2020" >> $logfile
     exit 2020
  fi

  echo "Time: $(date). Checking for update package file: $extractfile " >> $logfile  
  if [ -f "$extractfile" ]; then
     # we have an update package so we can go ahead and make sure that we 
     # prevent re-extract of the core update package
     echo "Time: $(date). Update package $extractfile exists" >> $logfile

     # remove update archive as we are sucessful
     rm $i
     echo "Time: $(date). Update complete - remove update source file $i" >> $logfile

     # now extract the update tree, but we need to make sure we are not overwriting
     # an update of same version

     if [ -d "$version" ]; then
        echo "Time: $(date). Update already installed can not continue..." >> $logfile
        (echo "Time: $(date). Update was previously installed on: "; cat $version/$version) >> $logfile
        echo "Time: $(date). EXIT 3010" >> $logfile
        exit 3010
     else
        echo "Time: $(date). Processing $version - extracting files " >> $logfile
	echo "Time: $(date). EXIT 3030" >> $logfile
        tar xvfz $extractfile > /dev/null 2>&1

        # Now that we unpacked the archive we need to make sure that the archive 
        # directory created matches the version we think we should have i.e elsaupdate-v0001.tgz
        # has created a  directory v0001 if not we need to abort!

        if [ -d "$version" ]; then
           echo "Time: $(date). Update version in archive match, proceed with update of $version..." >> $logfile
           # now we can start the actually install and move the update in place
           cd $version

	   # lets see what the version to install update stamp is, there should be a date/time stamp
	   # in a file called $version
	   (echo "Time: $(date). Updating $version -- package timestamp is: "; cat $version) >> $logfile

           # we need to ensure that we have  a prerquisite if required.  The ile requires should be in the
	   # root of the directory and if it contains a string like v000x then we need to check if the
           # pre-requisite package is installed
	   echo "Time: $(date). Checking if need to have a pre-requisite package installed " >> $logfile
           if [ -f $prereq ]; then
  	      echo "Time: $(date). Pre-requisite file exists checking requirement" >> $logfile
	      prerequisite=$(cat $prereq)
              if  [ -z $prerequisite ]; then
	         echo "Time: $(date). No pre-requisite required" >> $logfile
              else
	         echo "Time: $(date). Pre-requisite required - looking for previous install of: $prerequisite" >> $logfile
		 # check if we have the prerequisite - that means we shoudl have a directory left with name of 
	         # $prerequisite
                 if [ -d ../$prerequisite ]; then
 	            echo "Time: $(date). Pre-requisite $prerequisite installed as required " >> $logfile
		 else
 	            echo "Time: $(date). ABORT Pre-requisite $prerequisite not installed " >> $logfile
 	            echo "Time: $(date). EXIT 3400 " >> $logfile
		    # exit the script hard 
		    exit 3400
                 fi
              fi
           fi

           # get elsa process ID
           processId=$(ps -ef | grep 'elsa' | grep -v 'grep' | awk '{ printf $2 }')
           echo $processId

           # Kill the process and sleep 1sec to ensure it ends 
           # it is possible Elsa is not running, in which case we can not KILL it
           if [ -z "$processId" ]; then
              echo "Time: $(date). Elsa process appears not to be running safe to update " >> $logfile
           else
              echo "Time: $(date). Stopping elsa process with id: $processId prior to update " >> $logfile
              kill $processId
              sleep 1
           fi

           # now we need to process the updates, first we need to check if we need to update
           # our own script, if so we have a special case and we need to account for re-running oursleves

	   # we need to check if we got files in the scripts directory, if so we need to handle the special
	   # script update case, if not we cna go on as normal.
           if [ -d "$script_dir" ]; then
	      # script directory exists so we maybe needing to do script updates
              echo "Time: $(date). SCRIPTS directory is present in update, possible script update needed " >> $logfile
              # we need to check if we have files in the directory and if so we need to move them in place

              scriptfiles=$(ls scripts/*.sh 2> /dev/null | wc -l)
              if [ "$scriptfiles" != "0" ]; then
                 echo "Time: $(date). Number Scriptfiles Found: $scriptfiles..." >> $logfile
                 # process files - find them and move them into proper spot, we only process .sh files
                 # only scripts in the scriptArray can be updated. moved

		 # moving into scripts directory
                 cd $script_dir
 
                 # update/replace in place extractupdate.sh
		 if [ -f "$scriptArray0" ]; then
		      # Todo an in place update the exisiting (running) script which is already loaded in memory
		      # and executing, must be removed from the system  (disk storage) before being updated 
    		      echo "Time: $(date). Script file named: $scriptArray0 found - processing" >> $logfile
		      # Process
    		      echo "Time: $(date). Removing old script, prior to replace" >> $logfile
		      # createa recover copu in recovery partition of script
                      cp ../../$scriptArray0 $recovery_dir/$scriptArray0.$(date +'%Y%m%d%H%M')	
                      rm ../../$scriptArray0

                      cp $scriptArray0 ../../.
    		      echo "Time: $(date). Script file named: $scriptArray0 moved into place" >> $logfile
		      echo "Time: $(date). EXIT 4000" >> $logfile
                 fi

		 #  Updating the script partitionreboot.sh if needed.
		 if [ -f "$scriptArray1" ]; then
                      echo "Time: $(date). Script file named: $scriptArray1 found - processing" >> $logfile
                      # Process
		      # Process
    		      echo "Time: $(date). Removing old script, prior to replace" >> $logfile
		      # createa recover copu in recovery partition of script
                      cp ../../$scriptArray1 $recovery_dir/$scriptArray1.$(date +'%Y%m%d%H%M')	
                      rm ../../$scriptArray1

                      cp $scriptArray1 ../../.
    		      echo "Time: $(date). Script file named: $scriptArray1 moved into place" >> $logfile
		      echo "Time: $(date). EXIT 4000" >> $logfile
		 fi

		 #  Updating the script partitionupdate.sh if needed.
		 if [ -f "$scriptArray2" ]; then
                      echo "Time: $(date). Script file named: $scriptArray2 found - processing" >> $logfile
                      # Process
		      # Process
    		      echo "Time: $(date). Removing old script, prior to replace" >> $logfile
		      # createa recover copu in recovery partition of script
                      cp ../../$scriptArray2 $recovery_dir/$scriptArray2.$(date +'%Y%m%d%H%M')	
                      rm ../../$scriptArray2

                      cp $scriptArray2 ../../.
    		      echo "Time: $(date). Script file named: $scriptArray2 moved into place" >> $logfile
		      echo "Time: $(date). EXIT 4000" >> $logfile

                 fi
		 #  Updating the script configupdate.sh if needed.
		 if [ -f "$scriptArray3" ]; then
                      echo "Time: $(date). Script file named: $scriptArray3 found - processing" >> $logfile
                      # Process
		      # Process
    		      echo "Time: $(date). Removing old script, prior to replace" >> $logfile
		      # createa recover copu in recovery partition of script
                      cp ../../$scriptArray3 $recovery_dir/$scriptArray3.$(date +'%Y%m%d%H%M')	
                      rm ../../$scriptArray3

                      cp $scriptArray3 ../../.
    		      echo "Time: $(date). Script file named: $scriptArray3 moved into place" >> $logfile
		      echo "Time: $(date). EXIT 4000" >> $logfile

                 fi


		 cd ..
              fi
           else
              echo "Time: $(date). No SCRIPTS directory found - will not process script updates " >> $logfile
	      echo "Time: $(date). EXIT 4010" >> $logfile
           fi


           # move update binary files into place
           echo "Time: $(date). checking if we need to Update elsa binaries in $bindir_target " >> $logfile
	   binfiles=$(ls bin/* 2> /dev/null | wc -l)
           if [ "$binfiles" != "0" ]; then
              echo "Time: $(date). Need to update binaries total files to update: $binfiles..." >> $logfile
	      echo "Time: $(date). EXIT 5010" >> $logfile
              cp -p bin/* $bindir_target
              echo "Time: $(date). UPDATED binaries in: $bindir_target" >> $logfile
	      echo "Time: $(date). EXIT 5000" >> $logfile
           else
              echo "Time: $(date). No binaries to update" >> $logfile
	      echo "Time: $(date). EXIT 5020" >> $logfile
           fi

           # move new config files into place 
           echo "Time: $(date). Updating elsa config files in $etcdir_target/$elsaconf_dir" >> $logfile
	   etcfiles=$(ls etc/elsa.d/* 2> /dev/null | wc -l)
           if [ "$etcfiles" != "0" ]; then
              echo "Time: $(date). Need to update config files - total files to update: $etcfiles..." >> $logfile
	      echo "Time: $(date). EXIT 6010" >> $logfile
	      # protect config files first - copy all etc/elsa.d fiels into /var/recovery/etc
	      # we will tar  /usr/local/etc directory and date/time stamp and place in recovery direcotry
              echo "Time: $(date). Preparing to backup current configs into: $recovery_dir" >> $logfile
	      etcrecovery="$recovery_dir/elsaconfig.$(date +'%Y%m%d%H%M').tgz"
              tar -cvzf $etcrecovery etc/elsa.d > /dev/null 2>&1
              echo "Time: $(date). Configurations backedup to: $etcrecovery " >> $logfile
              sh -c "cp -a etc/elsa.d/* $etcdir_target/$elsaconf_dir"
              echo "Time: $(date). UPDATED configurations in: $etcdir_target/$elsaconf_dir " >> $logfile
	      echo "Time: $(date). EXIT 6000" >> $logfile
           else
              echo "Time: $(date). No configurations to update" >> $logfile
	      echo "Time: $(date). EXIT 6020" >> $logfile
           fi

           # move new DB into place 


           # Firmware update - we only update if the packaged version is greater then what is on the camera
	   # the firmware directory in the package requires fwversion file with a vaid 3 tupple version number
	   # in the format x.x.x (if it is x.x.x.x the last tupple is ignored.)

           echo "Time: $(date). Checking if we need to update Camera Firmware" >> $logfile
           firmwarefiles=$(ls firmware/* 2> /dev/null | wc -l)
           if [ "$firmwarefiles" != "0" ]; then
              echo "Time: $(date). Need to update Camera Firmware - firmware package found - checking version..." >> $logfile
	      echo "Time: $(date). EXIT 8010" >> $logfile
              # lets get the firware release number from the update pacakge, there should be a file fwversion
              if [ -f "firmware/fwversion" ]; then
                 # ok we got firmware date/version file
		 fwversion=`cat firmware/fwversion`

                 echo "Time: $(date). Firmware package exist - version: $fwversion" >> $logfile
	         echo "Time: $(date). EXIT 8015" >> $logfile

 		 fw_chk_major=$(echo "$fwversion" | cut -f1 -d ".")
		 fw_chk_major_two=$(echo "$fwversion" | cut -f2 -d ".")
		 fw_chk_minor=$(echo "$fwversion" | cut -f3 -d ".")

	         # Do firmware upgrade if needed -- check if firmware is below the new firmware update
	         # We need the Bus and Device the camera is attached to
                 bus=`lsusb | grep "Intel Corp." | cut -f1 -d ":" | cut -f2 -d " "`
                 device=`lsusb | grep "Intel Corp." | cut -f1 -d ":" | cut -f4 -d " "`
                 echo "Time: $(date). Camera is on Bus: $bus and Device: $device " >> $logfile

	         # get the current Firmware version
                 fw_version=`intel-realsense-dfu -b $bus -d $device  -p | grep "FW version on device" | cut -f2 -d "=" | awk '{$1=$1};1'`
                 echo "Time: $(date). Current Camera Firmware is: $fw_version " >> $logfile

                 # we need to get the first three tupples of firmware number so we can see if the firmware as part of the 
                 # update packages is actually newer
		 fw_major=$(echo "$fw_version" | cut -f1 -d ".")
		 fw_major_two=$(echo "$fw_version" | cut -f2 -d ".")
		 fw_minor=$(echo "$fw_version" | cut -f3 -d ".")

		 # Now do version compare and make sure we are pushing in a newer version
		 update_firmware=0

		 if [ "$fw_chk_major" -gt "$fw_major" ]; then
		    echo "Major Greater -- NEED Update" >> $logfile
		    update_firmware=1
		 else
		    if [ "$fw_chk_major" -eq "$fw_major" ]; then
		       # if the majors are the same it is possible that the next sub_major is same or greater etc
		       if [ "$fw_chk_major_two" -gt "$fw_major_two" ]; then
	 	          echo "Time: $(date). Major Two Greater -- NEED Update" >> $logfile
		          update_firmware=1
		       else
		          if [ "$fw_chk_major_two" -eq "$fw_major_two" ]; then
		             # if the majors two are the same it is possible that the next minor is same or greater etc
		             if [ "$fw_chk_minor" -gt "$fw_minor" ]; then
		                echo "Time: $(date). Minor Greater -- NEED Update" >> $logfile
		                update_firmware=1
		             else
		                update_firmware=0
		             fi
		          else
		             update_firmware=0
		          fi
		       fi
		    else
		       echo "Time: $(date). Current firmware has higher or equal major number - so we are NOT updating" >> $logfile
	               echo "Time: $(date). EXIT 8020" >> $logfile
		       update_firmware=0
		    fi 
		 fi
		 echo "Time: $(date). Update Flag: $update_firmware " >> $logfile
		 if [ "$update_firmware" -eq 1 ]; then
   		    echo "Time: $(date). FLAG set do firmware update" >> $logfile
	            echo "Time: $(date). EXIT 8030" >> $logfile

		    # Now we need to run the FIRMWARE update routines.
		    # We need to check if we have a bin file just in case
                    echo "Time: $(date). Checking if we have Camera Firmware bin file" >> $logfile
                    firmwarefiles=$(ls firmware/*.bin 2> /dev/null | wc -l)
                    if [ "$firmwarefiles" != "0" ]; then
                       echo "Time: $(date). Need to update Camera Firmware - firmware package found - getting bin file..." >> $logfile
	               echo "Time: $(date). EXIT 8035" >> $logfile
		       # Now we need to grap the bin file
		      firmwarebin=`ls firmware/*.bin`
                      echo "Time: $(date). Firmware BIN file: $firmwarebin " >> $logfile
		      intel-realsense-dfu -b $bus -d $device -f -i $firmwarebin >> $logfile
		      echo "Time: $(date). Firmware has been updates succesfully " >> $logfile
	              echo "Time: $(date). EXIT 8000" >> $logfile
  		    fi
                 else
                    echo "Time: $(date). No camera firmware update to be performed...skipping update " >> $logfile
	            echo "Time: $(date). EXIT 8040" >> $logfile
                 fi
              else
	        echo "Time: $(date). No camera firmware update version found....skipping update " >> $logfile
	        echo "Time: $(date). EXIT 8045" >> $logfile
              fi
           else
	      echo "Time: $(date). No camera firmware update version found....skipping update " >> $logfile
	      echo "Time: $(date). EXIT 8045" >> $logfile
           fi

           echo "Time: $(date). Update complete - move update source file $extractfile to recovery directory: $recovery_dir" >> $logfile
           mv ../$extractfile $recovery_dir/$extractfile.$(date +'%Y%m%d%H%M')
           echo "Time: $(date). Update complete - move update sha256 checksum file $shafile to recovery directory: $recovery_dir" >> $logfile
	   mv ../$shafile $recovery_dir/$shafile.$(date +'%Y%m%d%H%M')

           # do last step - update the MOTD 
           echo "Time: $(date). Updating MOTD to reflect installed patch level" >> $logfile
           echo "\n" >> $motd_dir"motd"				# always add a blank line first
	   cat $motdedit >> $motd_dir"motd"
           cat $motd_dir"motd"

           echo "Time: $(date). Update complete - please power cylce unit" >> $logfile
           echo "Time: $(date). EXIT 1000" >> $logfile

       else  
           echo "Time: $(date). Update version in archive mismatch - no update directory $version - update aborted" >> $logfile
           echo "Time: $(date). EXIT 3030" >> $logfile
       fi

     fi


  else
     echo "Time: $(date). Update ABORTED update pakage of $extractfile does not exist" >> $logfile
     echo "Time: $(date). EXIT 3040" >> $logfile
     exit 2025
  fi

else
  echo "Time: $(date). Update ABORTED no update package found" >> $logfile
  echo "Time: $(date). EXIT 1030" >> $logfile
fi
