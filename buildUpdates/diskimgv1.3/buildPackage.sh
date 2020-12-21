#!/bin/sh
#
# Author:	Willem
# Date:		01-06-2020
# Version:	V0.1
#
# Build the package after the proper directory structure has been populated and is ready for
# delivery

# Current version
version="V1.0 - 01-10-20202"

# input required is the update package name like v000x 
helpFunction()
{
   echo ""
   echo "Usage: $0 -p packagename -h"
   echo "\t-p Packagename in the form v000x expected"
   exit 1 # Exit script after printing help
}

versionFunction()
{
   echo ""
   echo "Current version of script: $0 version: $version ";
   exit 1 # Exit script after printing help
}

while getopts ":phv" opt
do
   case "$opt" in
      p ) package="$OPTARG" ;;
      v ) versionFunction ;;
      h ) helpFunction;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$package" ];
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

# Begin script in case all parameters are correct
echo "$package"

tar -cvzf elsaupdate-$package.tgz $package
sha256sum elsaupdate-$package.tgz > elsaupdate-$package.tgz.sha256
tar -cvzf update-$package.tgz elsaupdate-$package.tgz elsaupdate-$package.tgz.sha256

