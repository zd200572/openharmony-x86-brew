#!/bin/bash
# V3 stage: 容器即构建机 —— 给 rootfs 装上"容器内真实源码编译"工具链
#   1) Alpine 补件: clang15-headers(clang 资源头文件) / binutils(ld,ar,as,ranlib) / make
#   2) OHOS sysroot(来自 SDK native) 拷入 rootfs /opt/ohos-sysroot, 补 C++ 头与 libc++
#   3) ohos-clang / ohos-clang++ wrapper(镜像 SDK wrapper: -target x86_64-linux-ohos --sysroot -D__MUSL__)
#   4) zlib-1.3.1 源码包缓存到 /opt/src-cache + 生成 ohos/local tap 的 zlib.rb(真实源码 formula)
# 幂等:可重复执行。前置:V2 stage-brew.sh 已完成(brew 已引导、Alpine clang15 已在)。
set -euo pipefail

ROOTFS="${ROOTFS:-/root/ohos-x86/rootfs}"
SDK="${SDK:-/root/ohos-x86/ohos-sdk/linux/native}"
WS="$(cd "$(dirname "$0")" && pwd)"
ALPINE_BASE="https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64"
STAGE=/root/ohos-x86/v3/.deps/alpine-v3

[ -d "$SDK/sysroot/usr/lib/x86_64-linux-ohos" ] || { echo "SDK sysroot 缺失: $SDK"; exit 1; }
[ -d "$ROOTFS/storage/Users/currentUser/.harmonybrew/Homebrew" ] || { echo "rootfs 内 brew 未引导,先跑 v2/stage-brew.sh"; exit 1; }

echo "=== [1/5] Alpine 补件下载解包 ==="
mkdir -p "$STAGE/apk" "$STAGE/x"
cd "$STAGE/apk"
IDX=$(curl -fsSL --retry 3 --retry-delay 2 -m 60 "$ALPINE_BASE/")
get() { echo "$IDX" | grep -F "href=\"$1." | head -1 | grep -oE 'href="[^"]+"' | sed 's/href="//;s/"$//' || true; }
PKGS=""
for pat in "clang15-headers-15" "binutils-2" "binutils-libs-2" "make-4" "jansson-2" "tar-1" "acl-libs-2" "attr-libs-2"; do
  f=$(get "$pat")
  if [ -n "$f" ]; then PKGS="$PKGS $f"; echo "FOUND: $f"; else echo "MISSING(可忽略): $pat"; fi
done
for f in $PKGS; do
  [ -f "$f" ] || curl -fSL --retry 3 --retry-delay 2 -m 300 -O "$ALPINE_BASE/$f"
  tar xzf "$f" -C "$STAGE/x"
done

echo "=== [2/5] 补件拷入 rootfs ==="
# 坑(本次实测): cp -a src/. 穿过 /usr/bin→../bin 软链后, 若与 toybox 应用小程序同名软链
# (strings/ar…)相撞, GNU cp 会穿透过软链覆盖 /bin/toybox 本体, 全容器 ls/grep/sed 尽毁。
# 铁律: 拷贝前先 --remove-destination 删目标软链, 再放真身; 且先验 toybox 完好。
toybox_ok() { chroot "$ROOTFS" /bin/sh -c '/bin/toybox echo TOYBOX_ALIVE' 2>/dev/null | grep -q TOYBOX_ALIVE; }
if ! toybox_ok; then
  echo "!! toybox 本体被毁, 从 v1 基底 tar 恢复"
  V1TAR="${V1TAR:-/mnt/d/share/interesting/openharmony_x86_brew/v1/ohos-rootfs-x86_64.tar}"
  rm -rf /root/ohos-x86/v3/.deps/repair && mkdir -p /root/ohos-x86/v3/.deps/repair
  tar -xf "$V1TAR" -C /root/ohos-x86/v3/.deps/repair --wildcards '*bin/toybox'
  TB=$(find /root/ohos-x86/v3/.deps/repair -name toybox -type f | head -1)
  [ -n "$TB" ] || { echo "基底 tar 里找不到 toybox"; exit 1; }
  cp -f --remove-destination "$TB" "$ROOTFS/bin/toybox"
  toybox_ok || { echo "toybox 恢复失败"; exit 1; }
  echo "toybox 已恢复"
