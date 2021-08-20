#!/bin/bash

set -e

source "params.sh"
source "elib.sh"

# kernel config to use as base
KERNEL_CONFIG=$(find /opt/kernels -type f -name "config-*.amzn*" | head -n 1)
echo "KERNEL_CONFIG=$KERNEL_CONFIG"

# needed to make script idempotent for debug purposes
eqexec swapoff -a

# install gpg keys
eexec pacman-key --init
eexec pacman-key --populate archlinuxarm

# update system
eexec pacman -Syu --noconfirm

# init build directory
eexec mkdir /opt/build
eexec cd /opt/build

# install stuff needed to build kernel
# eexec pacman -S --noconfirm asp base-devel pacman-contrib bc cpio
eexec pacman -S --noconfirm asp sudo flex bison make gcc fakeroot pacman-contrib bc cpio

# TODO: what to cleanup?
# Packages (27) binutils-2.35-1  db-5.3.28-5  elfutils-0.185-1  gc-8.0.4-4  gdbm-1.20-1  git-2.33.0-1  guile-2.2.7-1  jq-1.6-4  libmpc-1.2.1-1  libtool-2.4.6+42+gb88cebd5-15
#              m4-1.4.19-1  oniguruma-6.9.7.1-1  perl-5.34.0-2  perl-error-0.17029-3  perl-mailtools-2.21-5  perl-timedate-2.33-3  texinfo-6.8-2  asp-7-1  bc-1.07.1-4  bison-3.7.6-1
#              cpio-2.13-2  fakeroot-1.25.3-2  flex-2.6.4-3  gcc-10.2.0-1  make-4.3-3  pacman-contrib-1.4.0-4  sudo-1.9.7.p2-1

# could be needed for nano and micro instances to build kernel faster
eexec fallocate -l 1G /swap
eexec chmod 600 /swap
eexec mkswap /swap
eexec swapon /swap

# export vanilla linux package
eexec asp update linux
eexec asp export linux
eexec cd linux

# patch linux package
eexec cp PKGBUILD PKGBUILD.bak
eexec sed -i PKGBUILD \
    -e '1h;2,$H;$!d;g' \
    -e 's!pkgbase=[^\n]*!pkgbase=linux-aarch64!' \
    -e 's!arch=([^)]*)!arch=(aarch64)!' \
    -e 's!makedepends=([^)]*)!makedepends=(bc kmod libelf cpio perl tar xz)!' \
    -e 's!_srcname=[^\n]*!_srcname=linux-${pkgver%.*}!' \
    -e 's!"$_srcname::[^"]*"!"$_srcname::http://www.kernel.org/pub/linux/kernel/v${pkgver%%.*}.x/linux-${pkgver%.*}.tar.xz"!' \
    -e 's!sha256sums=([^)]*)!sha256sums=("SKIP" "SKIP")!' \
    -e 's![^#]make htmldocs!#make htmldocs!' \
    -e 's!depends=(pahole)!depends=()!' \
    -e 's![^#]install -Dt "$builddir/tools/objtool" tools/objtool/objtool!#install -Dt "$builddir/tools/objtool" tools/objtool/objtool!' \
    -e 's!pkgname=([^)]*)!pkgname=("$pkgbase" "$pkgbase-headers")!' \
    -e 's!x86!arm64!g'
echo "PKGBUILD diff:"
diff -u PKGBUILD.bak PKGBUILD || true

# install amzn2 kernel config
eexec cp -v config config.bak
eexec cp -v "$KERNEL_CONFIG" config

# make it accessible to alarm
eexec chmod -R a+rwX .

# update checksums
eexec sudo -u alarm updpkgsums

# build the package
eexec sh -c 'MAKEFLAGS="-j'"$(nproc)"'" sudo -E -u alarm makepkg --holdver --skippgpcheck'

# swap is not needed anymore once kernel build is completed
eexec swapoff /swap
eexec rm -f /swap

# discovere kernel version after build
KERNEL_VERSION=$(< /opt/build/linux/src/linux-*/version)
echo "KERNEL_VERSION=$KERNEL_VERSION"

# patch mkinitcpio to avoid death with:
# ERROR: kernel version extraction from image not supported for `aarch64' architecture
# TODO: move patch to custom mkinitcpio overlay?
eexec sed -i /bin/mkinitcpio \
  -e 's/\[\[ \$arch != @(i?86|x86_64) \]\]/[[ $arch != @(i?86|x86_64|aarch64) ]]/'

# configure mkinitcpio with right kernel version and paths to ramdisk and kernel
eexec sed -i /etc/mkinitcpio.d/linux-aarch64.preset \
  -e 's!^ALL_kver=".*"$!ALL_kver="'"$KERNEL_VERSION"'"!' \
  -e 's!^default_image=.*$!default_image="/boot/initramfs-linux-aarch64.img"!' \
  -e 's!^fallback_image=.*$!fallback_image="/boot/initramfs-linux-aarch64-fallback.img"!'

