#!/bin/bash
# 交叉编译 Ruby 3.4 for x86_64-linux-ohos
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
[ -d ruby-3.4.11 ] || tar xf ruby-3.4.11.tar.xz
cd ruby-3.4.11

./configure \
    --host=x86_64-linux-musl \
    --build=x86_64-pc-linux-gnu \
    --prefix=/opt/ruby34 \
    --with-baseruby=/usr/bin/ruby \
    --enable-shared \
    --disable-install-doc \
    --with-openssl-dir=$OPENSSL_PREFIX \
    --with-zlib-dir=$ZLIB_PREFIX \
    --with-libyaml-dir=$V2/.deps/libyaml \
    --without-gmp \
    --disable-yjit --disable-zjit

make -j$(nproc)
make install DESTDIR=$V2/ruby-stage
echo RUBY_BUILD_OK
