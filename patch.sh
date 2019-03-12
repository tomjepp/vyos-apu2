#!/bin/bash

set -e

# Check usage

if [ $# != 1 ]; then
	echo "Usage: patch.sh <iso>"
	exit 1
fi

if ! [ $(id -u) = 0 ]; then
	echo "This script needs to run as root."
	exit 1
fi

ISO="$(realpath ${1})"
OUT_ISO="${ISO}.apu2.iso"

# Check dependencies
if ! which 7z > /dev/null 2>&1; then
	echo "Install p7zip!"
	exit 1
fi

if ! which unsquashfs > /dev/null 2>&1; then
	echo "Install squashfs tools!"
	exit 1
fi

if ! which mksquashfs > /dev/null 2>&1; then
	echo "Install squashfs tools!"
	exit 1
fi

if ! which mkisofs > /dev/null 2>&1; then
	echo "Install mkisofs!"
	exit 1
fi

if ! which isohybrid > /dev/null 2>&1; then
	echo "Install isohybrid!"
	exit 1
fi


echo "Unpacking ${ISO}..."
mkdir -p tmp/iso
pushd tmp/iso > /dev/null
7z x -y -bsp0 -bso0 "${ISO}" > /dev/null 2>&1

echo "Patching isolinux config..."
echo "serial 0 115200
console 0
timeout 50
prompt 1
include live.cfg
default live-amd64-vyos" > isolinux/isolinux.cfg

sed -i 's/append boot=live/append console=ttyS0,115200n8 boot=live/' isolinux/live.cfg
sed -i '/menu /d' isolinux/live.cfg
popd > /dev/null

echo "Unpacking squashfs..."
unsquashfs -d tmp/squashfs tmp/iso/live/filesystem.squashfs

echo "Patching squashfs..."
pushd tmp/squashfs > /dev/null
sed -i 's/9600/115200/' opt/vyatta/sbin/vyatta-grub-setup
sed -i 's/9600/115200/' opt/vyatta/etc/config.boot.default
sed -i 's/9600/115200/' opt/vyatta/etc/grub/default-union-grub-entry
sed -i 's/9600/115200/' opt/vyatta/etc/config-migrate/migrate/system/3-to-4
popd > /dev/null

echo "Repacking squashfs..."
rm tmp/iso/live/filesystem.squashfs
mksquashfs tmp/squashfs tmp/iso/live/filesystem.squashfs -noappend -comp xz

echo "Repacking iso..."
mkisofs -o "${OUT_ISO}" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -iso-level 3 -J tmp/iso > /dev/null 2>&1

echo "Running isohybrid..."
isohybrid "${OUT_ISO}"

# Finish up
echo "Cleaning up..."
rm -R tmp

echo "Done!"
