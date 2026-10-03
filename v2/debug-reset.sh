#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== 当前 HEAD(9d2189dcb4 是否还在) ==="
git -C "$HB" log --oneline -3
echo
echo "=== git status ==="
git -C "$HB" status --short | head -5
echo
echo "=== os.sh 当前内容 ==="
grep -nF 'ld-musl' "$HB/Library/Homebrew/utils/os.sh" | head -3
echo
echo "=== update.sh 90-137 行(reset --hard 的触发条件) ==="
sed -n '90,137p' "$HB/Library/Homebrew/cmd/update.sh"
echo
echo "=== 全树找 not support yet(排除 .git) ==="
grep -rln "not support yet" "$HB" 2>/dev/null | grep -v "/.git/" | head
echo
echo "=== HOMEBREW_LIBRARY / bin brew 检查二次加载路径 ==="
grep -n "os.sh\|HOMEBREW_LIBRARY=" "$HB/bin/brew" | head -10
