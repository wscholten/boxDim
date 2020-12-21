# boxDim

Dimensioning Project

There are two sets of update scripts which are triggered and controlled by the Elsa desktop application.  The first set of scripts does an in place update of the Elsa runtime environment.  The second set does a / (root) partition restore from a flash drive containing an updated image for the system.  All scripts live in /usr/local/updates

extractupdate.sh    -- none sha256 verification update script
extractupdatev2.sh  -- contains sha256 verification of the update (preferred)
extractupdatev3.sh  -- contains the ability to selfupdate the install scripts, as well as update camera firmware.  This is the current active script to be used on the Beta units for pre-prductin testing.

The update scripts rely on a package to come over which is called update-v0005.tgz where v0005 is the update package version.  The package for updating itself is build using the elsaupdate-v000x.tgz which will create a blank set of directories in a folder v000x.  This folder should be renamed to the new version number, forexample v0005, and subsequently populated with the various update binaries, including firmware for the camera if desired.

partitionreboot.sh  -- a shell script which is run by cron at @reboot which will trigger a reboot of the system into an automated clonezilla based restore of the / (root) partititon. Requires a cron entry (see below)

partitionupdate.sh  -- a shell script triggered by Elsa desktop app, verifying the flash drive has the correct to be updated image, and subsequently triggering on next reboot (power cycle) a resotre via clonezilla (calling partitionreboot.sh)  The image udpate file/directory on the flashdrive MUST be called mmcblk0p2-update and the subsequent mmcblk0p2-update.sha256 file must exist in the root of the flash drive.

To create the sha256 checksum file use the following commands

cd mmcblk0p2-update
sha256sum mmcblk0p2.ext4-ptcl-img.gz.aa > /tmp/mmcblk0p2-update.sha256

Then copy the subsequent /tmp/mmcblk0p2-update.sha256 to the root of the flash drive, which should have a directory mmcblk0p2-update which contains the partition update itself.

CRON entry required
sudo crontab -e

add line:
@reboot sleep 120 && /usr/local/updates/partitionreboot.sh >> /var/log/elsa/cron.log

CRON Note - the sleep can likely be reduced to 60, but for testing to give enough time to interrupt 120 is a safe bet.

GRUB Entries
In order for this process to work, a custom grub menu is required, the file 40_custom should be placed in /etc/grub.d after installation, the following command is required to active the scripts:

sudo update-grub
