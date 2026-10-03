#!/bin/bash
echo "=== 华为云 ruby 目录索引里的 4.0 ==="
curl -s -m 30 "https://mirrors.huaweicloud.com/ruby/" | grep -oE 'ruby-4\.0[0-9.]*\.tar\.[a-z]+' | sort -u | tail -10
echo
echo "=== 官方 cache.ruby-lang.org 探测 ==="
for v in 4.0.7 4.0.6 4.0.5 4.0.4 4.0.3 4.0.2 4.0.1 4.0.0; do
  for ext in tar.xz tar.gz; do
    code=$(curl -s -o /dev/null -w "%{http_code}" -m 20 -I "https://cache.ruby-lang.org/pub/ruby/4.0/ruby-${v}.${ext}")
    [ "$code" = "200" ] && echo "ruby-${v}.${ext} -> HTTP ${code} ***"
  done
done
echo "(官方探测结束)"
echo
echo "=== 清华镜像探测 ==="
curl -s -m 30 "https://mirrors.tuna.tsinghua.edu.cn/ruby/" 2>/dev/null | grep -oE 'ruby-4\.0[0-9.]*\.tar\.[a-z]+' | sort -u | tail -10
echo
echo "=== gh-proxy github tag 探测 ==="
for tag in v4_0_7 v4_0_6 v4_0_5 v4_0_1 v4_0_0; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -m 30 -L -I "https://gh-proxy.com/https://github.com/ruby/ruby/archive/refs/tags/${tag}.tar.gz")
  echo "${tag} -> HTTP ${code}"
done
