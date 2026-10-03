#!/bin/bash
# 确定性 brew 引导(替代 install.sh 在容器内的脆弱路径):
# 下载 brew.tar.gz -> 解包 -> 移为 Homebrew -> 建 bin/brew 符号链接
# 补丁(os.sh 等)由 apply-brew-patches.sh 在此之后统一应用
set -e
ROOTFS=/root/ohos-x86/rootfs
PREFIX=$ROOTFS/storage/Users/currentUser/.harmonybrew
DL=/root/ohos-x86/v2/.deps
TARBALL_URL="${HOMEBREW_TARBALL_URL:-https://harmonybrew.atomgit.com/brew/brew.tar.gz}"

mkdir -p $DL
[ -f $DL/brew.tar.gz ] || curl -fSL --retry 3 -m 900 -o $DL/brew.tar.gz "$TARBALL_URL"

mkdir -p $PREFIX/bin $PREFIX/etc $PREFIX/include $PREFIX/lib $PREFIX/opt \
         $PREFIX/sbin $PREFIX/share $PREFIX/var $PREFIX/Caskroom \
         $PREFIX/Cellar $PREFIX/Frameworks $ROOTFS/root

if [ ! -d $PREFIX/Homebrew ]; then
  tar -xzf $DL/brew.tar.gz -C $PREFIX
  [ -d $PREFIX/brew ] && mv $PREFIX/brew $PREFIX/Homebrew
fi
[ -d $PREFIX/Homebrew/.git ] || echo "WARN: Homebrew/.git 缺失, git apply 补丁将不可用"
ln -sfn ../Homebrew/bin/brew $PREFIX/bin/brew
ls $PREFIX
echo BREW_BOOTSTRAP_OK
