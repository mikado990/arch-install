#!/usr/bin/env bash

source $CONFIGS_DIR/setup.conf
timedatectl set-ntp true
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -ne "
-------------------------------------------------------------------------
                    Setting up $iso mirrors for faster downloads
-------------------------------------------------------------------------
"
reflector -a 48 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
echo -ne "
-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------
"
pacman -S --noconfirm --needed gptfdisk glibc
echo -ne "
-------------------------------------------------------------------------
                    Formating Disk
-------------------------------------------------------------------------
"
umount -A --recursive /mnt # make sure everything is unmounted before we start
# disk prep
sgdisk -Z ${DISK} # zap all on disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' ${DISK} # partition 1 (BIOS Boot Partition)
sgdisk -n 2::+2G --typecode=2:ef00 --change-name=2:'EFIBOOT' ${DISK} # partition 2 (UEFI Boot Partition)
sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' ${DISK} # partition 3 (Root), default start, remaining

partprobe ${DISK} # reread partition table to ensure it is correct

# make filesystems
echo -ne "
-------------------------------------------------------------------------
                    Creating Filesystems
-------------------------------------------------------------------------
"
if [[ "${DISK}" =~ "nvme" ]]; then
    partition2=${DISK}p2
    partition3=${DISK}p3
else
    partition2=${DISK}2
    partition3=${DISK}3
fi

mkfs.vfat -F32 -n "EFIBOOT" ${partition2}
mkfs.ext4 -L ROOT ${partition3}
mount -t ext4 ${partition3} /mnt

# mount target
mkdir -p /mnt/boot/efi
mount -t vfat -L EFIBOOT /mnt/boot/

if ! grep -qs '/mnt' /proc/mounts; then
    echo "Drive is not mounted can not continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi
echo -ne "
-------------------------------------------------------------------------
                    Arch Install on Main Drive
-------------------------------------------------------------------------
"
pacstrap -K /mnt base base-devel linux linux-headers linux-firmware
cp -R ${SCRIPT_DIR} /mnt/root/arch-install

genfstab -U /mnt >> /mnt/etc/fstab
echo "
  Generated /etc/fstab:
"
cat /mnt/etc/fstab

echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 1-setup.sh
-------------------------------------------------------------------------
"
