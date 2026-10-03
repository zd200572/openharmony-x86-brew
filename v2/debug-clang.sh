#!/bin/bash
SDK=/root/ohos-x86/ohos-sdk/linux/native
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== SDK native 体积 ==="
du -sh $SDK/llvm/bin $SDK/llvm/lib $SDK/llvm/sysroot 2>/dev/null
echo
echo "=== llvm/bin 里 clang 相关 ==="
ls $SDK/llvm/bin/ | head -25
echo
echo "=== DevelopmentTools.installed? 实现(linux 版) ==="
sed -n '1,60p' "$HB/Library/Homebrew/extend/os/linux/development_tools.rb"
