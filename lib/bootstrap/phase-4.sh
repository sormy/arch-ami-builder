#!/bin/bash

set -e

source "params.sh"
source "elib.sh"
source "disk.sh"

# TODO: run hook SIDELOAD_USER_TEST

# primary disk, root partition
PRI_DISK_ROOT=$(blkid | grep 'LABEL="/"' | sed 's/:.*$//')
echo "PRI_DISK_ROOT=$PRI_DISK_ROOT"

# primary disk, ESP partition (if available)
PRI_DISK_ESP=$(blkid | grep 'PARTLABEL="EFI' | sed 's/:.*$//')
echo "PRI_DISK_ESP=$PRI_DISK_ESP"

# aux disk, root partition
AUX_DISK_ROOT=$(blkid | grep 'LABEL="aux-root"' | sed 's/:.*$//')
echo "AUX_DISK_ROOT=$AUX_DISK_ROOT"

# needed to make script idempotent for debug purposes
# release resources that could be busy due to previous run of this phase
eqexec pkill gpg-agent
eqexec umount /mnt/arch/dev/shm \
    /mnt/arch/dev/pts \
    /mnt/arch/dev \
    /mnt/arch/proc \
    /mnt/arch/sys \
    /mnt/arch/boot/efi \
    /mnt/arch

# try to kill journald related processes that could block disk for write
# TODO: for ec2-init provisioning we should not try to stop journald to keep
# logs pushed to standard serial console, anyway disk will be blocked
eqexec systemctl stop systemd-journald.socket
eqexec systemctl stop systemd-journald-dev-log.socket
eqexec systemctl stop systemd-journald-audit.socket
eqexec systemctl stop systemd-journald.service

# migrating root partition from aux to primary disk
# try to remount read-only if possible, if not then okay, will try to fix fs later
eqexec mount -o remount,ro /
eexec sync
eexec dd "if=$AUX_DISK_ROOT" "of=$PRI_DISK_ROOT" bs=1M status=progress
eexec sync
eqexec mount -o remount,rw /

# fixing root partition errors (if remount as read-only has failed)
# NOTE: if fs is fixed, then this command can return non-zero status
eqexec e2fsck -fy "$PRI_DISK_ROOT"

# fixing root partition identity
eexec tune2fs -U random "$PRI_DISK_ROOT"
eexec e2label "$PRI_DISK_ROOT" "/"

# mounting primary disk
eexec mkdir -p /mnt/arch
eexec mount "$PRI_DISK_ROOT" /mnt/arch

# mounting ESP partition
eexec mkdir -p /mnt/arch/boot/efi
eexec mount "$PRI_DISK_ESP" /mnt/arch/boot/efi

# needed for chroot to work well
eexec mount -t proc none /mnt/arch/proc
eexec mount -o bind /sys /mnt/arch/sys
eexec mount -o bind /dev /mnt/arch/dev
eexec mount -o bind /dev/pts /mnt/arch/dev/pts
eexec mount -o bind /dev/shm /mnt/arch/dev/shm

# reset hostname
# TODO: do we need to explicitly set it here?
# eexec chroot hostnamectl set-hostname alarm

# reinstall bootloader
eexec chroot /mnt/arch grub-install --efi-directory=/boot/efi --removable

# reconfigure bootloader
eexec chroot /mnt/arch grub-mkconfig -o /boot/grub/grub.cfg

# fixing fstab
eexec sed -i -e 's!^LABEL=aux-root!LABEL=/!' /mnt/arch/etc/fstab

# clean pacman cache
eexec chroot /mnt/arch pacman -Scc --noconfirm

# cleaning logs
# TODO: move to "rm -rfv" section below
eqexec sh -c 'find /mnt/arch/var/log/journal -mindepth 1 -maxdepth 1 | xargs rm -rfv'

# cleaning filesystem
eqexec rm -rfv \
    "/mnt/arch$SIDELOAD_EC2_PATH" \
    /mnt/arch/opt/build \
    /mnt/arch/var/lib/ec2-init.* \
    /mnt/arch/var/log/ec2-init.* \
    /mnt/arch/home/alarm/.bash_history \
    /mnt/arch/home/alarm/.lesshst \
    /mnt/arch/home/alarm/.cache \
    /mnt/arch/home/alarm/.gnupg \
    /mnt/arch/home/alarm/.ssh/authorized_keys \
    /mnt/arch/root/.bash_history \
    /mnt/arch/root/.lesshst \
    /mnt/arch/root/.cache \
    /mnt/arch/root/.gnupg \
    /mnt/arch/root/.ssh/authorized_keys \
    /mnt/arch/boot/efi/EFI/amzn \
    /mnt/arch/etc/ssh/ssh_host_* \
    /mnt/arch/var/tmp/* \
    /mnt/arch/tmp/*

# TODO: run hook SIDELOAD_USER_CLEAN
