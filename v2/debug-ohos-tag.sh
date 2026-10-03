#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== ruby 侧读 HOMEBREW_OHOS 的地方 ==="
grep -rn "HOMEBREW_OHOS" "$HB/Library/Homebrew/" --include="*.rb" 2>/dev/null | grep -v ".git" | head -15
echo
echo "=== extend/os 里的 ohos 文件 ==="
ls -R "$HB/Library/Homebrew/extend/os/" 2>/dev/null | grep -i ohos | head
find "$HB/Library/Homebrew/extend" -path "*ohos*" -name "*.rb" 2>/dev/null | head -20
echo
echo "=== bin/brew 里 export 相关 ==="
grep -n "export\|HOMEBREW_OHOS" "$HB/bin/brew" | head -20
echo
echo "=== ruby 侧 OHOS 系统识别(OSType/OS) ==="
grep -rn -i "ohos" "$HB/Library/Homebrew/OS.rb" "$HB/Library/Homebrew/extend/ENV" 2>/dev/null | head -10
grep -rn -i "ld-musl\|ohos" "$HB/Library/Homebrew/extend/os/linux/" 2>/dev/null | head -10
echo
echo "=== shell 侧 bottle_tag 函数定义 ==="
grep -rn "bottle_tag()" "$HB/Library/Homebrew/" 2>/dev/null | grep -v ".git" | head -3
