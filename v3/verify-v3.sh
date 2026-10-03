#!/bin/bash
# V3 验证:chroot 内走通"容器内真实源码编译"全链路
#   1. C 冒烟(ohos-clang → 运行 → readelf 查 interpreter/sysroot 库)
#   2. ar/ranlib 冒烟(静态库)
#   3. C++ 冒烟(libc++)
#   4. brew install --build-from-source ohos/local/zlib(真实上游源码)
#   5. brew test
#   6. 用已安装的 zlib 链接一个真实程序(inflate/deflate 往返)
#   7. brew bottle(出 x86_64_ohos bottle)
#   8. uninstall → pour bottle → 再 test(bottle 闭环)
set -u
ROOTFS=/root/ohos-x86/rootfs
WS=/mnt/d/share/interesting/openharmony_x86_brew

mountpoint -q "$ROOTFS/dev"  || mount --bind /dev  "$ROOTFS/dev"
mountpoint -q "$ROOTFS/proc" || mount --bind /proc "$ROOTFS/proc"
mountpoint -q "$ROOTFS/sys"  || mount --bind /sys  "$ROOTFS/sys"

cat > "$ROOTFS/root/v3-verify-inner.sh" <<'INNER_EOF'
#!/bin/zsh
export HOME=/root
export PATH=/opt/ruby40/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_FROM_API=1
# Harmonybrew 默认 forbid_packages_from_paths(bottle pour 需要); INTERNAL 豁免变量会被
# brew 入口洗掉, 实测只有 HOMEBREW_DEVELOPER 能穿透并翻转默认
export HOMEBREW_DEVELOPER=1
export SSL_CERT_FILE=/etc/ssl/certs/cacert.pem
BREW=/storage/Users/currentUser/.harmonybrew/bin/brew
set -e
rm -rf /tmp/v3 && mkdir -p /tmp/v3 && cd /tmp/v3

echo "########## 1. C 冒烟 ##########"
cat > hello.c <<'EOF'
#include <stdio.h>
int main(void) { printf("hello from ohos x86_64 clang\n"); return 0; }
EOF
ohos-clang hello.c -o hello
./hello
echo "--- readelf interpreter / 依赖 ---"
readelf -l hello | grep -E 'interpreter'
readelf -d hello | grep NEEDED || echo "(无 NEEDED, 纯静态符号? musl libc.so 链接应有 libc.so)"
./hello && echo "[C smoke] exit=0"

echo "########## 2. ar/ranlib 冒烟 ##########"
cat > add.c <<'EOF'
int add3(int a, int b, int c) { return a + b + c; }
EOF
ohos-clang -c add.c -o add.o
ar cr libadd.a add.o && ranlib libadd.a
cat > useadd.c <<'EOF'
#include <stdio.h>
int add3(int a, int b, int c);
int main(void) { printf("add3=%d\n", add3(1, 2, 3)); return 0; }
EOF
ohos-clang useadd.c -L. -ladd -o useadd
./useadd

echo "########## 3. C++ 冒烟 ##########"
cat > hellocpp.cpp <<'EOF'
#include <cstdio>
#include <string>
#include <vector>
int main() {
  std::string s = "cpp-on-ohos-x86_64";
  std::vector<int> v{1, 2, 3};
  printf("%s size=%zu\n", s.c_str(), v.size());
  return 0;
}
EOF
ohos-clang++ hellocpp.cpp -o hellocpp
./hellocpp

echo "########## 4. brew install(源码 + bottle 模式)##########"
$BREW uninstall -f ohos/local/zlib 2>/dev/null || true
$BREW install --build-bottle ohos/local/zlib
$BREW list --versions zlib

echo "########## 5. brew test zlib ##########"
$BREW test ohos/local/zlib

echo "########## 6. 链接已安装 zlib 的真实程序 ##########"
ZP=$($BREW --prefix zlib)
cat > use_zlib.c <<'EOF'
#include <stdio.h>
#include <string.h>
#include <zlib.h>
int main(void) {
  const char *src = "real zlib on OHOS x86_64, brewed from source";
  unsigned long slen = strlen(src) + 1;
  unsigned char comp[128], out[128];
  unsigned long clen = sizeof(comp), olen = sizeof(out);
  compress2(comp, &clen, (const Bytef *)src, slen, 9);
  uncompress(out, &olen, comp, clen);
  printf("zlib %s: [%s] %lu -> %lu -> %lu bytes\n",
         zlibVersion(), (char *)out, slen, clen, olen);
  return strcmp((char *)out, src) == 0 ? 0 : 1;
}
EOF
ohos-clang use_zlib.c -I"$ZP/include" -L"$ZP/lib" -lz -o use_zlib
./use_zlib

echo "########## 7. brew bottle(出 x86_64_ohos bottle)##########"
cd /tmp/v3
$BREW bottle ohos/local/zlib
ls -la *.bottle.tar.gz
ls -la *.json(N) 2>/dev/null || echo "(无 .json, 新版 brew bottle 只出 tar.gz)"

echo "########## 8. pour: uninstall → install bottle → test ##########"
$BREW uninstall -f zlib
$BREW trust ohos/local 2>/dev/null || true
BOTTLE=$PWD/$(ls *.bottle.tar.gz | head -1)
$BREW install "$BOTTLE"
$BREW list --versions zlib
$BREW test ohos/local/zlib
ZP2=$($BREW --prefix zlib)
ls -la "$ZP2/lib/"
echo VERIFY_V3_ALL_DONE
INNER_EOF

echo ">>> 运行 chroot 内验证(日志同步落盘)"
chroot "$ROOTFS" /bin/zsh /root/v3-verify-inner.sh 2>&1 | tee /root/v3-verify.log
RC=${pipestatus[1]:-$?}

echo ">>> 回收产物到工作区"
mkdir -p "$WS/v3/artifacts"
cp -f /root/v3-verify.log "$WS/v3/artifacts/" || true
cp -f "$ROOTFS/tmp/v3/"*.bottle.tar.gz "$WS/v3/artifacts/" 2>/dev/null || true
cp -f "$ROOTFS/tmp/v3/"*.json "$WS/v3/artifacts/" 2>/dev/null || true
ls -la "$WS/v3/artifacts/"

if grep -q VERIFY_V3_ALL_DONE /root/v3-verify.log; then
  echo ">>> V3 验证:全部通过"
else
  echo ">>> V3 验证:未走完,看上方日志定位(内层脚本已留 $ROOTFS/root/v3-verify-inner.sh)"
  exit 1
fi
