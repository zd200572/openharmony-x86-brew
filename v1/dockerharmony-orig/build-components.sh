#!/bin/bash
set -e

WORKDIR=$(pwd)

# Download OpenHarmony source code
rm -rf OpenHarmony-v7.0-Release code-v7.0-Release.tar.gz
aria2c -s 16 -x 16 -k 1M https://repo.huaweicloud.com/openharmony/os/7.0-Release/code-v7.0-Release.tar.gz
tar -zxf code-v7.0-Release.tar.gz
cd OpenHarmony-v7.0-Release/OpenHarmony

# Disable HiLog because the container does not include the HiLog service.
cd third_party/musl/
patch -p1 < $WORKDIR/disable-hilog.patch
cd ../../

# Build only the components needed for the container rootfs.
# Outputs go to out/rk3568/thirdparty/ and out/rk3568/obj/build/common/musl/.
./build.sh --product-name rk3568 --target-cpu arm64 \
    --build-target musl_install \
    --build-target libcpp_install \
    --build-target toybox \
    --build-target sh \
    --build-target libcrypto_shared \
    --build-target libssl_shared \
    --build-target shared_libz \
    --build-target libselinux \
    --build-target libpcre2
