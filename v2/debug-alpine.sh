#!/bin/bash
echo "=== Alpine 镜像可用版本 ==="
for v in v3.22 v3.21 v3.20 v3.19; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -m 15 "https://dl-cdn.alpinelinux.org/alpine/${v}/main/x86_64/APKINDEX.tar.gz")
  echo "${v} -> ${code}"
done
echo
echo "=== v3.22 main 里 clang/llvm 相关包 ==="
curl -s -m 30 "https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/" | grep -oE 'href="[^"]*"' | grep -E "clang|llvm" | head -20
