#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== extend/os/linux/development_tools.rb 55-92 ==="
sed -n '55,92p' "$HB/Library/Homebrew/extend/os/linux/development_tools.rb"
echo
echo "=== development_tools.rb(上游基类)里 installed? ==="
grep -n -A15 "def installed?" "$HB/Library/Homebrew/development_tools.rb" | head -25
