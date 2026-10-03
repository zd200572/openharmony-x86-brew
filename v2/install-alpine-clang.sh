#!/bin/bash
# 给 rootfs 安装 Alpine musl 原生 clang15(真实编译器, 供 brew CompilerSelector 使用; V3 构建机刚需)
# .apk = gzip tar; 库进 /lib(默认搜索路径), 排除与 rootfs 现有 musl 库冲突的 libz
set -e
ROOTFS=/root/ohos-x86/rootfs
BASE=https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64
STAGE=/root/ohos-x86/v2/.deps/alpine-clang15
mkdir -p $STAGE/apk $STAGE/x
cd $STAGE/apk

# 1. 解析包名(固定字符串前缀匹配: "包名-版本首段.")
IDX=$(curl -fsSL -m 60 "$BASE/")
get() { echo "$IDX" | grep -F "href=\"$1." | head -1 | grep -oE 'href="[^"]+"' | sed 's/href="//;s/"$//'; }
PKGS=""
# 注意: 索引 href 中 "+" 被编码为 %2B; libstdc++/libgcc 主版本号写死为 alpine v3.22 的 14
for pat in "clang15-15" "clang15-libs-15" "llvm15-libs-15" "libstdc%2B%2B-14" "libgcc-14" "ncurses-libs-6" "zstd-libs-1" "libxml2-2" "libffi-3" "xz-libs-5"; do
  f=$(get "$pat")
  if [ -n "$f" ]; then PKGS="$PKGS $f"; echo "FOUND: $f"; else echo "MISSING: $pat"; fi
done

# 2. 下载解包
for f in $PKGS; do
  [ -f "$f" ] || curl -fsSL -m 300 -O "$BASE/$f"
  tar xzf "$f" -C $STAGE/x
done

# 3. 库进 /lib(排除 libz* — rootfs 已有 musl zlib)
find $STAGE/x/usr/lib -maxdepth 1 \( -name '*.so*' ! -name 'libz.so*' \) -exec cp -a {} $ROOTFS/lib/ \;

# 4. clang 二进制 + 符号链接(alpine 的 clang-15 是指向 ../lib/llvm15/bin/clang-15 的链接,
#    二进制实体在 usr/lib/llvm15/bin, 必须一并拷贝)
cp -a $STAGE/x/usr/bin/. $ROOTFS/usr/bin/ 2>/dev/null || true
if [ -d $STAGE/x/usr/lib/llvm15 ]; then
  mkdir -p $ROOTFS/usr/lib
  cp -a $STAGE/x/usr/lib/llvm15 $ROOTFS/usr/lib/
fi

# 5. chroot 内检查
echo "=== clang 版本 ==="
chroot $ROOTFS /bin/sh -c '/usr/bin/clang-15 --version 2>&1 | head -2'
echo "=== clang-15 缺失库检查 ==="
chroot $ROOTFS /bin/sh -c 'LD_LIBRARY_PATH= /lib/ld-musl-x86_64.so.1 --list /usr/bin/clang-15 2>&1' | grep -iE "error loading|not found" && echo "有缺失库!" || echo ALL_LIBS_OK
echo ALPINE_CLANG_DONE
