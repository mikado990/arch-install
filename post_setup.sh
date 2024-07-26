#!/bin/bash

## Firewall section
sudo ufw limit 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

## Flatpak section
flatpak install flathub org.onlyoffice.desktopeditors
sudo ln -s /var/lib/flatpak/exports/bin/org.onlyoffice.desktopeditors /usr/bin/onlyoffice

flatpak install flathub io.gitlab.librewolf-community
sudo ln -s /var/lib/flatpak/exports/bin/io.gitlab.librewolf-community /usr/bin/librewolf

flatpak install flathub com.spotify.Client
sudo ln -s /var/lib/flatpak/exports/bin/com.spotify.Client /usr/bin/spotify

flatpak install flathub it.mijorus.gearlever
sudo ln -s /var/lib/flatpak/exports/bin/it.mijorus.gearlever /usr/bin/gearlever

flatpak install flathub io.github.shiftey.Desktop
sudo ln -s /var/lib/flatpak/exports/bin/io.github.shiftey.Desktop /usr/bin/github

flatpak install flathub org.qbittorrent.qBittorrent
sudo ln -s /var/lib/flatpak/exports/bin/org.qbittorrent.qBittorrent /usr/bin/qbittorrent
