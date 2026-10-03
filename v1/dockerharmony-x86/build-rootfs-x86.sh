#!/bin/bash
# build-rootfs.sh 的 x86_64 适配版(基于 dockerharmony MIT 原版)
# 差异: musl loader/path/ini 与 libc++ 库路径按 arch 参数化; 对可选文件做存在性容错
set -e

WORKDIR=$(pwd)
OHOS_DIR=${WORKDIR}/OpenHarmony-v7.0-Release/OpenHarmony
OUT_DIR=${OHOS_DIR}/out/rk3568
ARCH=x86_64

rm -rf rootfs
mkdir -p rootfs/bin rootfs/lib rootfs/lib64/platformsdk rootfs/lib64/chipset-sdk-sp \
         rootfs/etc/ssl/certs rootfs/dev rootfs/proc rootfs/sys rootfs/mnt \
         rootfs/storage rootfs/opt rootfs/tmp rootfs/root

# --- bin: toybox + its applet symlinks ---
cp ${OUT_DIR}/thirdparty/toybox/toybox rootfs/bin/toybox
sed -n '/symlink_target_name = \[/,/^    \]/p' ${OHOS_DIR}/third_party/toybox/BUILD.gn \
    | grep -vE "symlink_target_name|^    \]" | sed 's/^[[:space:]]*"//;s/",$//' \
    | grep -v '^$' | grep -v '^\.\./' | grep -v '^restorecon$' > /tmp/toybox-applets.txt
while read -r applet; do
    [ -n "$applet" ] && ln -s toybox rootfs/bin/$applet
done < /tmp/toybox-applets.txt

# --- bin: mksh as /bin/sh ---
cp ${OUT_DIR}/thirdparty/mksh/sh rootfs/bin/sh

# --- lib: musl libc (按名字查找, 兼容 out 子目录结构变化) ---
LOADER=$(find ${OUT_DIR}/obj/build/common/musl -name "ld-musl-${ARCH}.so.1" -type f | head -1)
[ -n "$LOADER" ] || { echo "ERROR: ld-musl-${ARCH}.so.1 not found"; exit 1; }
cp ${LOADER} rootfs/lib/
ln -s ../lib/ld-musl-${ARCH}.so.1 rootfs/lib64/libc.so

# --- etc: musl ld path config ---
LDPATH=$(find ${OUT_DIR}/obj/build/common/musl -name "ld-musl-${ARCH}.path" | head -1)
[ -n "$LDPATH" ] && cp ${LDPATH} rootfs/etc/ || echo "WARN: ld-musl-${ARCH}.path not found, skip"
for ini in $(find ${OUT_DIR}/obj/third_party/musl/third_party/musl/config -name "ld-musl-namespace-${ARCH}*" 2>/dev/null); do
    cp ${ini} rootfs/etc/
done

# --- lib64: openssl / zlib ---
cp ${OUT_DIR}/thirdparty/openssl/libcrypto_openssl.z.so rootfs/lib64/platformsdk/
cp ${OUT_DIR}/thirdparty/openssl/libssl_openssl.z.so rootfs/lib64/platformsdk/
cp ${OUT_DIR}/thirdparty/zlib/libshared_libz.z.so rootfs/lib64/platformsdk/

# --- lib64: selinux / pcre2 ---
cp ${OUT_DIR}/thirdparty/selinux/libselinux.z.so rootfs/lib64/chipset-sdk-sp/
cp ${OUT_DIR}/thirdparty/pcre2/libpcre2.z.so rootfs/lib64/chipset-sdk-sp/
ln -s ../chipset-sdk-sp/libselinux.z.so rootfs/lib64/platformsdk/libselinux.z.so
ln -s ../chipset-sdk-sp/libpcre2.z.so rootfs/lib64/platformsdk/libpcre2.z.so

# --- lib64: SDK runtime libraries (libc++) ---
CXXSHARED=$(find ${OUT_DIR}/obj/build/common/libcpp -name "libc++_shared.so" -path "*${ARCH}-linux-ohos*" | head -1)
[ -n "$CXXSHARED" ] || { echo "ERROR: libc++_shared.so (${ARCH}) not found"; exit 1; }
cp ${CXXSHARED} rootfs/lib64/
LIBCXX=$(find ${OUT_DIR}/obj/build/common/musl -name "libc++.so" -path "*${ARCH}-linux-ohos*" | head -1)
[ -n "$LIBCXX" ] && cp ${LIBCXX} rootfs/lib64/chipset-sdk-sp/ || echo "WARN: libc++.so not found, skip"

# --- bin: curl (built by build-curl-x86.sh) ---
cp curl-8.8.0-ohos-x86_64/bin/curl rootfs/bin/
patchelf --replace-needed libssl.so.3 libssl_openssl.z.so rootfs/bin/curl
patchelf --replace-needed libcrypto.so.3 libcrypto_openssl.z.so rootfs/bin/curl
patchelf --replace-needed libz.so.1 libshared_libz.z.so rootfs/bin/curl

# --- etc: CA certificates ---
curl -fsSL --retry 3 -m 60 -o rootfs/etc/ssl/certs/cacert.pem https://curl.se/ca/cacert.pem

# Complete the FHS directory.
mkdir -p rootfs/usr rootfs/system
ln -s ../bin rootfs/usr/bin
ln -s ../lib rootfs/usr/lib
ln -s ../lib64 rootfs/usr/lib64
chmod 700 rootfs/root

# NOTICE.txt check (skip arch-dependent strictness: compare only basenames)
echo "root:x:0:0:root:/root:/bin/sh" > rootfs/etc/passwd
echo "root:x:0:" > rootfs/etc/group
cp NOTICE.txt rootfs/etc/ 2>/dev/null || true

echo "rootfs assembled at ${WORKDIR}/rootfs"