fi
# clang 资源目录(<prefix>/lib/clang/<ver>/include),修 'stdio.h file not found'
if [ -d "$STAGE/x/usr/lib/llvm15/lib/clang" ]; then
  rm -rf "$ROOTFS/usr/lib/llvm15/lib/clang"
  mkdir -p "$ROOTFS/usr/lib/llvm15/lib"
  cp -a "$STAGE/x/usr/lib/llvm15/lib/clang" "$ROOTFS/usr/lib/llvm15/lib/"
  echo "clang 资源头文件就位: $(find "$ROOTFS/usr/lib/llvm15/lib/clang" -name stddef.h | head -1)"
else
  echo "!! clang15-headers 解包内容异常"; exit 1
fi
# binutils/make/jansson/GNU tar: 逐条目 --remove-destination 拷入(见上坑), 新增真实 ar/strings/tar
# 取代 toybox 版(GNU tar 是 brew bottle 的硬需求: toybox tar 无 --hard-dereference)
find "$STAGE/x/usr/bin" -mindepth 1 -maxdepth 1 \
  -exec cp -a --remove-destination {} "$ROOTFS/usr/bin/" \;
# alpine 部分包(如 GNU tar)装在 /bin 而非 /usr/bin
if [ -d "$STAGE/x/bin" ]; then
  find "$STAGE/x/bin" -mindepth 1 -maxdepth 1 \
    -exec cp -a --remove-destination {} "$ROOTFS/bin/" \;
fi
# binutils 私有库(libbfd/libopcodes/libsframe 等): 真实文件强拷 + 断链防护(坑#22)
find "$STAGE/x/usr/lib" -maxdepth 1 -type f -name '*.so*' \
  -exec cp -fL --remove-destination {} "$ROOTFS/usr/lib/" \; 2>/dev/null || true
find "$STAGE/x/usr/lib" -maxdepth 1 -type l -name '*.so*' \
  -exec cp -a {} "$ROOTFS/usr/lib/" \; 2>/dev/null || true
find "$ROOTFS/lib" -maxdepth 1 -name 'libbfd*' -o -maxdepth 1 -name 'libopcodes*' -o -maxdepth 1 -name 'libsframe*' | while read -r f; do
  [ -L "$f" ] && [ ! -e "$f" ] && rm -f "$f" && echo "清除断链: $f"
done || true

echo "=== [3/5] OHOS sysroot 拷入 /opt/ohos-sysroot ==="
rm -rf "$ROOTFS/opt/ohos-sysroot"
mkdir -p "$ROOTFS/opt/ohos-sysroot"
cp -a "$SDK/sysroot/usr" "$ROOTFS/opt/ohos-sysroot/"
# C++ 标准库头(SDK llvm/include/c++/v1)补进 sysroot(SDK sysroot 自身不带)
cp -a "$SDK/llvm/include/c++" "$ROOTFS/opt/ohos-sysroot/usr/include/"
# OHOS 对 libc++ 的官方覆盖层(__config/__config_site, ABI v1/__n1):
# 缺 __config_site 时 libc++ 头直接编不过; SDK 基础头不带, prebuilts libcxx-ndk 里有。
# CI 等无 OHOS 源码树的环境用仓库资产 v3/assets/ 兜底。
OHOS_PRE="${OHOS_PRE:-/root/ohos-x86/OpenHarmony-v7.0-Release/OpenHarmony/prebuilts/clang/ohos/linux-aarch64/libcxx-ndk/include/libcxx-ohos/include/c++/v1}"
if [ -f "$OHOS_PRE/__config_site" ]; then
  cp -f "$OHOS_PRE/__config" "$OHOS_PRE/__config_site" \
    "$ROOTFS/opt/ohos-sysroot/usr/include/c++/v1/"
  echo "libc++ OHOS 覆盖层(__config/__config_site)已就位(prebuilts)"
elif [ -f "$WS/assets/__config_site" ]; then
  cp -f "$WS/assets/__config" "$WS/assets/__config_site" \
    "$ROOTFS/opt/ohos-sysroot/usr/include/c++/v1/"
  echo "libc++ OHOS 覆盖层已就位(仓库资产)"
