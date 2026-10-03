#!/usr/bin/env python3
# brew ruby 侧 x86_64 三处适配: ld.rb 加 musl x86_64 loader / linkage allowlist 加 musl soname / ENV loader path 架构动态化
import pathlib

HB = pathlib.Path('/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew/Library/Homebrew')

def apply(path, old, new):
    p = HB / path
    s = p.read_text()
    if new in s:
        print(f"SKIP (already): {path}")
        return
    assert old in s, f"PATTERN NOT FOUND in {path}"
    p.write_text(s.replace(old, new))
    print(f"PATCHED: {path}")

apply('os/linux/ld.rb',
"""        x86_64:  %w[
          /lib64/ld-linux-x86-64.so.2
          /system/bin/linker64
        ].freeze,""",
"""        x86_64:  %w[
          /lib64/ld-linux-x86-64.so.2
          /lib/ld-musl-x86_64.so.1
          /system/bin/linker64
        ].freeze,""")

apply('extend/os/linux/linkage_checker.rb',
"""        ld-linux-x86-64.so.2
        ld-linux-aarch64.so.1""",
"""        ld-linux-x86-64.so.2
        ld-linux-aarch64.so.1
        ld-musl-x86_64.so.1
        ld-musl-aarch64.so.1
        libc.so""")

apply('extend/os/linux/extend/ENV/super.rb',
'        path = "/lib/ld-musl-aarch64.so.1"',
'        path = "/lib/ld-musl-#{RbConfig::CONFIG["host_cpu"]}.so.1"')

apply('extend/os/linux/development_tools.rb',
"""        sig { returns(Symbol) }
        def default_compiler = :clang

        sig { returns(String) }
        def installation_instructions""",
"""        sig { returns(Symbol) }
        def default_compiler = :clang

        sig { returns(T::Boolean) }
        def installed?
          # OHOS: the container ships no source-build toolchain yet (V3 will);
          # allow script-like source installs behind an explicit opt-in switch.
          return true if OS.ohos? && !ENV.fetch("HOMEBREW_OHOS_ALLOW_NO_TOOLCHAIN", "").empty?
          !!(locate("clang") || locate("gcc"))
        end

        sig { returns(String) }
        def installation_instructions""")

print("RUBY_X86_PATCHES_DONE")
