#!/bin/bash
# 从 stash 恢复 os.sh 补丁并提交到 stable 分支(防 brew update 的 stash/reset 循环)
set -e
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew

echo "=== 恢复 stash@{0}(含 os.sh 补丁) ==="
git -C "$HB" stash pop || echo "(stash pop 未恢复,可能已应用)"

echo "=== 确认补丁在工作树 ==="
if grep -qF 'ld-musl-$(uname -m).so.1' "$HB/Library/Homebrew/utils/os.sh"; then
  echo PATCH_IN_TREE
else
  echo PATCH_MISSING; exit 1
fi

echo "=== 提交到 stable ==="
git -C "$HB" -c user.email=brew-update@localhost -c user.name="OHOS x86 porter" \
  commit -am "Support x86_64 OHOS: detect musl loader via uname -m" -q
git -C "$HB" log --oneline -3
git -C "$HB" status --short | head -5
echo FIX_REPO_DONE
