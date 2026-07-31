#!/bin/bash

set -e

echo "Server = http://192.168.101.11:7878/\$repo/os/\$arch" >/etc/pacman.d/mirrorlist
echo "Server = https://nocix.mm.fcix.net/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist

echo "Available drives:"
lsblk -do NAME,SIZE,MODEL

while true; do
    read -p "Device name to use for ROOT: " rootdisk
    if [ -z "$rootdisk" ]; then
        echo "Please provide a correct device name."
    elif [ ! -b "/dev/$rootdisk" ]; then
        echo "The drive doesn't exist. Try again."
    else
        break
    fi
done

read -p "Use a separate drive for HOME? [y/n] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    while true; do
        read -p "Device name to use for HOME: " homedisk
        if [ -z "$homedisk" ]; then
            echo "Please provide a correct device name."
        elif [ ! -b "/dev/$homedisk" ]; then
            echo "The device doesn't exist. Try again."
        elif [ "$homedisk" == "$rootdisk" ]; then
            echo "ERROR - trying to set up a separate drive for HOME but using the same device name as for ROOT. Try again."
        else
            break
        fi
    done
fi

rootdisk="/dev/$rootdisk"
if ! [ -z $homedisk ]; then
    homedisk="/dev/$homedisk"
fi

read -p "ALL EXISTING DATA on $rootdisk $homedisk WILL BE DESTROYED!!! PROCEED? [y/n] " yn
if ! [[ "$yn" =~ ^[Yy]$ ]]; then
    echo "Aborting..."
    exit 1
fi

parted -s -a optimal $rootdisk mklabel gpt
parted -s -a optimal $rootdisk mkpart primary 0% 1G
parted -s $rootdisk set 1 esp on
parted -s $rootdisk set 1 boot on
parted -s -a optimal $rootdisk mkpart primary 1G 100%
parted $rootdisk print
sync

if ! [ -z $homedisk ]; then
    parted -s -a optimal $homedisk mklabel gpt
    parted -s -a optimal $homedisk mkpart primary 0% 100%
    parted $homedisk print
    sync
fi

bootpart=$(lsblk -nr -o NAME,PARTTYPE $rootdisk | awk '$2=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"{print "/dev/"$1}')
rootpart=$(lsblk -nr -o NAME,PARTTYPE $rootdisk | awk '$2=="0fc63daf-8483-4772-8e79-3d69d8477de4"{print "/dev/"$1}')
if ! [ -z $homedisk ]; then
    homepart=$(lsblk -nr -o NAME,PARTTYPE $homedisk | awk '$2=="0fc63daf-8483-4772-8e79-3d69d8477de4"{print "/dev/"$1}')
fi

mkfs.vfat $bootpart

read -p "Use LUKS? [y/n] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    read -p "Disk Encryption Password: " lukspwd
    printf '%s' "$lukspwd" | cryptsetup -q luksFormat $rootpart -d -
    printf '%s' "$lukspwd" | cryptsetup open $rootpart cryptroot -d -
    rootlukspart=$rootpart
    rootpart="/dev/mapper/cryptroot"
    if ! [ -z $homepart ]; then
        printf '%s' "$lukspwd" | cryptsetup -q luksFormat $homepart -d -
        printf '%s' "$lukspwd" | cryptsetup open $homepart crypthome -d -
        homelukspart=$homepart
        homepart="/dev/mapper/crypthome"
    fi
else
    echo "Encryption won't be used"
fi

mkfs.btrfs -f -L ArchSystem $rootpart
sync
mount $rootpart /mnt
btrfs subvol create /mnt/rootfs
btrfs subvol create /mnt/snapshots
if [ -z $homepart ]; then
    btrfs subvol create /mnt/homefs
    umount /mnt
else
    umount /mnt
    mkfs.btrfs -f -L Home $homepart
    sync
    mount $homepart /mnt
    btrfs subvol create /mnt/homefs
    btrfs subvol create /mnt/snapshots
    umount /mnt
fi

mount -o noatime,compress=zstd:1,ssd,discard=async,subvol=/rootfs $rootpart /mnt
mkdir /mnt/boot
chmod 700 /mnt/boot
mkdir /mnt/home
mkdir /mnt/.snapshots
mount -o noatime,compress=zstd:1,ssd,discard=async,subvol=/snapshots $rootpart /mnt/.snapshots
if [ -z $homepart ]; then
    mount -o noatime,compress=zstd:1,ssd,discard=async,subvol=/homefs $rootpart /mnt/home
else
    mount -o noatime,compress=zstd:1,ssd,discard=async,subvol=/homefs $homepart /mnt/home
    mkdir /mnt/home/.snapshots
    mount -o noatime,compress=zstd:1,ssd,discard=async,subvol=/snapshots $homepart /mnt/home/.snapshots
fi
mount $bootpart -o fmask=0077,dmask=0077 /mnt/boot

if lspci | grep -q NVIDIA ; then
    nvidia="nvidia-open"
fi

pacstrap -K /mnt $(grep -v '^#' pacstrap_list.txt | grep -v '^$') $nvidia

if ! [ -z $homelukspart ]; then
    homeluksuuid=$(blkid -s UUID -o value $homelukspart)
    echo "crypthome UUID=$homeluksuuid none tpm2-device=auto" >> /mnt/etc/crypttab
fi

genfstab -U /mnt >> /mnt/etc/fstab

mkdir -p /mnt/boot/loader/entries
if [ -z $rootlukspart ]; then
    cp arch.conf /mnt/boot/loader/entries/arch.conf
    rootuuid=$(blkid -s UUID -o value $rootpart)
else
    cp arch-luks.conf /mnt/boot/loader/entries/arch.conf
    rootuuid=$(blkid -s UUID -o value $rootlukspart)
fi
sed -i "s/__UUID__/$rootuuid/g" /mnt/boot/loader/entries/arch.conf

cp -r top-off /mnt/opt

echo "export rootlukspart=$rootlukspart" >> /mnt/opt/top-off/config.sh
if ! [ -z $homelukspart ]; then
    echo "export homelukspart=$homelukspart" >> /mnt/opt/top-off/config.sh
fi
if ! [ -z $lukspwd ]; then
    echo "export lukspwd=$lukspwd" >> /mnt/opt/top-off/config.sh
fi
arch-chroot -S /mnt sh /opt/top-off/top-off.sh
