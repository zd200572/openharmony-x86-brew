#!/bin/bash
# V2 依赖链: libyaml(ruby psych 用) -> ncurses -> zsh -> git
set -e
V2=/root/ohos-x86/v2
SDK=/root/ohos-x86/ohos-sdk/linux/native
LLVM_BIN=$SDK/llvm/bin
export CC=$LLVM_BIN/x86_64-unknown-linux-ohos-clang
export CXX=$LLVM_BIN/x86_64-unknown-linux-ohos-clang++
export LD=$LLVM_BIN/ld.lld
export AR=$LLVM_BIN/llvm-ar
export RANLIB=$LLVM_BIN/llvm-ranlib
export STRIP=$LLVM_BIN/llvm-strip
OPENSSL_PREFIX=/root/ohos-x86/.build/openssl-3.0.9-ohos-x86_64
ZLIB_PREFIX=/root/ohos-x86/.build/zlib-1.3.1-ohos-x86_64
YAML_PREFIX=$V2/.deps/libyaml
NCURSES_PREFIX=$V2/.deps/ncurses
dl() { local out=$1; shift; for u in "$@"; do curl -fsSL --retry 2 -m 300 -o "$out.tmp" "$u" && { mv "$out.tmp" "$out"; return 0; }; rm -f "$out.tmp"; done; return 1; }
mkdir -p $V2/.deps

# ---------- libyaml ----------
cd $V2
[ -f .deps/libyaml.done ] || {
  [ -f yaml-0.2.5.tar.gz ] || dl yaml-0.2.5.tar.gz \
    https://pyyaml.org/download/libyaml/yaml-0.2.5.tar.gz \
    https://gh-proxy.com/https://github.com/yaml/libyaml/releases/download/0.2.5/yaml-0.2.5.tar.gz
  tar xzf yaml-0.2.5.tar.gz && cd yaml-0.2.5
  ./configure --host=x86_64-linux-musl --build=x86_64-pc-linux-gnu --prefix=$YAML_PREFIX --enable-shared
  make -j$(nproc) && make install
  cd .. && touch .deps/libyaml.done && echo LIBYAML_OK
}

# ---------- ncurses ----------
[ -f .deps/ncurses.done ] || {
  [ -f ncurses-6.4.tar.gz ] || dl ncurses-6.4.tar.gz \
    https://mirrors.tuna.tsinghua.edu.cn/gnu/ncurses/ncurses-6.4.tar.gz \
    https://ftp.gnu.org/gnu/ncurses/ncurses-6.4.tar.gz
  tar xzf ncurses-6.4.tar.gz && cd ncurses-6.4
  ./configure --host=x86_64-linux-musl --build=x86_64-pc-linux-gnu --prefix=$NCURSES_PREFIX \
    --enable-widec --without-cxx --without-cxx-binding --without-ada --without-progs --without-tests
  make -j$(nproc) && make install
  cd .. && touch .deps/ncurses.done && echo NCURSES_OK
}

# ---------- zsh ----------
[ -f .deps/zsh.done ] || {
  [ -f zsh-5.9.tar.xz ] || dl zsh-5.9.tar.xz \
    https://downloads.sourceforge.net/project/zsh/zsh/5.9/zsh-5.9.tar.xz \
    https://gh-proxy.com/https://github.com/zsh-users/zsh/archive/refs/tags/zsh-5.9.tar.gz \
    https://www.zsh.org/pub/zsh-5.9.tar.xz
  tar xf zsh-5.9.tar.xz && cd zsh-5.9
  # --disable-dynamic: 交叉编译下不构建动态 .so 模块, 一律走静态链接路径
  CPPFLAGS="-I$NCURSES_PREFIX/include" LDFLAGS="-L$NCURSES_PREFIX/lib" \
  ./configure --host=x86_64-linux-musl --build=x86_64-pc-linux-gnu --prefix=/opt/zsh \
    --enable-multibyte --without-tcsetpgrp --disable-dynamic
  # configure 顶层生成的 config.modules 才是模块构建依据; 交叉编译跑不了 regexec
  # 探测, zsh/regex 被求值为 link=no 整体跳过(run3 37097917616: brew 启动 =~ 即死),
  # 定向改回 static 编入二进制
  sed -i '/^name=zsh\/regex / s/link=no/link=static/' config.modules
  make -j$(nproc)
  make install DESTDIR=$V2/zsh-stage
  cd .. && touch .deps/zsh.done && echo ZSH_OK
}

# ---------- git ----------
[ -f .deps/git.done ] || {
  [ -f git-2.46.0.tar.xz ] || dl git-2.46.0.tar.xz \
    https://www.kernel.org/pub/software/scm/git/git-2.46.0.tar.xz \
    https://gh-proxy.com/https://github.com/git/git/archive/refs/tags/v2.46.0.tar.gz \
    https://mirrors.tuna.tsinghua.edu.cn/kernel.org/software/scm/git/git-2.46.0.tar.xz
  tar xf git-2.46.0.tar.xz && cd git-2.46.0
  make -j$(nproc) prefix=/opt/git NO_GETTEXT=1 NO_TCLTK=1 NO_EXPAT=1 NO_PERL=1 NO_REGEX=NeedsStartEnd \
    CC=$CC \
    CURL_CFLAGS="-I$V2/curl-8.8.0-ohos-x86_64/include" \
    CURL_LDFLAGS="-L$V2/curl-8.8.0-ohos-x86_64/lib -lcurl -lssl -lcrypto -lz -lpthread" \
    OPENSSLDIR=$OPENSSL_PREFIX \
    LDFLAGS="-Wl,-z,undefs -L$OPENSSL_PREFIX/lib -L$ZLIB_PREFIX/lib"
  make prefix=/opt/git NO_GETTEXT=1 NO_TCLTK=1 NO_EXPAT=1 NO_PERL=1 NO_REGEX=NeedsStartEnd \
    CC=$CC \
    CURL_CFLAGS="-I$V2/curl-8.8.0-ohos-x86_64/include" \
    CURL_LDFLAGS="-L$V2/curl-8.8.0-ohos-x86_64/lib -lcurl -lssl -lcrypto -lz -lpthread" \
    OPENSSLDIR=$OPENSSL_PREFIX \
    LDFLAGS="-Wl,-z,undefs -L$OPENSSL_PREFIX/lib -L$ZLIB_PREFIX/lib" \
    INSTALL_SYMLINKS=1 install DESTDIR=$V2/git-stage
  cd .. && touch .deps/git.done && echo GIT_OK
}
echo DEPS_ALL_DONE
