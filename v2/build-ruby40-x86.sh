#!/bin/bash
# 交叉编译 Ruby 4.0.7 for x86_64-linux-ohos(brew 7.0.6_3 要求 major.minor=4.0)
# 配方与 build-ruby-x86.sh(3.4.11)一致, 仅换版本与 prefix
set -e
V2=/root/ohos-x86/v2
SDK=/root/ohos-x86/ohos-sdk/linux/native
LLVM_BIN=$SDK/llvm/bin
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
[ -f ruby-4.0.7.tar.xz ] || curl -fsSL --retry 2 -m 600 -o ruby-4.0.7.tar.xz \
  https://cache.ruby-lang.org/pub/ruby/4.0/ruby-4.0.7.tar.xz
[ -d ruby-4.0.7 ] || tar xf ruby-4.0.7.tar.xz
cd ruby-4.0.7

./configure \
    --host=x86_64-linux-musl \
    --build=x86_64-pc-linux-gnu \
    --prefix=/opt/ruby40 \
    --with-baseruby=/usr/bin/ruby \
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
echo RUBY40_BUILD_OK
