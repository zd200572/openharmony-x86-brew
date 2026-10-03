#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== 'standard development tools' 消息出处 ==="
grep -rn "standard development tools\|development_tools installed\|DevelopmentTools.installed" "$HB/Library/Homebrew/" --include="*.rb" 2>/dev/null | grep -v ".git\|test/\|diagnostic" | head -10
echo
echo "=== extend/os/linux/development_tools.rb 里 installed? 与 ohos 分支 ==="
grep -n -B3 -A20 "def installed?\|def self.installed?\|OHOS\|ohos" "$HB/Library/Homebrew/extend/os/linux/development_tools.rb" 2>/dev/null | head -60
echo
echo "=== 全部 development_tools 文件 ==="
find "$HB/Library/Homebrew" -name "development_tools.rb" | grep -v ".git"
