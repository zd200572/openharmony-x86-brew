#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== os/linux/ld.rb 全文 ==="
cat "$HB/Library/Homebrew/os/linux/ld.rb"
echo
echo "=== extend/os/linux/linkage_checker.rb 1-40 ==="
sed -n '1,40p' "$HB/Library/Homebrew/extend/os/linux/linkage_checker.rb"
echo
echo "=== extend/os/linux/extend/ENV/super.rb 80-115 ==="
sed -n '80,115p' "$HB/Library/Homebrew/extend/os/linux/extend/ENV/super.rb"
