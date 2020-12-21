#!/bin/sh
#
# Author:	Willem
# Date:		06-01-2020
# Version:	V0.1
#
#  prunedisk - prunes the /var/elsa/images directory by deleting  images by removing oldest
# 	       first until space has been freed back into the given tolerance
#
# Changed:	09-01-2020
# Author:	Willem
# changes:	added bility to prune down to day level
#
# This script should be run by CRON as the user ioline and does NOT have system level
# priviledges.
#
# Install script in cron as follows:
# sudo ln -s /usr/local/updates/prunedisk.sh /etc/cron.hourly/prunedisk.sh


prune_dir="/var/elsa/images"
prune_time="/usr/local/updates/prunetime"
capacity_limit=95				# when to trigger pruning  (95)
capacity_lowlevel=85				# when pruning the lower ceiling to prune towards (85)
prunedaylevel=1					# if prunedaylevel = 1 -- delete by day not at month level

#set log file location
pruneLogfile="/var/elsa/log/diskprune.log"
logfile="/var/elsa/log/elsa.log"		# Write notices to main ELSA log file

# we need some logfile sanity check here - in case they don;t exists we need to create them
if [ -f "$pruneLogfile" ]; then
   # logfile exists we can append
   echo "Time: $(date). Disk Pruning Logifle active " >> $pruneLogfile
else
   echo "Time: $(date). Start of new Disk Pruning logfile " > $pruneLogfile
fi

echo "Time: $(date). Starting Disk Pruning Routine. " >> $logfile
 
if [ -d $prune_dir ]; then
    cd $prune_dir
    echo "Time: $(date). Changing to prune directory: $prune_dir" >> $pruneLogfile
else 
    echo "Time: $(date). ERROR: unable to chdir to directory: $prune_dir " >> $pruneLogfile
    exit 2
fi

# get the current capcity percentage for the partition the directory we want to prune is on
capacity_current=$(df -k . | awk '{gsub("%",""); $capacity_current=$5}; END {print $capacity_current}')
echo "Time: $(date). Current capacity of partition: $capacity_current -- disk may not be fuller then: $capacity_limit " >> $pruneLogfile

last_prune_time=$(cat $prune_time)
echo "Time: $(date). Last pruning took place on: $last_prune_time " >> $pruneLogfile

# lets record the last time we fired the pruning script
touch $prune_time
date > $prune_time

