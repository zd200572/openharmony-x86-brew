#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== def ohos? 定义位置 ==="
grep -rn "def ohos?\|def self.ohos?" "$HB/Library/Homebrew/" --include="*.rb" 2>/dev/null | grep -v ".git" | head -5
echo
echo "=== OS.ohos? 实现上下文 ==="
F=$(grep -rln "def ohos?" "$HB/Library/Homebrew/" --include="*.rb" 2>/dev/null | grep -v ".git" | head -1)
echo "[$F]"
grep -n -B5 -A10 "def ohos?" "$F" 2>/dev/null
echo
echo "=== ruby 侧全部 aarch64/ld-musl 硬编码 ==="
grep -rn "ld-musl\|aarch64" "$HB/Library/Homebrew/" --include="*.rb" 2>/dev/null | grep -v ".git\|test/\|spec/" | head -25
echo
echo "=== simulate_system.rb 全文(tag 解析) ==="
cat "$HB/Library/Homebrew/extend/os/linux/simulate_system.rb"
echo
echo "=== shell 侧 bottle_tag(update.sh 45-70) ==="
sed -n '45,75p' "$HB/Library/Homebrew/cmd/update.sh"
