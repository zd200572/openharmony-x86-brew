#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== 在 Homebrew 树里找 'not support yet' ==="
grep -rn "not support yet" "$HB"/Library/Homebrew/ 2>/dev/null | grep -v ".git" | head -10
echo
echo "=== wrapper 里检查支持的部分 ==="
grep -n -A5 -B5 "support" "$HB"/bin/brew | head -40
echo
echo "=== os.sh 里的架构检查 ==="
sed -n '1,60p' "$HB"/Library/Homebrew/utils/os.sh
