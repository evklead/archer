#!/bin/sh

BOOTMOUNT=/boot
ROOTSNAPSUBVOL=/.snapshots

tag=$1

if [ "$(df -P /home | tail -n 1 | awk '{print $1}')" != "$(df -P / | tail -n 1 | awk '{print $1}')" ]; then
    HOMESNAPSUBVOL=/home/.snapshots
else
    HOMESNAPSUBVOL=/.snapshots
fi

set -e

mkdir -p $ROOTSNAPSUBVOL/boot
cp -r $BOOTMOUNT $ROOTSNAPSUBVOL/boot/$tag
btrfs subvol snapshot -r / $ROOTSNAPSUBVOL/root_$tag
btrfs subvol snapshot -r /home $HOMESNAPSUBVOL/home_$tag
