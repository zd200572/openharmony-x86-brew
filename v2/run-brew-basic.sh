#!/bin/bash
# V2 验证: brew --version / config / search / info
ROOTFS=/root/ohos-x86/rootfs
mountpoint -q $ROOTFS/dev  || mount --bind /dev  $ROOTFS/dev
mountpoint -q $ROOTFS/proc || mount --bind /proc $ROOTFS/proc
mountpoint -q $ROOTFS/sys  || mount --bind /sys  $ROOTFS/sys

chroot $ROOTFS /bin/zsh -c '
export HOME=/root
export PATH=/opt/ruby40/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
echo "########## brew --version ##########"
/storage/Users/currentUser/.harmonybrew/bin/brew --version
echo "[--version] exit=$?"
echo
echo "########## brew config ##########"
/storage/Users/currentUser/.harmonybrew/bin/brew config
echo "[config] exit=$?"
'
echo BASIC_DONE
