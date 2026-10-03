#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== extend/os/development_tools.rb(ohos 定制?) ==="
cat "$HB/Library/Homebrew/extend/os/development_tools.rb" 2>/dev/null
echo
echo "=== extend/os/linux/development_tools.rb 关键函数 ==="
grep -n -A12 "def self.installed?\|def self.installed" "$HB/Library/Homebrew/extend/os/linux/development_tools.rb" 2>/dev/null | head -40
echo
echo "=== 'No developer tools' 消息出处 ==="
grep -rn "No developer tools" "$HB/Library/Homebrew/" 2>/dev/null | grep -v ".git" | head -3