else
  echo "(警告: 找不到 OHOS __config_site 覆盖层, C++ 编译可能失败)"
fi
# libc++: 用 rootfs /lib64/libc++_shared.so —— 实测其导出命名空间为 __n1, 与 OHOS __config_site
# 的 ABI 命名空间一致(chipset-sdk-sp/libc++.so 是 __h 系统版, 与 NDK 头不匹配, 勿用)。
# 编译期以链接名 libc++.so 进 sysroot, 运行期按其 SONAME(libc++_shared.so)进 /lib。
LIBCXX="$ROOTFS/lib64/libc++_shared.so"
if [ -f "$LIBCXX" ]; then
  cp -fL --remove-destination "$LIBCXX" "$ROOTFS/opt/ohos-sysroot/usr/lib/x86_64-linux-ohos/libc++.so"
  cp -fL --remove-destination "$LIBCXX" "$ROOTFS/lib/libc++_shared.so"
  echo "libc++(libc++_shared.so, __n1)已补进 sysroot 与 /lib"
else
  echo "(警告: rootfs 无 libc++_shared.so, C++ 编译不可用, 继续 C 路线)"
fi

echo "=== [4/5] ohos-clang wrapper ==="
mkdir -p "$ROOTFS/opt/ohos-clang/bin"
# 关键事实: alpine 的 LLVM 把 OHOS 工具链分支剥掉了(libLLVM 连 ohos 三元组字符串都没有),
# driver 一律走 alpine 默认 generic Linux 路径(glibc loader + crtbeginS + -lgcc + -lssp_nonshared)。
# 所以 wrapper 必须: 编译期显式给 include 路径; 链接期 -nostdlib 手工排 OHOS crt 与库,
# 并显式覆盖 dynamic-linker(默认是 glibc 的)与 -no-pie(Scrt1.o 搭配)。
cat > "$ROOTFS/opt/ohos-clang/bin/ohos-clang" <<'EOF'
#!/bin/sh
# 容器内 OHOS x86_64 编译入口(alpine clang15 + OHOS sysroot)
BASE="-target x86_64-linux-ohos --sysroot=/opt/ohos-sysroot -D__MUSL__ -isystem /opt/ohos-sysroot/usr/include/x86_64-linux-ohos"
LIBD=/opt/ohos-sysroot/usr/lib/x86_64-linux-ohos
mode=link shared=0
for a in "$@"; do
  case "$a" in
    -c|-S|-E|-M|-MM|-fsyntax-only|-print*|--version|--help|-emit-obj) mode=compile ;;
    -shared|--shared) shared=1 ;;
  esac
done
if [ "$mode" = compile ]; then
  exec /usr/lib/llvm15/bin/clang $BASE "$@"
fi
# 链接期公共尾巴: -L/-lc 之外必须给 -rpath-link(/lib 存放 rootfs 运行时库, 如 libruby.so
# 传递依赖的 libz.so —— GNU ld 解析传递 NEEDED 不认 -L), /opt/ruby40/lib 供 -lruby 链。
TAIL="-L/lib -Wl,-rpath-link,/lib -Wl,-rpath-link,/opt/ruby40/lib"
if [ "$shared" = 1 ]; then
  exec /usr/lib/llvm15/bin/clang $BASE -nostdlib \
    "$LIBD/crti.o" "$@" "$LIBD/crtn.o" -L"$LIBD" $TAIL -lc \
    -Wl,-dynamic-linker=/lib/ld-musl-x86_64.so.1
fi
exec /usr/lib/llvm15/bin/clang $BASE -nostdlib \
  "$LIBD/Scrt1.o" "$LIBD/crti.o" "$@" "$LIBD/crtn.o" -L"$LIBD" $TAIL -lc \
  -no-pie -Wl,-dynamic-linker=/lib/ld-musl-x86_64.so.1
EOF
cat > "$ROOTFS/opt/ohos-clang/bin/ohos-clang++" <<'EOF'
#!/bin/sh
# C++ 版: -nostdinc++ 显式接 OHOS libc++ 头; 链接期补 -lc++(OHOS libc++.so 已并 abi/unwind)
BASE="-target x86_64-linux-ohos --sysroot=/opt/ohos-sysroot -D__MUSL__ -isystem /opt/ohos-sysroot/usr/include/x86_64-linux-ohos -nostdinc++ -isystem /opt/ohos-sysroot/usr/include/c++/v1"
LIBD=/opt/ohos-sysroot/usr/lib/x86_64-linux-ohos
mode=link shared=0
for a in "$@"; do
  case "$a" in
    -c|-S|-E|-M|-MM|-fsyntax-only|-print*|--version|--help|-emit-obj) mode=compile ;;
    -shared|--shared) shared=1 ;;
  esac
