#!/bin/bash
# 工作区最新脚本同步回 distro(保持本地可复现)
set -e
WS=/mnt/d/share/interesting/openharmony_x86_brew
D=/root/ohos-x86/v2
for f in stage-brew.sh build-ruby40-host-then-cross.sh brew-bootstrap.sh apply-brew-patches.sh \
         patch-ruby-x86.py install-alpine-clang.sh build-deps-x86.sh; do
  cp -f $WS/v2/$f $D/$f
  sed -i 's/\r$//' $D/$f
done
mkdir -p $D/patches
cp -f $WS/v2/patches/*.patch $D/patches/
echo "=== distro 侧同步完成 ==="
ls -la $D/stage-brew.sh $D/brew-bootstrap.sh $D/patches/
