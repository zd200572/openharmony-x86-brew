#!/bin/bash
# 从 Homebrew git 仓库生成 os.sh 的 x86_64 补丁, 归档到 distro 与 Windows 工作区
set -e
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
mkdir -p /root/ohos-x86/v2/patches
git -C "$HB" diff -- Library/Homebrew/utils/os.sh > /root/ohos-x86/v2/patches/os.sh-x86_64.patch
mkdir -p /mnt/d/share/interesting/openharmony_x86_brew/v2/patches
cp /root/ohos-x86/v2/patches/os.sh-x86_64.patch /mnt/d/share/interesting/openharmony_x86_brew/v2/patches/
echo "=== 补丁内容 ==="
cat /root/ohos-x86/v2/patches/os.sh-x86_64.patch
