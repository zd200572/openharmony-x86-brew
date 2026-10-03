#!/bin/bash
# 在 rootfs chroot 内运行 brew update --force(zsh 系,无需 bash)
ROOTFS=/root/ohos-x86/rootfs
mountpoint -q $ROOTFS/dev  || mount --bind /dev  $ROOTFS/dev
mountpoint -q $ROOTFS/proc || mount --bind /proc $ROOTFS/proc
mountpoint -q $ROOTFS/sys  || mount --bind /sys  $ROOTFS/sys
chroot $ROOTFS /bin/zsh -c '
export HOME=/root
export PATH=/opt/ruby34/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
/storage/Users/currentUser/.harmonybrew/bin/brew update --force
'
echo "BREW_UPDATE_EXIT=$?"