# remove old ramdisks if exists
eqexec rm -fv /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img

# install kernel and headers
eexec pacman -U --noconfirm linux-aarch64-${KERNEL_VERSION%%-*}.*.pkg.tar.xz

# TODO: make kernel to be installed in /boot under initramfs-linux.img
# instead of initramfs-linux-aarch64.img
# may be line below can be fixed in BUILDPKG
# echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

# ensure custom version of kernel won't be auto updated
eexec sed -i /etc/pacman.conf \
    -r -e 's!^\s*#?\s*IgnorePkg\s*=\s*.*$!IgnorePkg = linux-aarch64!'

# install ena kernel module
# TODO: make PKGBUILD for it
eexec cd /opt/build
eexec git clone https://github.com/amzn/amzn-drivers.git
eexec cd amzn-drivers
ENA_VERSION=$(git tag | sort -V -r | head -n 1)
echo "ENA_VERSION=$ENA_VERSION"
eexec git checkout "$ENA_VERSION"
eexec cd kernel/linux/ena
eexec sed -i Makefile -e 's!/lib/modules/\$(BUILD_KERNEL)/build!$(KERNEL_DIR)!g'
eexec make "KERNEL_DIR=/opt/build/linux/src/linux-${KERNEL_VERSION%%-*}"
eexec /opt/build/linux/src/linux-${KERNEL_VERSION%%-*}/scripts/sign-file \
    sha512 \
    /opt/build/linux/src/linux-${KERNEL_VERSION%%-*}/certs/signing_key.pem \
    /opt/build/linux/src/linux-${KERNEL_VERSION%%-*}/certs/signing_key.x509 \
    ena.ko
eexec mkdir -pv "/usr/lib/modules/$KERNEL_VERSION/extra"
eexec cp -v ena.ko "/usr/lib/modules/$KERNEL_VERSION/extra"
eexec depmod "$KERNEL_VERSION"
eexec sh -c 'echo "ena" > /etc/modules-load.d/ena.conf'
eexec mkinitcpio -p linux-aarch64

# remove unneded anymore kernel build stuff
eexec pacman -R --noconfirm asp sudo flex bison make gcc fakeroot pacman-contrib bc cpio
eexec pacman -R --noconfirm linux-firmware
eexec sh -c 'pacman -Qdtq | pacman -Rs --noconfirm -'

# installing vfat support for ESP partition
eexec pacman -S --noconfirm dosfstools

# install boot loader
eexec pacman -S --noconfirm grub-efi-aarch64

# configure grub
# 1. Justification for nvme_core.io_timeout=4294967295:
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nvme-ebs-volumes.html#timeout-nvme-ebs-volumes
# 2. Serial configuration is needed to be able to use serial access from AWS console
# 3. systemd is explicitly set as init as it might be not set on kernel config level
eexec sh -c 'cat >> /etc/default/grub << END

# added by archlinux-ami-builder
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
GRUB_CMDLINE_LINUX="init=/lib/systemd/systemd nvme_core.io_timeout=4294967295 console=tty0 console=ttyS0,115200n8"
END'

# init systemd
# TODO: it is likely not needed since ec2-init will reinitialize it anyway
# eexec systemd-machine-id-setup

# disable password auth for root and alarm
eexec passwd -d -l root
eexec passwd -d -l alarm

# enable alarm user to run sudo without password
# https://wiki.archlinux.org/title/Sudo
eexec pacman -S --noconfirm sudo
eexec sh -c 'echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel'

# enable password auth for alarm if you wanted to login using serial console
# TODO: add option to set password for alarm and may be root
# passwd alarm

# enable ssh in case if it is not (but it should be enabled by default)
eexec systemctl enable sshd

# enable ec-init
# TODO: make PKGBUILD for it
eexec cd /opt
eexec curl -O https://raw.githubusercontent.com/sormy/ec2-init/master/ec2-init.script
eexec curl -O https://raw.githubusercontent.com/sormy/ec2-init/master/ec2-init.service
eexec mv -f ec2-init.script /usr/sbin/ec2-init
eexec chmod +x /usr/sbin/ec2-init
eexec mv -f ec2-init.service /etc/systemd/system/ec2-init.service
eexec sed -i '/ExecStart=/a Environment="SSH_USER_NAME=alarm"' /etc/systemd/system/ec2-init.service
eexec systemctl enable ec2-init

# TODO: run hook SIDELOAD_USER_INSTALL

# revert back dns resolve config
eexec ln -snf /run/systemd/resolve/resolv.conf /etc/resolv.conf
