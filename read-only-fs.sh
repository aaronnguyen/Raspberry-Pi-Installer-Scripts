#!/bin/bash

# Original from: 
#   https://github.com/adafruit/Raspberry-Pi-Installer-Scripts/blob/master/read-only-fs.sh
#   has some package dependencies needed from apt-get, should be installed already.

# Check for sudo
if [ $(id -u) -ne 0 ]; then
	echo "Installer must be run as root."
	echo "Try 'sudo bash $0'"
	exit 1
fi

# Check if readonlyfs is already installed, exit if it is
RUNFLAG=/opt/readonlyfs.host
if [ -f RUNFLAG ]; then
    echo "Already in readonly state."
    exit 0
fi

NETWORKFLAG=/opt/networksetup.host
# If setup is not ready, then ignore this script
if [ ! -f NETWORKFLAG ]; then 
    echo "Network not setup yet.. will wait..."
    exit 0
fi

# If it has gotten to this point, then gateway is ready for installation
# Add a flag to notify system if the system is already in read only
# echo "Create flag to notify system that it is already read only..."
touch RUNFLAG

# FEATURE PROMPTS ----------------------------------------------------------

SYS_TYPES=(Pi\ 3\ /\ Pi\ Zero\ W All\ other\ models)
WATCHDOG_MODULES=(bcm2835_wdog bcm2708_wdog)
OPTION_NAMES=(NO YES)

# START INSTALL ------------------------------------------------------------

# Given a filename, a regex pattern to match and a replacement string:
# Replace string if found, else no change.
# (# $1 = filename, $2 = pattern to match, $3 = replacement)
replace() {
	grep $2 $1 >/dev/null
	if [ $? -eq 0 ]; then
		# Pattern found; replace in file
		sed -i "s/$2/$3/g" $1 >/dev/null
	fi
}

# Given a filename, a regex pattern to match and a replacement string:
# If found, perform replacement, else append file w/replacement on new line.
replaceAppend() {
	grep $2 $1 >/dev/null
	if [ $? -eq 0 ]; then
		# Pattern found; replace in file
		sed -i "s/$2/$3/g" $1 >/dev/null
	else
		# Not found; append on new line (silently)
		echo $3 | sudo tee -a $1 >/dev/null
	fi
}

# Given a filename, a regex pattern to match and a string:
# If found, no change, else append file with string on new line.
append1() {
	grep $2 $1 >/dev/null
	if [ $? -ne 0 ]; then
		# Not found; append on new line (silently)
		echo $3 | sudo tee -a $1 >/dev/null
	fi
}

# Given a filename, a regex pattern to match and a string:
# If found, no change, else append space + string to last line --
# this is used for the single-line /boot/cmdline.txt file.
append2() {
	grep $2 $1 >/dev/null
	if [ $? -ne 0 ]; then
		# Not found; insert in file before EOF
		sed -i "s/\'/ $3/g" $1 >/dev/null
	fi
}

# Install watchdog
# $MODULE is specific watchdog module name
MODULE=${WATCHDOG_MODULES[($WD_TARGET-1)]}
# Add to /etc/modules, update watchdog config file
append1 /etc/modules $MODULE $MODULE
replace /etc/watchdog.conf "#watchdog-device" "watchdog-device"
replace /etc/watchdog.conf "#max-load-1" "max-load-1"
# Start watchdog at system start and start right away
# Raspbian Stretch needs this package installed first
insserv watchdog; /etc/init.d/watchdog start
# Additional settings needed on Jessie
append1 /lib/systemd/system/watchdog.service "WantedBy" "WantedBy=multi-user.target"
systemctl enable watchdog
# Set up automatic reboot in sysctl.conf
replaceAppend /etc/sysctl.conf "^.*kernel.panic.*$" "kernel.panic = 10"

# Add fastboot, noswap and/or ro to end of /boot/cmdline.txt
append2 /boot/cmdline.txt fastboot fastboot
append2 /boot/cmdline.txt noswap noswap
append2 /boot/cmdline.txt ro^o^t ro

# Move /var/spool to /tmp
rm -rf /var/spool
ln -s /tmp /var/spool

# Move /var/lib/lightdm and /var/cache/lightdm to /tmp
rm -rf /var/lib/lightdm
rm -rf /var/cache/lightdm
ln -s /tmp /var/lib/lightdm
ln -s /tmp /var/cache/lightdm

# Make SSH work
replaceAppend /etc/ssh/sshd_config "^.*UsePrivilegeSeparation.*$" "UsePrivilegeSeparation no"
# bbro method (not working in Jessie?):
#rmdir /var/run/sshd
#ln -s /tmp /var/run/sshd

# Change spool permissions in var.conf (rondie/Margaret fix)
replace /usr/lib/tmpfiles.d/var.conf "spool\s*0755" "spool 1777"

# Move dhcpd.resolv.conf to tmpfs
touch /tmp/dhcpcd.resolv.conf
rm /etc/resolv.conf
ln -s /tmp/dhcpcd.resolv.conf /etc/resolv.conf

# Make edits to fstab
# make / ro
# tmpfs /var/log tmpfs nodev,nosuid 0 0
# tmpfs /var/tmp tmpfs nodev,nosuid 0 0
# tmpfs /tmp     tmpfs nodev,nosuid 0 0
replace /etc/fstab "vfat\s*defaults\s" "vfat    defaults,ro "
replace /etc/fstab "ext4\s*defaults,noatime\s" "ext4    defaults,noatime,ro "
append1 /etc/fstab "/var/log" "tmpfs /var/log tmpfs nodev,nosuid 0 0"
append1 /etc/fstab "/var/tmp" "tmpfs /var/tmp tmpfs nodev,nosuid 0 0"
append1 /etc/fstab "\s/tmp"   "tmpfs /tmp    tmpfs nodev,nosuid 0 0"

# REBOOT
reboot
exit 0
