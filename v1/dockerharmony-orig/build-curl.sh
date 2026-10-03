#!/bin/bash
set -e

WORKDIR=$(pwd)
BUILD_DIR=${WORKDIR}/.build

# Setup ohos-sdk
SDK_ROOT=${BUILD_DIR}/ohos-sdk
rm -rf ${SDK_ROOT}
mkdir -p ${SDK_ROOT}
[ -f ohos-sdk-windows_linux-public.tar.gz ] || \
    aria2c -s 16 -x 16 -k 1M https://repo.huaweicloud.com/openharmony/os/7.0-Release/ohos-sdk-windows_linux-public.tar.gz
tar -zxf ohos-sdk-windows_linux-public.tar.gz -C ${SDK_ROOT}
cd ${SDK_ROOT}/ohos-sdk/linux
unzip -q native-*.zip
cd - >/dev/null
SDK_NATIVE=${SDK_ROOT}/ohos-sdk/linux/native

# Setup env
LLVM_BIN=${SDK_NATIVE}/llvm/bin
export CC=$LLVM_BIN/aarch64-unknown-linux-ohos-clang
export CXX=$LLVM_BIN/aarch64-unknown-linux-ohos-clang++
export LD=$LLVM_BIN/ld.lld
export AR=$LLVM_BIN/llvm-ar
export AS=$LLVM_BIN/llvm-as
export NM=$LLVM_BIN/llvm-nm
export OBJCOPY=$LLVM_BIN/llvm-objcopy
export OBJDUMP=$LLVM_BIN/llvm-objdump
export RANLIB=$LLVM_BIN/llvm-ranlib
export STRIP=$LLVM_BIN/llvm-strip

OPENSSL_PREFIX=${BUILD_DIR}/openssl-3.0.9-ohos-arm64
ZLIB_PREFIX=${BUILD_DIR}/zlib-1.3.1-ohos-arm64
CURL_PREFIX=${WORKDIR}/curl-8.8.0-ohos-arm64

# Build openssl
[ -f openssl-3.0.9.tar.gz ] || curl -fLO https://github.com/openssl/openssl/releases/download/openssl-3.0.9/openssl-3.0.9.tar.gz
tar -zxf openssl-3.0.9.tar.gz
cd openssl-3.0.9/
./Configure --prefix=${OPENSSL_PREFIX} linux-aarch64
make -j$(nproc)
make install_sw
cd ..

# Build zlib
[ -f zlib-1.3.1.tar.gz ] || curl -fLO https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
tar -zxf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --prefix=${ZLIB_PREFIX}
make -j$(nproc)
make install
cd ..

# Build curl. Static linking with libcurl but dynamic linking with other libraries(libc, openssl, zlib).
[ -f curl-8.8.0.tar.gz ] || curl -fLO https://curl.se/download/curl-8.8.0.tar.gz
tar -zxf curl-8.8.0.tar.gz
cd curl-8.8.0/
./configure \
    --host=aarch64-linux \
    --prefix=${CURL_PREFIX} \
    --enable-static \
    --disable-shared \
    --with-openssl=${OPENSSL_PREFIX} \
    --with-zlib=${ZLIB_PREFIX} \
    --with-ca-bundle=/etc/ssl/certs/cacert.pem \
    --with-ca-path=/etc/ssl/certs \
    CPPFLAGS="-D_GNU_SOURCE"
make -j$(nproc)
make install
cd ..

# Clean up intermediate artifacts, keeping the curl build output.
rm -rf *.tar.gz openssl-3.0.9 zlib-1.3.1 curl-8.8.0 ${BUILD_DIR}
