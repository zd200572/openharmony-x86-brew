#!/bin/bash
# V2 验证: 本地 tap + formula 安装全链路(Harmonybrew 要求 formula 必须在 tap 中)
set -e
ROOTFS=/root/ohos-x86/rootfs
mountpoint -q $ROOTFS/dev  || mount --bind /dev  $ROOTFS/dev
mountpoint -q $ROOTFS/proc || mount --bind /proc $ROOTFS/proc
mountpoint -q $ROOTFS/sys  || mount --bind /sys  $ROOTFS/sys

echo "########## 1. 准备测试 formula ##########"
bash /mnt/d/share/interesting/openharmony_x86_brew/v2/make-test-formula.sh

echo "########## 2. 建本地 tap 并安装 ##########"
chroot $ROOTFS /bin/zsh -c '
export HOME=/root
export PATH=/opt/ruby40/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_FROM_API=1
BREW=/storage/Users/currentUser/.harmonybrew/bin/brew
$BREW tap-new ohos/local 2>&1 | tail -3
cp /root/testsrc/hello.rb /storage/Users/currentUser/.harmonybrew/Homebrew/Library/Taps/ohos/homebrew-local/Formula/hello.rb
$BREW install ohos/local/hello
'
echo "[install] exit=$?"

echo "########## 3. 验证安装产物 ##########"
chroot $ROOTFS /bin/zsh -c '
export HOME=/root
export PATH=/storage/Users/currentUser/.harmonybrew/bin:/bin:/usr/bin
ls -la /storage/Users/currentUser/.harmonybrew/Cellar/hello/1.0/bin/ 2>&1
/storage/Users/currentUser/.harmonybrew/opt/hello/bin/hello.sh
echo "[hello] exit=$?"
/storage/Users/currentUser/.harmonybrew/bin/brew list
echo "[list] exit=$?"
'
echo INSTALL_TEST_DONE
