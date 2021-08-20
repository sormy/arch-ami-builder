#!/bin/bash

set -e

source "params.sh"
source "elib.sh"

# primary disk
PRI_DISK=$(find_pri_disk)
echo "PRI_DISK=$PRI_DISK"

# primary disk, root partition
PRI_DISK_ROOT=$(blkid | grep 'LABEL="/"' | sed 's/:.*$//')
echo "PRI_DISK_ROOT=$PRI_DISK_ROOT"

# aux disk
AUX_DISK=$(find_aux_disk)
echo "AUX_DISK=$AUX_DISK"

# aux disk, root partition
AUX_DISK_ROOT=$(append_disk_part "$AUX_DISK" 1)
echo "AUX_DISK_ROOT=$AUX_DISK_ROOT"

# only arm64 else is supported at this time
eexec [ "$(uname -m)" = "aarch64" ]

# needed to make script idempotent for debug purposes
eqexec swapoff -a
eqexec pkill gpg-agent
eqexec umount /mnt/arch/dev/shm \
    /mnt/arch/dev/pts \
    /mnt/arch/dev \
    /mnt/arch/proc \
    /mnt/arch/sys \
    /mnt/arch/boot/efi \
    /mnt/arch

# partitioning aux disk
eexec sh -c 'sfdisk --dump "'"$PRI_DISK"'" |
    grep "'"$PRI_DISK_ROOT"'\b" | grep -o "size=[^,]*" |
    sfdisk --label gpt "'"$AUX_DISK"'"'

# waiting for aux disk
eexec sh -c 'while [ ! -e "'"$AUX_DISK_ROOT"'" ]; do sleep 1; done'

# formatting aux disk
eexec mkfs.ext4 "$AUX_DISK_ROOT"

# labeling partitions on aux disk
eexec e2label "$AUX_DISK_ROOT" aux-root

# mounting aux disk
eexec mkdir -p /mnt/arch
eexec mount "$AUX_DISK_ROOT" /mnt/arch

# setting work directory to /mnt/arch
eexec cd /mnt/arch

# installing Arch Linux GPG keys
eexec wget https://raw.githubusercontent.com/archlinuxarm/archlinuxarm-keyring/master/archlinuxarm.gpg
eexec gpg --import archlinuxarm.gpg
eexec rm -fv archlinuxarm.gpg

# downloading Arch Linux base system
eexec wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
eexec wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz.sig
eexec gpg --verify ArchLinuxARM-aarch64-latest.tar.gz.sig

# installing Arch Linux base system
eexec tar xvpf ArchLinuxARM-aarch64-latest.tar.gz --xattrs-include='*.*' --numeric-owner
eexec rm -fv ArchLinuxARM-aarch64-latest.*
# TODO: tar: Ignoring unknown extended header keyword `LIBARCHIVE.xattr.security.capability'

# configuring /etc/fstab
eexec sh -c 'cat >> /mnt/arch/etc/fstab << END
LABEL=aux-root / ext4 noatime 0 1
PARTLABEL=EFI\040System\040Partition /boot/efi vfat noauto,noatime 0 2
END'

# copying Amazon kernel configuration to /opt/kernels
eexec mkdir -p /mnt/arch/opt/kernels
eexec cp -fv /boot/config-* /mnt/arch/opt/kernels

# fixing /etc/resolv.conf
# NOTE: /etc/resolv.conf symlink pointing to /run/systemd/resolve/resolv.conf will be restored later
eexec rm -rfv /mnt/arch/etc/resolv.conf
eexec cp -fv /etc/resolv.conf /mnt/arch/etc/

# mounting /proc /sys /dev
eexec mount -t proc none /mnt/arch/proc
eexec mount -o bind /sys /mnt/arch/sys
eexec mount -o bind /dev /mnt/arch/dev
eexec mount -o bind /dev/pts /mnt/arch/dev/pts
eexec mount -o bind /dev/shm /mnt/arch/dev/shm
