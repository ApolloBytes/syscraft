#!/bin/sh
set -e

printf "Install CachyOS repo and Chaotic AUR? (y/n): "
read answer

case "$answer" in
    y|Y|yes|YES|Yes)
        echo "== Installing CachyOS repo =="

        curl -LO https://mirror.cachyos.org/cachyos-repo.tar.xz
        tar xvf cachyos-repo.tar.xz
        cd cachyos-repo
        sudo ./cachyos-repo.sh
        cd ..

        echo "== Setting up Chaotic AUR =="

        sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        sudo pacman-key --lsign-key 3056513887B78AEB

        sudo pacman -U https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst
        sudo pacman -U https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst

        echo "[chaotic-aur]" | sudo tee -a /etc/pacman.conf
        echo "Include = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf

        echo "== Updating system =="
        sudo pacman -Syu

        echo "Done."
        ;;
    *)
        echo "Cancelled."
        ;;
esac
