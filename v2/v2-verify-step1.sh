#!/bin/bash
# V2 验证第 1 步: 打补丁 -> brew update(跳过 API) -> 重打补丁 -> --version/config
set -u
ROOTFS=/root/ohos-x86/rootfs
HB="$ROOTFS/storage/Users/currentUser/.harmonybrew/Homebrew"
OS_SH="$HB/Library/Homebrew/utils/os.sh"
PATCH=/root/ohos-x86/v2/patches/os.sh-x86_64.patch

apply_patch() {
  if grep -qF 'ld-musl-$(uname -m).so.1' "$OS_SH"; then
    echo "[patch] already applied"
  else
    ( cd "$HB" && git apply --whitespace=nowarn "$PATCH" ) && echo "[patch] applied"
  fi
}

mountpoint -q $ROOTFS/dev  || mount --bind /dev  $ROOTFS/dev
mountpoint -q $ROOTFS/proc || mount --bind /proc $ROOTFS/proc
mountpoint -q $ROOTFS/sys  || mount --bind /sys  $ROOTFS/sys

echo "########## 1. brew update --force (NO_INSTALL_FROM_API) ##########"
apply_patch
chroot $ROOTFS /bin/zsh -c '
export HOME=/root
export PATH=/opt/ruby34/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
export HOMEBREW_NO_INSTALL_FROM_API=1
/storage/Users/currentUser/.harmonybrew/bin/brew update --force
'
echo "[update] exit=$?"

echo "########## 2. update 后重打补丁(update 会 checkout tag 抹掉) ##########"
apply_patch

echo "########## 3. brew --version / config ##########"
chroot $ROOTFS /bin/zsh -c '
export HOME=/root
export PATH=/opt/ruby34/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
/storage/Users/currentUser/.harmonybrew/bin/brew --version
echo "----"
/storage/Users/currentUser/.harmonybrew/bin/brew config
'
echo "[version/config] exit=$?"
echo V2_STEP1_DONE
