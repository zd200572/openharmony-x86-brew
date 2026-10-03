#!/bin/bash
# 幂等应用 v2/patches/*.patch 到 brew 仓库(brew update 会 checkout 发布 tag 抹掉一切本地修改)
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
for patch in /root/ohos-x86/v2/patches/*.patch; do
  [ -f "$patch" ] || continue
  if ( cd "$HB" && git apply --check --whitespace=nowarn "$patch" 2>/dev/null ); then
    ( cd "$HB" && git apply --whitespace=nowarn "$patch" ) && echo "[patch] applied: $(basename "$patch")"
  else
    echo "[patch] skipped (already applied or inapplicable): $(basename "$patch")"
  fi
done
