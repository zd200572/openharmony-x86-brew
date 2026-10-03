#!/bin/bash
# 1) 烘焙 brew.env(禁 auto-update 与 API 模式, 规避 x86_64 元数据缺失+tag切换抹补丁)
# 2) 重打 os.sh 补丁, 检查/清理 stash
set -e
ROOTFS=/root/ohos-x86/rootfs
HB="$ROOTFS/storage/Users/currentUser/.harmonybrew/Homebrew"
OS_SH="$HB/Library/Homebrew/utils/os.sh"
PATCH=/root/ohos-x86/v2/patches/os.sh-x86_64.patch

echo "########## brew.env ##########"
ENV_CONTENT="HOMEBREW_NO_AUTO_UPDATE=1
HOMEBREW_NO_INSTALL_FROM_API=1"
mkdir -p "$ROOTFS/etc/homebrew" "$HB/../etc/homebrew"
echo "$ENV_CONTENT" > "$ROOTFS/etc/homebrew/brew.env"
echo "$ENV_CONTENT" > "$ROOTFS/storage/Users/currentUser/.harmonybrew/etc/homebrew/brew.env"
echo "--- /etc/homebrew/brew.env ---"; cat "$ROOTFS/etc/homebrew/brew.env"

echo "########## stash 现状 ##########"
git -C "$HB" stash list || true
echo "--- stash@{0} 内容摘要 ---"
git -C "$HB" stash show -p 2>/dev/null | grep -E "^\+|^-" | grep -v "^+++\|^---" | head -8 || echo "(无 stash@{0})"

echo "########## 重打 os.sh 补丁 ##########"
if grep -qF 'ld-musl-$(uname -m).so.1' "$OS_SH"; then
  echo "[patch] already applied"
else
  ( cd "$HB" && git apply --whitespace=nowarn "$PATCH" ) && echo "[patch] applied"
fi

echo "########## 确认工作树就绪 ##########"
git -C "$HB" status --short | head -3
git -C "$HB" log --oneline -1
echo CLEANUP_AND_ENV_DONE