done
if [ "$mode" = compile ]; then
  exec /usr/lib/llvm15/bin/clang++ $BASE "$@"
fi
TAIL="-L/lib -Wl,-rpath-link,/lib -Wl,-rpath-link,/opt/ruby40/lib"
if [ "$shared" = 1 ]; then
  exec /usr/lib/llvm15/bin/clang++ $BASE -nostdlib \
    "$LIBD/crti.o" "$@" "$LIBD/crtn.o" -L"$LIBD" $TAIL -lc++ -lc \
    -Wl,-dynamic-linker=/lib/ld-musl-x86_64.so.1
fi
exec /usr/lib/llvm15/bin/clang++ $BASE -nostdlib \
  "$LIBD/Scrt1.o" "$LIBD/crti.o" "$@" "$LIBD/crtn.o" -L"$LIBD" $TAIL -lc++ -lc \
  -no-pie -Wl,-dynamic-linker=/lib/ld-musl-x86_64.so.1
EOF
chmod +x "$ROOTFS/opt/ohos-clang/bin/ohos-clang" "$ROOTFS/opt/ohos-clang/bin/ohos-clang++"
ln -sf /opt/ohos-clang/bin/ohos-clang   "$ROOTFS/bin/ohos-clang"
ln -sf /opt/ohos-clang/bin/ohos-clang++ "$ROOTFS/bin/ohos-clang++"

# rbconfig 容器化: ruby 交叉编译时烤进 rbconfig 的工具链是宿主机 SDK 路径, 容器内不存在,
# gem 原生扩展(prism 等)一律编译失败。重定向到容器内 ohos-clang/binutils —— 这同时是
# Tier-2 gem(原生扩展)能在容器内构建的前提。
RBCONFIG="$ROOTFS/opt/ruby40/lib/ruby/4.0.0/x86_64-linux-musl/rbconfig.rb"
if [ -f "$RBCONFIG" ] && grep -q "ohos-sdk/linux/native/llvm/bin" "$RBCONFIG"; then
  sed -i \
    -e 's|/root/ohos-x86/ohos-sdk/linux/native/llvm/bin/x86_64-unknown-linux-ohos-clang++|/opt/ohos-clang/bin/ohos-clang++|g' \
    -e 's|/root/ohos-x86/ohos-sdk/linux/native/llvm/bin/x86_64-unknown-linux-ohos-clang|/opt/ohos-clang/bin/ohos-clang|g' \
    -e 's|/root/ohos-x86/ohos-sdk/linux/native/llvm/bin/llvm-strip -S -x|strip|g' \
    -e 's|/root/ohos-x86/ohos-sdk/linux/native/llvm/bin/llvm-ranlib|ranlib|g' \
    -e 's|/root/ohos-x86/ohos-sdk/linux/native/llvm/bin/llvm-nm --no-llvm-bc|nm|g' \
    -e 's|/root/ohos-x86/ohos-sdk/linux/native/llvm/bin/ld.lld|ld|g' \
    -e 's|/root/ohos-x86/ohos-sdk/linux/native/llvm/bin/llvm-ar|ar|g' \
    "$RBCONFIG"
  echo "rbconfig 工具链已重定向到容器内(ohos-clang/binutils)"
fi

echo "=== [5/5] zlib 源码缓存 + formula 生成 ==="
# ruby 的 openssl 编译期 CA 路径(OHOS SDK)容器里没有, SSL_CERT_FILE 指向 rootfs 的 CA,
# 否则 brew test 的 bundle install 拉 rubygems 时 CertificateFailureError。
# brew 启动的 bundle 子进程不继承 SSL_CERT_FILE, 故再写 RubyGems/Bundler 配置文件双保险。
if ! grep -q "SSL_CERT_FILE" "$ROOTFS/etc/homebrew/brew.env" 2>/dev/null; then
  echo "SSL_CERT_FILE=/etc/ssl/certs/cacert.pem" >> "$ROOTFS/etc/homebrew/brew.env"
  echo "brew.env += SSL_CERT_FILE"
