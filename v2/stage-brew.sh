#!/bin/bash
# V2: 把 ruby/zsh/git 及运行时库组装进 rootfs,准备 brew 引导
set -e
V2=/root/ohos-x86/v2
ROOTFS=/root/ohos-x86/rootfs
OPENSSL_PREFIX=/root/ohos-x86/.build/openssl-3.0.9-ohos-x86_64
ZLIB_PREFIX=/root/ohos-x86/.build/zlib-1.3.1-ohos-x86_64
YAML_PREFIX=$V2/.deps/libyaml
NCURSES_PREFIX=$V2/.deps/ncurses

mkdir -p $ROOTFS/opt/ohos-libs $ROOTFS/storage/Users/currentUser $ROOTFS/root

# 1. 三大工具 + ruby40(brew 7.0.6_3 要求 ruby major.minor=4.0, 见 utils/ruby.sh)
rm -rf $ROOTFS/opt/ruby34 $ROOTFS/opt/ruby40 $ROOTFS/opt/zsh $ROOTFS/opt/git
[ -d $V2/ruby-stage/opt/ruby34 ] && cp -a $V2/ruby-stage/opt/ruby34 $ROOTFS/opt/ruby34
cp -a $V2/zsh-stage/opt/zsh   $ROOTFS/opt/zsh
cp -a $V2/git-stage/opt/git   $ROOTFS/opt/git
if [ -d $V2/ruby40-stage/opt/ruby40 ]; then
  cp -a $V2/ruby40-stage/opt/ruby40 $ROOTFS/opt/ruby40
  find -L $V2/ruby40-stage/opt/ruby40/lib -maxdepth 1 -name '*.so*' -type f \
    -exec cp -fL --remove-destination {} $ROOTFS/lib/ \; 2>/dev/null || true
fi

# 2. 运行时共享库(plain soname 版本; -L 跟随 lib→lib64 符号链接)
# OHOS musl ldso 不读 /etc/ld-musl-*.path, 直接放进默认搜索目录 /lib
# 注意: 只拷真实文件(-L 下符号链接也呈 type f), 每个名字都是实体 ELF;
# 不能用 cp -a 拷符号链接——dst 已有同名链接时会产出断链(ruby 报 libz.so 加载失败的教训)
for d in $OPENSSL_PREFIX/lib $OPENSSL_PREFIX/lib64 $ZLIB_PREFIX/lib $YAML_PREFIX/lib $NCURSES_PREFIX/lib; do
  find -L $d -maxdepth 1 -name '*.so*' -type f -exec cp -fL --remove-destination {} $ROOTFS/lib/ \; 2>/dev/null || true
done
cp -aL $ROOTFS/opt/ohos-libs/. $ROOTFS/lib/ 2>/dev/null || true
rm -rf $ROOTFS/opt/ohos-libs
# 清理 /lib 里指向不存在目标的残留断链(只清 *.so*, 不动系统链接)
find $ROOTFS/lib -maxdepth 1 -name '*.so*' -xtype l -delete 2>/dev/null || true

# 3. musl 动态链接器搜索路径(实测 ldso 不读此文件, 仅作文档记录; 坑#11)
cat > $ROOTFS/etc/ld-musl-x86_64.path <<EOF
/lib
/usr/lib
/lib64/platformsdk
/lib64/chipset-sdk-sp
/opt/ruby34/lib
EOF

# 4. PATH 装配(brew 需要 ruby/git/zsh/curl 可发现; brew 7.0.6_3 要求 ruby 4.0.x)
for b in ruby gem zsh git; do
  case $b in
    ruby)  t=/opt/ruby40/bin/ruby; [ -x $ROOTFS/$t ] || t=/opt/ruby34/bin/ruby ;;
    gem)   t=/opt/ruby40/bin/gem;  [ -x $ROOTFS/$t ] || t=/opt/ruby34/bin/gem ;;
    zsh)   t=/opt/zsh/bin/zsh ;;
    git)   t=/opt/git/bin/git ;;
  esac
  ln -sf $t $ROOTFS/bin/$b
done

# 5. brew 仓库 x86_64 补丁(幂等循环; brew update 会 checkout 发布 tag 抹掉本地修改, 需重打)
if [ -d $ROOTFS/storage/Users/currentUser/.harmonybrew/Homebrew/.git ]; then
  bash /root/ohos-x86/v2/apply-brew-patches.sh
fi

# 5.5 烘焙 brew.env: 禁 auto-update(防 tag 切换抹补丁)、禁 API 模式(服务端无 x86_64 元数据)、
#     显式允许无工具链源码安装(脚本类 formula; V3 再引入编译工具链)
ENV_CONTENT="HOMEBREW_NO_AUTO_UPDATE=1
HOMEBREW_NO_INSTALL_FROM_API=1
HOMEBREW_OHOS_ALLOW_NO_TOOLCHAIN=1"
mkdir -p $ROOTFS/etc/homebrew $ROOTFS/storage/Users/currentUser/.harmonybrew/etc/homebrew
echo "$ENV_CONTENT" > $ROOTFS/etc/homebrew/brew.env
echo "$ENV_CONTENT" > $ROOTFS/storage/Users/currentUser/.harmonybrew/etc/homebrew/brew.env

# 6. 校验
chroot $ROOTFS /bin/sh -c 'ruby --version && git --version && zsh --version && curl --version | head -1'
echo STAGE_BREW_OK
