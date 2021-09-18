# TODO

1. Auto resize partition on boot using resize2fs?
2. Add user install/test/clean/image.
3. Move /opt/build to 3rd drive? Can be used to reduce image size to just 2-3G.
4. Shrink root partition before taking an image to reduce AMI? Is it possible?

Shrink/grow image:

```sh
# unmount all before
PRI_DISK_ROOT=$(blkid | grep 'LABEL="/"' | sed 's/:.*$//')
echo "PRI_DISK_ROOT=$PRI_DISK_ROOT"
# check
e2fsck -f "$PRI_DISK_ROOT"
# shrink
resize2fs -M "$PRI_DISK_ROOT"
# grow
resize2fs "$PRI_DISK_ROOT"
```

5. Add these user phases:

```sh
SIDELOAD_USER_INSTALL="${SIDELOAD_USER_INSTALL}"
SIDELOAD_USER_TEST="${SIDELOAD_USER_TEST}"
SIDELOAD_USER_CLEAN="${SIDELOAD_USER_CLEAN}"
SIDELOAD_USER_IMAGE="${SIDELOAD_USER_IMAGE}"
```

6. Resize on boot (update ec2-init?):

```sh
ROOT_PART=$(cat /proc/mounts | grep " / " | cut -d ' ' -f 1)
sfdisk --dump /dev/nvme0n1 \
    | sed -e '/\/dev\/nvme0n1p1 : /s/ size= *[0-9]*,//' \
    | grep -v '^last-lba:' \
    | sfdisk --force /dev/nvme0n1
partx -u /dev/nvme0n1
resize2fs -f /dev/nvme0n1p1
```

7. [x] set ELIB_VERBOSE=false for ssh mode ???

8. Make final phase of ec2-init provisioning to print to serial as well
