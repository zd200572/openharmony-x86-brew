#!/bin/bash
# 两步: 1) host 原生 ruby 4.0.7(作 baseruby) 2) 交叉编译 ruby 4.0.7
set -e
V2=/root/ohos-x86/v2
SDK=/root/ohos-x86/ohos-sdk/linux/native
LLVM_BIN=$SDK/llvm/bin

# ruby 源码包(仓库 .gitignore 不含大文件, 现场下载; baseruby 与交叉两处都要用)
cd $V2
[ -f ruby-4.0.7.tar.xz ] || curl -fsSL --retry 2 -m 600 -o ruby-4.0.7.tar.xz \
  https://cache.ruby-lang.org/pub/ruby/4.0/ruby-4.0.7.tar.xz

# ---------- 1. host 原生 ruby(仅作 baseruby, 极简) ----------
if [ ! -x /opt/host-ruby/bin/ruby ]; then
  cd $V2
  [ -d ruby-4.0.7-host ] || { rm -rf ruby-4.0.7-host; mkdir ruby-4.0.7-host; tar xf ruby-4.0.7.tar.xz -C ruby-4.0.7-host --strip-components=1; }
  cd ruby-4.0.7-host
  ./configure --prefix=/opt/host-ruby --disable-install-doc --without-gmp >/dev/null
  make -j$(nproc) >/dev/null
  make install >/dev/null
  echo HOST_RUBY_OK
else
  echo HOST_RUBY_EXISTS
fi
/opt/host-ruby/bin/ruby --version

# ---------- 2. 交叉编译 ----------
export CC=$LLVM_BIN/x86_64-unknown-linux-ohos-clang
export CXX=$LLVM_BIN/x86_64-unknown-linux-ohos-clang++
export LD=$LLVM_BIN/ld.lld
export AR=$LLVM_BIN/llvm-ar
export AS=$LLVM_BIN/llvm-as
export NM=$LLVM_BIN/llvm-nm
export OBJCOPY=$LLVM_BIN/llvm-objcopy
export OBJDUMP=$LLVM_BIN/llvm-objdump
export RANLIB=$LLVM_BIN/llvm-ranlib
export STRIP=$LLVM_BIN/llvm-strip
OPENSSL_PREFIX=/root/ohos-x86/.build/openssl-3.0.9-ohos-x86_64
ZLIB_PREFIX=/root/ohos-x86/.build/zlib-1.3.1-ohos-x86_64

cd $V2
[ -d ruby-4.0.7 ] || tar xf ruby-4.0.7.tar.xz
cd ruby-4.0.7
rm -f config.cache
./configure \
    --host=x86_64-linux-musl \
    --build=x86_64-pc-linux-gnu \
    --prefix=/opt/ruby40 \
    --with-baseruby=/opt/host-ruby/bin/ruby \
    --enable-shared \
    --disable-install-doc \
    --with-openssl-dir=$OPENSSL_PREFIX \
    --with-zlib-dir=$ZLIB_PREFIX \
    --with-libyaml-dir=$V2/.deps/libyaml \
    --without-gmp \
    --disable-yjit --disable-zjit
make -j$(nproc)
rm -rf $V2/ruby40-stage
make install DESTDIR=$V2/ruby40-stage

# rbconfig target_os: linux-musl -> linux-ohos
# brew ruby 侧用 RbConfig host_os 判定 OHOS(OS.ohos?), host_os 运行时由 target_os 展开
RBC=$V2/ruby40-stage/opt/ruby40/lib/ruby/4.0.0/x86_64-linux-musl/rbconfig.rb
sed -i 's/\["target_os"\] = "linux-musl"/\["target_os"\] = "linux-ohos"/' "$RBC"
grep -q '"linux-ohos"' "$RBC" || { echo "RBCONFIG PATCH FAILED"; exit 1; }
echo "[rbconfig] target_os=linux-ohos patched"
echo RUBY40_BUILD_OK
