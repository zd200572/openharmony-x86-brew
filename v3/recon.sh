#!/bin/bash
# V3 侦察:确认 rootfs / SDK sysroot / SDK clang wrapper 现状
set -u
R=/root/ohos-x86
echo "===== 1. rootfs 顶层 ====="
ls "$R/rootfs" 2>&1 | head -30
echo "--- rootfs/opt ---"
ls "$R/rootfs/opt" 2>&1
echo "--- rootfs 内 brew 是否在 ---"
ls -d "$R/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew" 2>&1
echo "--- rootfs 内 alpine clang ---"
ls "$R/rootfs/usr/lib/llvm15/bin/clang" "$R/rootfs/usr/lib/llvm15/bin/clang++" "$R/rootfs/usr/lib/llvm15/bin/ld.lld" 2>&1
echo "--- rootfs /bin 内 clang 链接 ---"
ls -l "$R/rootfs/bin" 2>/dev/null | grep -iE 'clang|llvm' || echo "(no clang links in /bin)"
ls -l "$R/rootfs/usr/bin" 2>/dev/null | grep -iE 'clang|llvm' || echo "(no clang links in /usr/bin)"

echo "===== 2. SDK sysroot ====="
S=$R/ohos-sdk/linux/native
du -sh "$S/sysroot" 2>&1
ls "$S/sysroot" 2>&1
echo "--- sysroot/usr ---"
ls "$S/sysroot/usr" 2>&1
echo "--- sysroot/usr/lib ---"
ls "$S/sysroot/usr/lib" 2>&1
echo "--- sysroot/usr/lib/x86_64-linux-ohos 头几个 + 计数 ---"
ls "$S/sysroot/usr/lib/x86_64-linux-ohos" 2>&1 | head -40
echo "count: $(ls "$S/sysroot/usr/lib/x86_64-linux-ohos" 2>/dev/null | wc -l)"
echo "--- sysroot/usr/include 计数 ---"
ls "$S/sysroot/usr/include" 2>&1 | head -20
echo "count: $(ls "$S/sysroot/usr/include" 2>/dev/null | wc -l)"
echo "--- sysroot/lib (dynamic linker?) ---"
ls -l "$S/sysroot/lib" 2>&1 | head
echo "--- 关键库:crt1/libc/libc++/libunwind/builtins ---"
ls "$S/sysroot/usr/lib/x86_64-linux-ohos"/crt*.o "$S/sysroot/usr/lib/x86_64-linux-ohos"/libc.so "$S/sysroot/usr/lib/x86_64-linux-ohos"/libc++.so "$S/sysroot/usr/lib/x86_64-linux-ohos"/libunwind* 2>&1
echo "--- libc.so 是 ELF 还是脚本? ---"
file "$S/sysroot/usr/lib/x86_64-linux-ohos/libc.so" 2>&1
head -c 200 "$S/sysroot/usr/lib/x86_64-linux-ohos/libc.so" | od -c | head -3

echo "===== 3. SDK clang wrapper 内容 ====="
ls "$S/llvm/bin" | grep -E 'x86_64.*clang' | head
W="$S/llvm/bin/x86_64-unknown-linux-ohos-clang"
if [ -f "$W" ]; then
  echo "--- wrapper 类型 ---"
  file "$W"
  echo "--- wrapper 内容 ---"
  cat "$W"
  WPP="$S/llvm/bin/x86_64-unknown-linux-ohos-clang++"
  echo "--- clang++ wrapper 内容 ---"
  cat "$WPP" 2>&1
else
  echo "(wrapper 名不同,列目录)"
  ls "$S/llvm/bin" | head -40
fi

echo "===== 4. SDK clang resource dir(找 builtins) ====="
ls -d "$S/llvm/lib/clang/"* 2>&1
ls "$S/llvm/lib/clang/"*/lib/linux/ 2>&1 | head -20

echo "===== 5. Alpine clang 资源(容器内已有) ====="
A="$R/rootfs/usr/lib/llvm15"
ls "$A/lib/clang/"* 2>&1
ls "$A/lib/clang/"*/lib/linux/ 2>&1 | head
"$A/bin/clang" --version 2>&1 | head -2

echo "===== 6. 磁盘余量 ====="
df -h /root | tail -1
