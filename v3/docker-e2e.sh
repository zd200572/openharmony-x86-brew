#!/bin/sh
# docker 容器内端到端自检(V3):编译工具链 + brew bottle 演示
set -e
echo "=== 1. 基线 ==="
/bin/clang --version 2>/dev/null | head -1 || /usr/bin/clang-15 --version | head -1
tar --version | head -1
ld --version 2>/dev/null | head -1 || echo "(ld version n/a)"
echo "=== 2. 容器内 C 编译 ==="
cat > /tmp/e2e.c <<'EOF'
#include <stdio.h>
int main(void) { printf("docker-e2e: compiled inside container on OHOS x86_64\n"); return 0; }
EOF
ohos-clang /tmp/e2e.c -o /tmp/e2e && /tmp/e2e
echo "=== 3. 容器内 C++ 编译 ==="
cat > /tmp/e2e.cpp <<'EOF'
#include <string>
#include <cstdio>
int main() { std::string s = "cpp-e2e"; printf("%s ok\n", s.c_str()); return 0; }
EOF
ohos-clang++ /tmp/e2e.cpp -o /tmp/e2ecpp && /tmp/e2ecpp
echo "=== 4. brew zlib(pour 产物)与源码 formula ==="
. /etc/homebrew/brew.env 2>/dev/null || true
BREW=/storage/Users/currentUser/.harmonybrew/bin/brew
$BREW list --versions zlib
echo "=== 5. brew 源码重装(容器即构建机终极验证)==="
$BREW uninstall -f zlib
$BREW install --build-bottle ohos/local/zlib 2>&1 | tail -2
$BREW test ohos/local/zlib 2>&1 | tail -2
echo "=== 6. 用 brew 的 zlib 链接运行 ==="
ZP=$($BREW --prefix zlib)
cat > /tmp/usez.c <<'EOF'
#include <stdio.h>
#include <zlib.h>
int main(void) { printf("container zlib %s works\n", zlibVersion()); return 0; }
EOF
ohos-clang /tmp/usez.c -I"$ZP/include" -L"$ZP/lib" -lz -o /tmp/usez && /tmp/usez
echo DOCKER_E2E_ALL_DONE