fi
# bottle pour(本地 .bottle.tar.gz 安装)需要两件套: HOMEBREW_DEVELOPER(穿透 brew 入口
# 的环境白名单并翻转 forbid_packages_from_paths 默认)+ tap 信任(见 verify 脚本)
if ! grep -q "HOMEBREW_DEVELOPER" "$ROOTFS/etc/homebrew/brew.env" 2>/dev/null; then
  echo "HOMEBREW_DEVELOPER=1" >> "$ROOTFS/etc/homebrew/brew.env"
  echo "brew.env += HOMEBREW_DEVELOPER"
fi
cat > "$ROOTFS/root/.gemrc" <<'EOF'
---
:ssl_ca_cert: /etc/ssl/certs/cacert.pem
EOF
mkdir -p "$ROOTFS/root/.bundle"
cat > "$ROOTFS/root/.bundle/config" <<'EOF'
---
BUNDLE_SSL_CA_CERT: "/etc/ssl/certs/cacert.pem"
EOF
echo "gemrc/.bundle CA 配置已写入"
mkdir -p "$ROOTFS/opt/src-cache"
TARBALL="$ROOTFS/opt/src-cache/zlib-1.3.1.tar.gz"
valid_tar() { tar tzf "$1" >/dev/null 2>&1; }
if [ -f "$TARBALL" ] && valid_tar "$TARBALL"; then
  echo "zlib 源码包已缓存且有效"
else
  rm -f "$TARBALL" "$TARBALL.part"
  ok=""
  # 注意: huaweicloud 的 /zlib/ 路径返回 200 的 HTML 错误页(坑: 须做内容校验), GitHub 优先
  for u in "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz" \
           "https://zlib.net/fossils/zlib-1.3.1.tar.gz" \
           "https://repo.huaweicloud.com/zlib/zlib-1.3.1.tar.gz"; do
    if curl -fSL --retry 3 --retry-delay 2 -m 300 -o "$TARBALL.part" "$u" && valid_tar "$TARBALL.part"; then
      mv "$TARBALL.part" "$TARBALL"; ok="$u"; break
    fi
  done
  [ -n "$ok" ] || { echo "zlib 源码包下载失败(三镜像全部无效)"; exit 1; }
  echo "zlib 源码来自: $ok"
fi
SHA=$(sha256sum "$TARBALL" | awk '{print $1}')
FORMULA_DIR="$ROOTFS/storage/Users/currentUser/.harmonybrew/Homebrew/Library/Taps/ohos/homebrew-local/Formula"
mkdir -p "$FORMULA_DIR"
sed "s/@SHA256@/$SHA/" "$WS/templates/zlib.rb" > "$FORMULA_DIR/zlib.rb"
echo "formula: $FORMULA_DIR/zlib.rb (sha256=$SHA)"

echo "=== 冒烟: chroot 内 C 编译 ==="
cat > "$ROOTFS/tmp/smoke.c" <<'EOF'
#include <stdio.h>
int main() { printf("ohos-x86_64-clang ok\n"); return 0; }
EOF
chroot "$ROOTFS" /bin/sh -c '
set -e
# 基础工具体检(toybox 应用小程序 + 新拷入二进制的缺失库)
/bin/toybox echo TOYBOX_ALIVE | grep -q TOYBOX_ALIVE || { echo "TOYBOX-BROKEN"; exit 1; }
echo "toybox: alive"
for b in grep sed ls ld ar as nm ranlib strip objdump readelf make; do
  p=$(command -v $b) || { echo "MISSING-BIN: $b"; exit 1; }
  if /lib/ld-musl-x86_64.so.1 --list "$p" 2>&1 | grep -qiE "error loading|not found"; then
    echo "BROKEN-DEPS: $b"; /lib/ld-musl-x86_64.so.1 --list "$p"; exit 1
  fi
done
echo TOOLCHAIN_BINS_OK
ohos-clang /tmp/smoke.c -o /tmp/smoke && /tmp/smoke
'
echo STAGE_V3_DONE
