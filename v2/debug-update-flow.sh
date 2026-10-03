#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== update.sh 里 git 操作策略 ==="
grep -n -B2 -A8 "git stash\|git reset\|git merge\|git rebase\|git checkout" "$HB/Library/Homebrew/cmd/update.sh" | head -80
echo
echo "=== packages jws 下载段(update.sh 420-460) ==="
sed -n '415,470p' "$HB/Library/Homebrew/cmd/update.sh"
echo
echo "=== 是否有跳过 API 的开关 ==="
grep -rn "NO_INSTALL_FROM_API\|NO_UPDATE" "$HB/Library/Homebrew/cmd/update.sh" "$HB/Library/Homebrew/api.rb" 2>/dev/null | head -10
