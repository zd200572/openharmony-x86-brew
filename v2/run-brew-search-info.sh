#!/bin/bash
# V2 验证: brew search / info(走本地 tap 模式)
ROOTFS=/root/ohos-x86/rootfs
chroot $ROOTFS /bin/zsh -c '
export HOME=/root
export PATH=/opt/ruby40/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
echo "########## brew search git ##########"
/storage/Users/currentUser/.harmonybrew/bin/brew search git 2>&1 | head -15
echo "[search] exit=$?"
echo
echo "########## brew info hello ##########"
/storage/Users/currentUser/.harmonybrew/bin/brew info ohos/local/hello 2>&1 | head -12
echo "[info] exit=$?"
'
echo SEARCH_INFO_DONE