if [ $capacity_current -gt $capacity_limit ]; then
    #
    # Get list of files, oldest first.
    # Delete the oldest files until
    # we are below the limit. Just
    # delete regular files, ignore directories.
    #
    ls -rt | while read YEAR
    do
        echo "Time: $(date). Processing image year directory: $YEAR" >> $pruneLogfile
        cd $YEAR
        echo "Time: $(date). Moved to year directory: $(pwd)" >> $pruneLogfile
        #now we need to list all the moth's in oldest order first
        ls -rt | while read MONTH
        do
           echo "Time: $(date). Processing Month directory: $MONTH of year: $YEAR" >> $pruneLogfile
	   # we will now delete the full month worth of data
 
           # check if we need to go down to day level
           if [ $prunedaylevel -eq '1' ]; then
	      # we are pruning down to day level
              cd $MONTH				// go into the first month
	      echo "Time: $(date). Processing Month directory: $MONTH - looking for days to delete" >> $pruneLogfile
              ls -rt | while read DAY
	      do
                 echo "Time: $(date). Processing Day directory: $DAY of month: $MONTH and year: $YEAR" >> $pruneLogfile
                 rm -rf $DAY
                 echo "Time: $(date). Delete permanently $DAY from system" >> $pruneLogfile
                 # Now we need to check if we have dropped below $capcity_limit  and we meed to chec
                 # if we have reached the $capacity_lowlevel - which is the minimum space we need to have free
                 capacity_current=$(df -k . | awk '{gsub("%",""); capacity_current=$5}; END {print capacity_current}')
                 echo "Time: $(date). New current capacity of partition after delete: $capacity_current" >> $pruneLogfile
                 if [ $capacity_current -le $capacity_lowlevel ]; then
                    # we're below the limit, so stop deleting
                    echo "Time: $(date). Current capacity: $capacity_current is below minimum free space of: $capacity_lowlevel" >> $pruneLogfile
                    echo "Time: $(date). Exiting day deleting for month: $MONTH and year: $YEAR " >> $pruneLogfile
                    exit				# This only drops us out of first while loop
                 fi
              done
              cd ..					# we need to go out of the month we jsut completed
	      # we now should check if the $MONTH is empty if so we should remove the empty $MONTH
              files=$(ls $MONTH/* 2> /dev/null | wc -l)
              if [ "$files" -eq "0" ]; then
                 # we got no days left so lets remove month
                 echo "Time: $(date). Content of month: $MONTH and year: $YEAR is empty - remove $MONTH " >> $pruneLogfile
                 rm -rf $MONTH
              fi
           else 
              # we should delete MONTH
              rm -rf $MONTH
              echo "Time: $(date). Deleted permanently $MONTH from system" >> $pruneLogfile
              # Now we need to check if we have dropped below $capcity_limit  and we meed to chec
              # if we have reached the $capacity_lowlevel - which is the minimum space we need to have free
              capacity_current=$(df -k . | awk '{gsub("%",""); capacity_current=$5}; END {print capacity_current}')
              echo "Time: $(date). New current capacity of partition after delete: $capacity_current" >> $pruneLogfile
              if [ $capacity_current -le $capacity_lowlevel ]; then
                 # we're below the limit, so stop deleting
                 echo "Time: $(date). Current capacity: $capacity_current is below minimum free space of: $capacity_lowlevel" >> $pruneLogfile
                 echo "Time: $(date). Exiting month deleting for year: $YEAR " >> $pruneLogfile
                 exit				# This only drops us out of first while loop
              fi
           fi
        done
	# move back to year directory (we were in a year, deleted some month)
        cd ..
	# we now should check if the $MONTH is empty if so we should remove the empty $MONTH
        files=$(ls $YEAR/* 2> /dev/null | wc -l)
        if [ "$files" -eq "0" ]; then
           # we got no days left so lets remove month
           echo "Time: $(date). Content of Year: $YEAR is empty - remove $YEAR " >> $pruneLogfile
           rm -rf $YEAR
        fi

        # We need to for safety doubloe check if we reached lowerlimit yet, we can coem here two ways
        # We broke out of inner while loop having reached lowerlimit, or we exhausted the optiosn to delete
        # image directories 

        echo "Time: $(date). Checking if we still need to delete more for subsequent years" >> $pruneLogfile 
        capacity_current=$(df -k . | awk '{gsub("%",""); capacity_current=$5}; END {print capacity_current}')
        if [ $capacity_current -le $capacity_lowlevel ]; then
           # we're below the limit, so stop deleting
           echo "Time: $(date). Current capacity: $capacity_current is below minimum free space of: $capacity_lowlevel" >> $pruneLogfile
           echo "Time: $(date). Exiting year deleting  - we should be finished" >> $pruneLogfile
           exit
        fi
    done
    # it is possible to get here while we have deleted everythign yet not reached the minimum required
    # space
    capacity_current=$(df -k . | awk '{gsub("%",""); capacity_current=$5}; END {print capacity_current}')
    if [ $capacity_current -gt $capacity_lowlevel ]; then
       # we're got a problem.... w ere not bale to free up enough space
       echo "Time: $(date). WARNING: Current capacity: $capacity_current is NOT below minimum free space of: $capacity_lowlevel" >> $pruneLogfile
       echo "Time: $(date). WARNING: System needs to find additional space please notify tech support" >> $pruneLogfile

       echo "Time: $(date). WARNING DISK PRUNING: Current capacity: $capacity_current is NOT below minimum free space of: $capacity_lowlevel" >> $logfile
       echo "Time: $(date). WARNING DISK PRUNING: System needs to find additional space please notify tech support" >> $logfile
    fi
else
   capacity_current=$(df -k . | awk '{gsub("%",""); capacity_current=$5}; END {print capacity_current}')
   echo "Time: $(date). NO pruning required current capcity: $capacity_current below the minimum threshold of: $capacity_lowlevel" >> $pruneLogfile
fi
echo "Time: $(date). Finished Disk Pruning Routine. " >> $logfile

