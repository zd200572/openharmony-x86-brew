#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== os.sh 当前状态 ==="
grep -n "OHOS_MUSL_LIBC=" "$HB/Library/Homebrew/utils/os.sh" | head -2
echo
echo "=== git 状态 ==="
git -C "$HB" status --short | head -10
git -C "$HB" stash list | head -5
git -C "$HB" log --oneline -3
echo
echo "=== stash 里有什么 ==="
git -C "$HB" stash show -p 2>/dev/null | head -30
echo
echo "=== update-repository 相关 jws 逻辑 ==="
grep -rn "jws.json" "$HB/Library/Homebrew/" --include="*.rb" --include="*.sh" 2>/dev/null | grep -v ".git" | head -10
