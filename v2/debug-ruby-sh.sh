#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== utils/ruby.sh 全文 ==="
cat "$HB/Library/Homebrew/utils/ruby.sh" 2>/dev/null
echo
echo "=== 'No Homebrew ruby' 消息出处 ==="
grep -rn "No Homebrew ruby" "$HB/Library/Homebrew/" 2>/dev/null | grep -v ".git" | head -3
