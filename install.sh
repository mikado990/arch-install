#!/bin/bash

set -a
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"/scripts
CONFIGS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"/configs
set +a

( bash $SCRIPT_DIR/scripts/startup.sh )|& tee startup.log
source $CONFIGS_DIR/setup.conf
( bash $SCRIPT_DIR/scripts/0-preinstall.sh )|& tee 0-preinstall.log
( arch-chroot /mnt $HOME/arch-install/scripts/1-setup.sh )|& tee 1-setup.log
( arch-chroot /mnt /usr/bin/runuser -u $USERNAME -- /home/$USERNAME/arch-install/scripts/2-user.sh )|& tee 2-user.log
( arch-chroot /mnt $HOME/arch-install/scripts/3-post-setup.sh )|& tee 3-post-setup.log
cp -v *.log /mnt/home/$USERNAME
