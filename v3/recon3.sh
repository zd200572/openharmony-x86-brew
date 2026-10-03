#!/bin/bash
# V3 侦察第 3 轮:C++ 运行时来源 / clang 资源目录 / binutils / brew 补丁与 tap / 网络
set -u
R=/root/ohos-x86
S=$R/ohos-sdk/linux/native
OH=$R/OpenHarmony-v7.0-Release/OpenHarmony

echo "===== A. rootfs/system 里找 libc++ ====="
ls "$R/rootfs/system" 2>&1
find "$R/rootfs/system" -maxdepth 3 -name 'libc++*' -o -maxdepth 3 -name 'libunwind*' 2>/dev/null | head
echo "--- rootfs 全盘找 libc++(maxdepth 4)---"
find "$R/rootfs" -maxdepth 4 -name 'libc++*' 2>/dev/null | head
echo "===== B. OHOS out 目录里找 libc++ ====="
ls -d "$OH/out" 2>&1
find "$OH/out" -maxdepth 6 -name 'libc++.so' 2>/dev/null | head -5
find "$OH/out" -maxdepth 6 -name 'libunwind.so' 2>/dev/null | head -5
echo "--- libcxx 头文件 ---"
ls -d "$OH/third_party/libcxx/include" 2>&1
ls "$OH/third_party/libcxx/include" 2>/dev/null | head -5
ls -d "$OH/third_party/libunwind" 2>&1
echo "===== C. alpine apk 解包区有无 clang 资源目录 ====="
X=$R/v2/.deps/alpine-clang15/x
ls -d "$X/usr/lib/llvm15/lib/clang/"* 2>&1
ls "$X/usr/lib/llvm15/lib" 2>/dev/null | head
echo "--- apk 缓存列表 ---"
ls "$R/v2/.deps/alpine-clang15/apk" 2>/dev/null
echo "===== D. brew 六补丁(看 ENV super 与 os.sh 改动) ====="
ls "$R/v2/patches/" 2>/dev/null
for f in "$R/v2/patches/"*ENV* "$R/v2/patches/"*env*; do [ -f "$f" ] && echo "--- $f ---" && head -50 "$f"; done 2>/dev/null
echo "===== E. ohos/local tap ====="
T="$R/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew/Library/Taps"
ls "$T" 2>&1
find "$T" -name '*.rb' 2>/dev/null | head
echo "--- hello formula ---"
cat "$T/ohos/local/Formula/hello.rb" 2>/dev/null || find "$T" -name 'hello.rb' -exec cat {} \;
echo "===== F. 容器内工具链 PATH 相关:cc 存在? ====="
chroot "$R/rootfs" /bin/sh -c 'command -v cc gcc clang make ar ld as 2>&1; echo ---; ls /opt'
echo "===== G. 下载可达性(zlib 源码包) ====="
for u in "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz" \
         "https://zlib.net/fossils/zlib-1.3.1.tar.gz" \
         "https://repo.huaweicloud.com/zlib/zlib-1.3.1.tar.gz" \
         "https://www.zlib.net/zlib-1.3.1.tar.gz"; do
  code=$(curl -sIL -m 20 -o /dev/null -w '%{http_code}' "$u" 2>/dev/null)
  echo "$code  $u"
done
echo "===== H. alpine 索引里 binutils / lld-15 ====="
IDX=$(curl -fsSL -m 60 "https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/")
echo "$IDX" | grep -oE 'href="binutils[^"]*"' | head -5
echo "$IDX" | grep -oE 'href="lld-15[^"]*"' | head -3
echo "$IDX" | grep -oE 'href="clang15-[^"]*"' | head -5
