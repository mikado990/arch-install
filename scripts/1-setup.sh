#!/usr/bin/env bash

source $HOME/arch-install/configs/setup.conf
echo -ne "
-------------------------------------------------------------------------
                    Network Setup 
-------------------------------------------------------------------------
"
pacman -S --noconfirm --needed networkmanager dhclient
systemctl enable --now NetworkManager

nc=$(grep -c ^processor /proc/cpuinfo)
echo -ne "
-------------------------------------------------------------------------
                    You have " $nc" cores. And
			changing the makeflags for "$nc" cores. Aswell as
				changing the compression settings.
-------------------------------------------------------------------------
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $TOTAL_MEM -gt 8000000 ]]; then
sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /etc/makepkg.conf
sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /etc/makepkg.conf
fi
echo -ne "
-------------------------------------------------------------------------
                    Setup Language to US and set locale  
-------------------------------------------------------------------------
"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
# Set keymaps
echo "KEYMAP=pl" > /etc/vconsole.conf

# Add sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

#Add parallel downloading and Color
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf

#Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm --needed

#Fix long shutdowns
sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/system.conf

echo -ne "
-------------------------------------------------------------------------
                    Installing Microcode
-------------------------------------------------------------------------
"
# determine processor type and install microcode
proc_type=$(lscpu)
if grep -E "GenuineIntel" <<< ${proc_type}; then
    echo "Installing Intel microcode"
    pacman -S --noconfirm --needed intel-ucode
    proc_ucode=intel-ucode.img
elif grep -E "AuthenticAMD" <<< ${proc_type}; then
    echo "Installing AMD microcode"
    pacman -S --noconfirm --needed amd-ucode
    proc_ucode=amd-ucode.img
fi

echo -ne "
-------------------------------------------------------------------------
                    Installing Graphics Drivers
-------------------------------------------------------------------------
"
# Graphics Drivers find and install
pacman -S --noconfirm --needed nvidia-lts nvidia-utils lib32-nvidia-utils nvidia-settings intel-media-driver vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader mesa lib32-mesa

#gpu_type=$(lspci)
#if grep -E "NVIDIA|GeForce" <<< ${gpu_type}; then
#    pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver
#elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
#    pacman -S --noconfirm --needed mesa-vdpau lib32-mesa-vdpau vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver vulkan-icd-loader lib32-vulkan-icd-loader
#elif grep -E "Integrated Graphics Controller" <<< ${gpu_type}; then
#    pacman -S --noconfirm --needed intel-media-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils
#elif grep -E "Intel Corporation UHD" <<< ${gpu_type}; then
#    pacman -S --needed --noconfirm intel-media-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils
#fi

#SETUP IS WRONG THIS IS RUN
if ! source $HOME/arch-install/configs/setup.conf; then
	# Loop through user input until the user gives a valid username
	while true
	do 
		read -p "Please enter username:" username
		# username regex per response here https://unix.stackexchange.com/questions/157426/what-is-the-regex-to-validate-linux-users
		# lowercase the username to test regex
		if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]
		then 
			break
		fi 
		echo "Incorrect username."
	done 
# convert name to lowercase before saving to setup.conf
echo "username=${username,,}" >> ${HOME}/arch-install/configs/setup.conf

    #Set Password
    read -p "Please enter password:" password
echo "password=${password,,}" >> ${HOME}/arch-install/configs/setup.conf

    # Loop through user input until the user gives a valid hostname, but allow the user to force save 
	while true
	do 
		read -p "Please name your machine:" name_of_machine
		# hostname regex (!!couldn't find spec for computer name!!)
		if [[ "${name_of_machine,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]
		then 
			break 
		fi 
		# if validation fails allow the user to force saving of the hostname
		read -p "Hostname doesn't seem correct. Do you still want to save it? (y/n)" force 
		if [[ "${force,,}" = "y" ]]
		then 
			break 
		fi 
	done 

    echo "NAME_OF_MACHINE=${name_of_machine,,}" >> ${HOME}/arch-install/configs/setup.conf
fi
echo -ne "
-------------------------------------------------------------------------
                    Adding User
-------------------------------------------------------------------------
"
if [ $(whoami) = "root"  ]; then
    useradd -m -G wheel,rfkill,games,video,audio,storage -s /bin/bash $USERNAME 
    echo "$USERNAME created, home directory created, added to wheel group, default shell set to /bin/bash"

# use chpasswd to enter $USERNAME:$password
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "$USERNAME password set"

	cp -R $HOME/arch-install /home/$USERNAME/
    chown -R $USERNAME: /home/$USERNAME/arch-install
    echo "arch-install copied to home directory"

# enter $NAME_OF_MACHINE to /etc/hostname
	echo $NAME_OF_MACHINE > /etc/hostname
else
	echo "You are already a user proceed with aur installs"
fi
#if [[ ${FS} == "luks" ]]; then
# Making sure to edit mkinitcpio conf if luks is selected
# add encrypt in mkinitcpio.conf before filesystems in hooks
#    sed -i 's/filesystems/encrypt filesystems/g' /etc/mkinitcpio.conf
# making mkinitcpio with linux kernel
#    mkinitcpio -p linux
#fi
echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 2-user.sh
-------------------------------------------------------------------------
"
