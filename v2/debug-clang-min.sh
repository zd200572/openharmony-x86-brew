#!/bin/bash
SDK=/root/ohos-x86/ohos-sdk/linux/native
echo "=== clang-15 / clang++-15 大小 ==="
ls -la $SDK/llvm/bin/clang-15 $SDK/llvm/bin/clang++-15 2>/dev/null
du -sh $SDK/llvm/lib/clang 2>/dev/null
echo
echo "=== clang-15 动态依赖 ==="
ldd $SDK/llvm/bin/clang-15 2>/dev/null | awk '{print $1, $3}' | head -20
echo
echo "=== 这些依赖在 llvm/lib 里的大小 ==="
for so in $(ldd $SDK/llvm/bin/clang-15 2>/dev/null | awk '$3 ~ /^\// {print $3}'); do
  ls -la "$so" 2>/dev/null | awk '{print $5, $9}'
done
echo
echo "=== sysroot 位置 ==="
ls -d $SDK/sysroot $SDK/llvm/sysroot 2>/dev/null; du -sh $SDK/sysroot 2>/dev/null
