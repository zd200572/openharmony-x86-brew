#!/bin/zsh
# CI 专用 V3 验证(在 chroot 内运行): 编译工具链冒烟 + brew 真实源码构建 + 链接。
# 刻意不含 brew test/bottle/pour(需从 rubygems 拉 dev gems, CI 上走 aliyun 慢且抖;
# 完整 bottle 链路在本地 verify-v3.sh 已验证)。
export HOME=/root
export PATH=/opt/ruby40/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_FROM_API=1
export SSL_CERT_FILE=/etc/ssl/certs/cacert.pem
BREW=/storage/Users/currentUser/.harmonybrew/bin/brew
set -e
rm -rf /tmp/civ3 && mkdir -p /tmp/civ3 && cd /tmp/civ3

echo "--- V3 工具链冒烟(C) ---"
cat > hello.c <<'EOF'
#include <stdio.h>
int main(void) { printf("ci v3: c ok\n"); return 0; }
EOF
ohos-clang hello.c -o hello && ./hello
readelf -l hello | grep interpreter

echo "--- V3 工具链冒烟(C++) ---"
cat > hellocpp.cpp <<'EOF'
#include <string>
#include <cstdio>
int main() { std::string s = "ci v3 cpp"; printf("%s ok\n", s.c_str()); return 0; }
EOF
ohos-clang++ hellocpp.cpp -o hellocpp && ./hellocpp

echo "--- V3 brew 真实源码构建(zlib) ---"
$BREW install --build-bottle ohos/local/zlib 2>&1 | tail -2
$BREW list --versions zlib

echo "--- V3 链接 brew 的 zlib ---"
ZP=$($BREW --prefix zlib)
cat > usez.c <<'EOF'
#include <stdio.h>
#include <zlib.h>
int main(void) { printf("ci v3: brewed zlib %s works\n", zlibVersion()); return 0; }
EOF
ohos-clang usez.c -I"$ZP/include" -L"$ZP/lib" -lz -o usez && ./usez
echo CI_V3_VERIFY_OK
