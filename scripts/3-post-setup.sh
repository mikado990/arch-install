#!/usr/bin/env bash

source ${HOME}/arch-install/configs/setup.conf

if [[ -d "/sys/firmware/efi" ]]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch ${DISK}
fi

echo -ne "
-------------------------------------------------------------------------
               Creating (and Theming) Grub Boot Menu
-------------------------------------------------------------------------
"
# set kernel parameter for decrypting the drive
#if [[ "${FS}" == "luks" ]]; then
#sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
#fi

echo -e "Backing up Grub config..."
cp -an /etc/default/grub /etc/default/grub.bak
echo -e "Updating grub..."
grub-mkconfig -o /boot/grub/grub.cfg
echo -e "All set!"

#echo -ne "
#-------------------------------------------------------------------------
#               Enabling (and Theming) Login Display Manager
#-------------------------------------------------------------------------
#"
#if [[ ${DESKTOP_ENV} == "kde" ]]; then
#  systemctl enable sddm.service
#
#elif [[ "${DESKTOP_ENV}" == "gnome" ]]; then
#  systemctl enable gdm.service
#fi

echo -ne "
-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------
"
systemctl enable ntpd.service
echo "  NTP enabled"
systemctl disable dhcpcd.service
echo "  DHCP disabled"
systemctl enable NetworkManager.service
echo "  NetworkManager enabled"

echo -ne "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------
"
# Remove no password sudo rights
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD:\/sbin\/pacman/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD:\/sbin\/pacman/' /etc/sudoers
# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

rm -r $HOME/arch-install
rm -r /home/$USERNAME/arch-install

# Replace in the same state
cd $pwd
