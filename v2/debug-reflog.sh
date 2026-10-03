#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== git reflog(谁动了 HEAD) ==="
git -C "$HB" reflog -15
echo
echo "=== update.sh 里所有 checkout/reset ==="
grep -n "git checkout\|git reset\|git rebase\|git merge" "$HB/Library/Homebrew/cmd/update.sh"
echo
echo "=== merge_or_rebase 函数体(247-286) ==="
sed -n '247,286p' "$HB/Library/Homebrew/cmd/update.sh"
