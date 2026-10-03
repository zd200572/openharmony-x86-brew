#!/bin/bash
# build-curl.sh 的 x86_64 适配版(基于 dockerharmony MIT 原版)
# 差异: x86_64-unknown-linux-ohos wrapper; openssl linux-x86_64; curl --host=x86_64-linux
# 差异: github 直连不可达, 增加 gh 代理回退
set -e

WORKDIR=$(pwd)
BUILD_DIR=${WORKDIR}/.build

dl() { # dl <output> <url> [fallback urls...]
    local out=$1; shift
    for u in "$@"; do
        if curl -fsSL --retry 2 -m 300 -o "$out" "$u"; then return 0; fi
        rm -f "$out"
    done
    return 1
}

# Setup ohos-sdk (V0 已解压, 复用; 不存在则现场解)
SDK_ROOT=${BUILD_DIR}/ohos-sdk
mkdir -p ${SDK_ROOT}
if [ ! -d ${SDK_ROOT}/ohos-sdk/linux/native ]; then
    [ -f ohos-sdk-windows_linux-public.tar.gz ] || \
        aria2c -s 16 -x 16 -k 1M https://repo.huaweicloud.com/openharmony/os/7.0-Release/ohos-sdk-windows_linux-public.tar.gz
    tar -zxf ohos-sdk-windows_linux-public.tar.gz -C ${SDK_ROOT}
fi
cd ${SDK_ROOT}/ohos-sdk/linux
[ -d native ] || unzip -q native-*.zip
cd - >/dev/null
SDK_NATIVE=${SDK_NATIVE:-${SDK_ROOT}/ohos-sdk/linux/native}

# Setup env (x86_64 wrapper)
LLVM_BIN=${SDK_NATIVE}/llvm/bin
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

OPENSSL_PREFIX=${BUILD_DIR}/openssl-3.0.9-ohos-x86_64
ZLIB_PREFIX=${BUILD_DIR}/zlib-1.3.1-ohos-x86_64
CURL_PREFIX=${WORKDIR}/curl-8.8.0-ohos-x86_64

# Build openssl
[ -f openssl-3.0.9.tar.gz ] || dl openssl-3.0.9.tar.gz \
    https://gh-proxy.com/https://github.com/openssl/openssl/releases/download/openssl-3.0.9/openssl-3.0.9.tar.gz \
    https://ghfast.top/https://github.com/openssl/openssl/releases/download/openssl-3.0.9/openssl-3.0.9.tar.gz
tar -zxf openssl-3.0.9.tar.gz
cd openssl-3.0.9/
./Configure --prefix=${OPENSSL_PREFIX} linux-x86_64
make -j$(nproc)
make install_sw
# openssl 3.0 在 linux-x86_64 下安装到 lib64, curl 只认 lib
[ -d ${OPENSSL_PREFIX}/lib ] || ln -s lib64 ${OPENSSL_PREFIX}/lib
cd ..

# Build zlib
[ -f zlib-1.3.1.tar.gz ] || dl zlib-1.3.1.tar.gz \
    https://gh-proxy.com/https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz \
    https://ghfast.top/https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
tar -zxf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --prefix=${ZLIB_PREFIX}
make -j$(nproc)
make install
cd ..

# Build curl. Static libcurl, dynamic libc/openssl/zlib.
[ -f curl-8.8.0.tar.gz ] || dl curl-8.8.0.tar.gz \
    https://curl.se/download/curl-8.8.0.tar.gz \
    https://gh-proxy.com/https://github.com/curl/curl/releases/download/curl-8_8_0/curl-8.8.0.tar.gz
tar -zxf curl-8.8.0.tar.gz
cd curl-8.8.0/
./configure \
    --host=x86_64-linux \
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

echo "curl built at ${CURL_PREFIX}"
