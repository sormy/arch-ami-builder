#!/bin/bash

set -e

source "params.sh"
source "elib.sh"
source "disk.sh"

# aux disk, root patition, UUID
AUX_DISK_ROOT_UUID=$(blkid | grep aux-root | grep -o '\bUUID="[^"]*"' | sed -e 's!"!!g')
echo "AUX_DISK_ROOT_UUID=$AUX_DISK_ROOT_UUID"

# kernel file
KERNEL_FILE="$(find /mnt/arch/boot -iname 'vmlinuz-*' | head -n 1)"
echo "KERNEL_FILE=$KERNEL_FILE"

# ramdisk file
INITRAMFS_FILE="$(find /mnt/arch/boot -iname 'initramfs-*' | grep -v fallback | head -n 1)"
echo "INITRAMFS_FILE=$INITRAMFS_FILE"

# force systemd to be our init
GRUB_CMDLINE_LINUX="init=/lib/systemd/systemd"
echo "GRUB_CMDLINE_LINUX=$GRUB_CMDLINE_LINUX"

# install kernel from aux disk to primary disk
eexec cp -v "$KERNEL_FILE" "$INITRAMFS_FILE" /boot/

# patch bootloader on primary disk to load new kernel and system from aux disk
eexec cp -v /boot/grub2/grub.cfg /boot/grub2/grub.cfg.bak
eexec sed -i \
    -e 's!/boot/\(vmlinuz\|kernel\)-\S\+!/boot/'"$(basename "$KERNEL_FILE")"'!g' \
    -e 's!/boot/initramfs-\S\+!/boot/'"$(basename "$INITRAMFS_FILE")"'!g' \
    -e 's!root=\S\+!root='"$AUX_DISK_ROOT_UUID"' '"$GRUB_CMDLINE_LINUX"'!g' \
    /boot/grub2/grub.cfg
echo "grub.cfg diff:"
diff -u /boot/grub2/grub.cfg.bak /boot/grub2/grub.cfg || true
