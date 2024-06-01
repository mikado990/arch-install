#!/usr/bin/env bash

source $HOME/arch-install/configs/setup.conf

cd ~
mkdir "/home/$USERNAME/.cache"
mkdir "/home/$USERNAME/.config"
mkdir -p "/home/$USERNAME/.local/state"
mkdir -p "/home/$USERNAME/.local/share"
mkdir -p "/home/$USERNAME/.local/state/bash"
mkdir -p "/home/$USERNAME/.local/share/wineprefixes"

cp -r ~/arch-install/configs/.config/* ~/.config/
cp -rf ~/arch-install/configs/.bashrc ~/
cp -rf ~/arch-install/configs/.bash_profile ~/

packages=''

while IFS=read -r line ; do
    packages+=" ${line}"
done < $HOME/arch-install/sripts/pacman-pkgs.txt

while IFS=read -r line ; do
    packages+=" ${line}"
done < $HOME/arch-install/sripts/${DESKTOP_ENV}.txt

sudo pacman -S --needed --noconfirm $packages

if [[ ! $AUR_HELPER == none ]]; then
  cd ~
  git clone "https://aur.archlinux.org/$AUR_HELPER.git"
  cd ~/$AUR_HELPER
  makepkg -si --noconfirm
fi

#while IFS=read -r line ; do
#    packages+=" ${line}"
#done < aur-pkgs.txt

export PATH=$PATH:~/.local/bin

echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
