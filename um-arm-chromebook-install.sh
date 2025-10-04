#!/bin/bash
set -e

# Ultramarine arm chromebook moment
# By: WeirdTreeThing

# lets try to figure out the boot device (sorry to the one mt8195 user with nvme)
LIKELY_BOOTDEV="$(ls /dev/mmcblk*boot0 | sed 's/boot0//')"
echo "Your internal drive (probably): $LIKELY_BOOTDEV"
printf "Type the full path of your internal drive: "
read -r DISK
printf "Are you sure you want to install to '$DISK'? All data will be wiped! (y/N) "
read -r CONF
if [[ $CONF =~ ^[Yy]$ ]]; then
	# installing stuff

	# partition drive
	echo "Partitioning drive"
	wipefs -af $DISK
	parted -s $DISK mklabel gpt
	parted -s -a optimal $DISK unit mib mkpart submarine 1 65
	parted -s -a optimal $DISK unit mib mkpart boot 65 1089
	parted -s $DISK type 2 bc13c2ff-59e6-4262-a352-b275fd6f7172
	parted -s -a optimal $DISK unit mib mkpart root 1089 100%
	cgpt add -i 1 -t kernel -P 15 -T 1 -S 1 $DISK
	partprobe $DISK

	# filesystems
	# first wipe any that may exist
	echo "Formatting drive"
	wipefs -af ${DISK}p2
	wipefs -af ${DISK}p3
	mkfs.ext4 ${DISK}p2
	mkfs.btrfs ${DISK}p3
	# uuids
	OLDBOOTUUID="$(blkid -s UUID -o value $(findmnt -n -o SOURCE /boot))"
	OLDROOTUUID="$(blkid -s UUID -o value $(findmnt -n -o SOURCE /))"
	BOOTUUID="$(blkid -s UUID -o value ${DISK}p2)"
	ROOTUUID="$(blkid -s UUID -o value ${DISK}p3)"
	# mounts
	mkdir /newinstall
	mount ${DISK}p3 /newinstall
	mkdir /newinstall/boot
	mount ${DISK}p2 /newinstall/boot

	# copy data from current install
	echo "Copying files"
	rsync -aHAXErp --info=progress2 --no-inc-recursive --exclude=/newinstall --exclude=/tmp/* --exclude=/var/tmp/* --exclude=/dev/* --exclude=/sys/* --exclude=/proc/* --exclude=/run/* --exclude=/var/cache/* --exclude=/lost+found/* / /newinstall

	# Fixup UUIDs
	sed -i "s|$OLDROOTUUID|$ROOTUUID|g" /newinstall/etc/kernel/cmdline
	sed -i "s|$OLDROOTUUID|$ROOTUUID|g" /newinstall/boot/loader/entries/*.conf
	sed -i "s|$OLDROOTUUID|$ROOTUUID|g" /newinstall/etc/fstab
	sed -i "s|$OLDBOOTUUID|$BOOTUUID|g" /newinstall/etc/fstab

	# Install submarine
	echo "Installing submarine"
	cat /usr/share/submarine/submarine-a64.kpart > ${DISK}p1

	# Cleanup
	umount -R /newinstall
	sync

	echo "Done!"
else
	echo "Exiting"
	exit
fi
