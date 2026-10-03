#!/usr/bin/env python3
# 重新给 rootfs 内 brew 的 os.sh 打 x86_64 补丁(上次被 brew update 的 git 操作还原)
import pathlib

P = pathlib.Path('/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew/Library/Homebrew/utils/os.sh')
s = P.read_text()

old1 = 'OHOS_MUSL_LIBC="/lib/ld-musl-aarch64.so.1"'
new1 = 'OHOS_MUSL_LIBC="/lib/ld-musl-$(uname -m).so.1"'
old2 = '  HOMEBREW_PROCESSOR="arm64"\n  HOMEBREW_SYSTEM="Linux"\n  HOMEBREW_OHOS_SYSTEM="ohos"'
new2 = '  HOMEBREW_PROCESSOR="$(uname -m)"\n  HOMEBREW_SYSTEM="Linux"\n  HOMEBREW_OHOS_SYSTEM="ohos"'

if new1 in s and new2 in s:
    print("OS_SH_ALREADY_PATCHED")
elif old1 in s and old2 in s:
    s = s.replace(old1, new1).replace(old2, new2)
    P.write_text(s)
    print("OS_SH_PATCHED")
else:
    raise SystemExit("PATTERN_NOT_FOUND: os.sh 结构与预期不符, 需人工检查")

# 展示 os.sh 余下部分(60 行后)确认 prefix 解析无 arm64 硬编码残留
print("---- os.sh lines 60+ ----")
lines = P.read_text().splitlines()
for i, line in enumerate(lines[59:], start=60):
    print(f"{i}\t{line}")
