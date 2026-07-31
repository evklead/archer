#!/bin/bash
set -e

source /opt/top-off/config.sh

ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
hwclock --systohc
sed -i "s/#$LOCALE/$LOCALE/g" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" >/etc/locale.conf
echo "KEYMAP=$KEYMAP" >/etc/vconsole.conf
read -p "Hostname: " hostname
echo "$hostname" > /etc/hostname

read -p "Username: " NEWUSER
useradd -d /home/$NEWUSER $NEWUSER
usermod -aG wheel $NEWUSER
sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g" /etc/sudoers
echo "Setting password for $NEWUSER..."
passwd $NEWUSER

mkdir /home/$NEWUSER
cp -r /opt/top-off/usercontent/home/. /home/$NEWUSER

chmod -R 755 /opt/top-off/usercontent/scripts
export NEWUSER
for script in $(find /opt/top-off/usercontent/scripts -type f); do
    /usr/bin/sh -c "$script"
done

chown -R $NEWUSER:$NEWUSER /home/$NEWUSER

while read service ; do
    systemctl enable $service
done < /opt/top-off/services.txt

bootctl install

if ! [ -z "$rootlukspart" ]; then
    sed -i "s/sd-vconsole block/sd-vconsole sd-encrypt block/g" /etc/mkinitcpio.conf
    mkinitcpio -P
#    sbctl create-keys
#    sbctl enroll-keys -m
#    sbctl sign -s /boot/vmlinuz-linux
#    sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
#    sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
    PASSWORD=$lukspwd systemd-cryptenroll --tpm2-device=auto $rootlukspart

    if ! [ -z "$homelukspart" ]; then
        PASSWORD=$lukspwd systemd-cryptenroll --tpm2-device=auto $homelukspart
    fi
fi

read -p "Install desktop environment? [y/N] " yn
if ! [[ "$yn" =~ ^[Yy]$ ]]; then
    echo "Finishing the installation process..."
else
    pacman -S $(grep -v '^#' /opt/top-off/desktop_list.txt | grep -v '^$')
    while read service ; do
        systemctl enable $service
    done < /opt/top-off/desktop_services.txt
fi

cp /opt/top-off/system_backup.sh /usr/local/bin
chmod 744 /usr/local/bin/system_backup.sh
mkdir -p /etc/pacman.d/hooks
cp /opt/top-off/pre-install-backup.hook /etc/pacman.d/hooks

rm -r /opt/top-off
/usr/local/bin/system_backup.sh _install-script-$(date "+%F-%T")
