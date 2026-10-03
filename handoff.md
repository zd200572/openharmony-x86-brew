# Handoff:OpenHarmony x86 + Harmonybrew 移植项目

> 更新:2026-10-03 · 本文档供新会话/他人接续使用,配套阅读 `docs/V0-验证报告.md`、`docs/V1-验证报告.md`、`docs/V2-验证报告.md`、`docs/调研规划-x86-OpenHarmony-可用性.md`

## 一、项目目标

把 [Harmonybrew](https://atomgit.com/Harmonybrew)(仅支持 arm64 的鸿蒙版 Homebrew)生态整体搬到 x86 版 OpenHarmony。验证阶梯:V0 工具链冒烟 → V1 最小 rootfs 容器 → V2 brew 引导链 → V3 bottle 生态/CI。

**V0 ✅ V1 ✅ V2 ✅ CI ✅ V3(容器内真实源码编译)✅ 已完成(2026-10-03,详见 `docs/V3-验证报告.md`)。剩余:上游 PR、harmonybrew ci 仓库 x86_64 矩阵、Tier-1 批量出 bottle。**

## 二、环境清单(全部已就位,可直接用)

| 位置 | 内容 |
|---|---|
| WSL 发行版 `ohos-build`(D:\wsl\ohos-build\ext4.vhdx,root 默认) | 唯一构建环境,Ubuntu 22.04.5,16C/14G。**绝对不要动用户原 Ubuntu** |
| `/root/ohos-x86/OpenHarmony-v7.0-Release/OpenHarmony` | OHOS 7.0 全量源码(~200G,含 openharmony_prebuilts 缓存),已打全部 GN 补丁 |
| `/root/ohos-x86/ohos-sdk/linux/native` | OHOS SDK native(llvm 15.0.4 + sysroot,V0 下载解压) |
| `/root/ohos-x86/rootfs` | V1 rootfs(可 chroot),**V2 已注入 ruby/zsh/git + 运行时库** |
| `/root/ohos-x86/dockerharmony`、`/root/ohos-x86/dockerharmony-x86/` | 上游克隆 + x86 适配脚本(build-components-x86.sh / build-curl-x86.sh / build-rootfs-x86.sh / stageA.sh / stageB.sh) |
| `/root/ohos-x86/v2/` | V2 资产:ruby-3.4.11 交叉编译产物(ruby-stage/)、zsh-stage/、git-stage/、.deps/{libyaml,ncurses}、curl-8.8.0-ohos-x86_64、build-ruby-x86.sh、build-deps-x86.sh、stage-brew.sh、hb-recon/{install.sh(已patch),brew.tar.gz} |
| `/root/ohos-x86/v3/` | V3 资产:.deps/alpine-v3(补件 apk 缓存)、.deps/repair(toybox 自愈) |
| `D:\share\interesting\openharmony_x86_brew\` | 工作区:v1/(脚本+补丁+rootfs tar)、v2/(脚本)、v3/(容器内编译工具链:stage-v3.sh / verify-v3.sh / ci-verify-v3.sh / docker-e2e.sh / pack-rootfs-v3.sh / templates/zlib.rb / assets/{__config,__config_site} / artifacts/{bottle,日志})、docs/(四份报告) |
| Docker(Windows) | `dockerharmony:x86_64` 镜像(id 80ec959f457d,807MB rootfs-v3.tar,**代理问题已修**(见坑#14)) |

工具链环境变量(所有交叉编译通用):`CC=$SDK/llvm/bin/x86_64-unknown-linux-ohos-clang`(wrapper 自带 --sysroot),host 三元组一律用 **`x86_64-linux-musl`**(config.sub 不认识 ohos 后缀)。

## 三、当前进度与断点

**已完成(V2,2026-10-03)**——详见 `docs/V2-验证报告.md`:
- Ruby 4.0.7 交叉编译(host 原生 baseruby + 交叉两步,`v2/build-ruby40-host-then-cross.sh`;rbconfig target_os 补为 linux-ohos)。brew 7.0.6_3 要求 ruby major.minor=4.0,ruby 3.4.11 已不够
- zsh 5.9 / git 2.46.0 / curl 8.8.0(早前完成)
- brew 引导链端到端全通:`--version` / `config` / `search` / `info` / `install`(本地 tap ohos/local)/ `list`,chroot 与 docker 容器均验证
- 六处 x86 补丁归档 `v2/patches/`(os.sh + ruby 侧 ld.rb/linkage_checker/ENV super/development_tools),`apply-brew-patches.sh` 幂等应用
- 容器烘焙 `/etc/homebrew/brew.env`:NO_AUTO_UPDATE + NO_INSTALL_FROM_API + OHOS_ALLOW_NO_TOOLCHAIN
- Alpine musl clang15(15.0.7)进 rootfs(SDK clang 是 glibc 的进不来);homebrew-core tap 已克隆(4762 formulae)
- `dockerharmony:x86_64` 镜像重建(687MB,sha 3de3b73d5212),容器内验证通过

**CI 自动构建(2026-10-03 接续完成)**——排障记录见 `docs/HANDOFF-CI.md`:
- GitHub Actions 从源码全自动构建并发布 `ghcr.io/zd200572/openharmony-x86-brew/dockerharmony:x86_64`(+latest)。run5 `37102593171`(commit 500eeac)全绿,digest `sha256:51dda0eff2f270b7c7eeb1c41b5c08849e0a9572077dbc35e6d27eba20ae904d`
- 过程修了 4 个 runner-only 根因(本地全绿掩盖的差距):①SDK 外层 tar 是嵌套 zip,需二次 unzip;②基底 tar 无 /dev 节点,裸 chroot 下 git 启动即死(无 /dev/null),解包后 mknod 补齐;③交叉编译无法运行 regexec 探测,configure 生成的 config.modules 把 zsh/regex 判 link=no 整体跳过(brew 启动 =~ 即死),configure 后 sed 定向改 link=static(与坑#5 同源,脚本已固化);④基底 tar 无 resolv.conf,chroot 内 DNS 全挂,拷宿主机配置修复
- 已知非致命:actions/cache 对 /root/ohos-x86/ohos-sdk 归档报 EACCES(SDK 每次重新下载,约 1 分钟,不挡构建)

**关键技术事实(勿重蹈)**:
- Harmonybrew 的 brew update 是 `git checkout --force -B stable refs/tags/7.0.6_3`——**Library/** 的任何本地修改(含 stable 上的 commit)每次 update/auto-update 都会被抹掉**。所以:补丁必须归档+幂等重放(`apply-brew-patches.sh`),容器默认禁 auto-update;brew update 后必须重跑补丁
- ruby 侧 OHOS 身份由 rbconfig 的 `host_os` 决定(`OS.ohos?` 检查它),交叉编译的 host 三元组只能用 musl 后缀,所以要补 rbconfig 的 target_os
- Harmonybrew 强制 formula 必须在 tap 里,`brew install ./x.rb` 直装被拒
- 服务端 `packages.x86_64_ohos.jws.json` 404(arm64 独享元数据),故容器默认 `HOMEBREW_NO_INSTALL_FROM_API=1`,search/info 走本地 tap

**当前断点(V3 后续,从这里继续)**:
1. **V3 ✅(2026-10-03)**:容器即构建机——ohos-clang(Alpine clang15 + OHOS sysroot)C/C++ 编译链接全通,brew 真实源码构建 zlib 1.3.1 → bottle(x86_64_ohos)→ pour 全绿,docker e2e 全绿。详见 `docs/V3-验证报告.md`
2. **上游回馈**(优先):原六处 x86 泛化 + V3 新增四项(Gemfile.lock 平台白名单 / GNU tar 硬依赖 / forbid_packages_from_paths 对本地 pour / bottle 文件名单横线惯例),附 V2/V3 报告提 PR;同时提 issue 确认 x86_64 路线图
3. **CI/服务端**:harmonybrew ci 仓库加 x86_64 构建矩阵,发布 `packages.x86_64_ohos.jws.json` → 容器可去掉 NO_INSTALL_FROM_API;bottle 批量产出(Tier-1:xz/zstd/patch 等无依赖包)
4. **可选路线 A**:OHOS 用户态 + 通用 Linux 内核的 x86 发行版形态(rootfs 直接装机)
5. **推送镜像到阿里云 ACR**:仍卡 403 账号开通(用户侧),诊断方法见记忆

## 四、踩坑清单(血泪经验,勿重蹈)

### OHOS x86_64 构建类
1. **GN 四类补丁**(归档在 `v1/ohos-patches/`,源码树已应用):camera.gni 与 device.gni 的 defines 导出碰撞(is_emulator 分支)/ asmjit+zydis 缺仓用空 stub BUILD.gn / prebuilt.gni 模板对 x86_64 合成占位 blob / gpu BUILD.gn 补 x86_64 分支。**源码树重建镜像时这些补丁必须在**(origin-bak 备份在各文件旁)。
2. OHOS musl x86_64 **静态** libc 启动即段错误(`-fno-stack-protector` 缺失)——容器路线全动态,不影响。
3. openssl 3.0 装 `lib64`、`lib` 是软链;`find` 不跟链接要 `-L`。curl 的 include/lib 用 `CURL_CFLAGS`/`CURL_LDFLAGS` 传(git 2.46 的 CURLDIR 被删)。
4. git on musl 四件套:`NO_REGEX=NeedsStartEnd`、`-Wl,-z,undefs`(SDK libc stub 缺 pthread_setcancelstate 等符号,运行时真 musl 有)、`CURL_LDFLAGS` 加 `-lpthread`、**不要覆盖 LIBS=**(会杀掉 GITLIBS)。
5. zsh 交叉构建 regex 模块被判 no:改 `config.modules` 里 `zsh/regex link=static` 再 make。
6. GN 需要 `/usr/bin/python`(Ubuntu 22.04 无):`ln -sf /usr/bin/python3 /usr/bin/python`。

### Harmonybrew 适配类
7. install.sh 和 brew 的 `utils/os.sh` 都硬编码 `/lib/ld-musl-aarch64.so.1` + `HOMEBREW_PROCESSOR="arm64"`——都改成 `$(uname -m)`。os.sh 补丁位置:rootfs 内 `/storage/Users/currentUser/.harmonybrew/Homebrew/Library/Homebrew/utils/os.sh`(有 .orig-bak)。
8. brew 前缀固定 `/storage/Users/currentUser/.harmonybrew`,rootfs 里已建 /storage/Users/currentUser。

### 运行时/加载器类
9. musl 动态二进制的库搜索:**实测 ldso 不读 /etc/ld-musl-x86_64.path**(不管换行还是冒号分隔),`LD_LIBRARY_PATH` 生效,默认搜索 /lib:/usr/local/lib:/usr/lib——**所有运行时 .so 直接放 /lib 最稳**。
10. rootfs 的 `/usr` 是真实目录、`usr/bin→../bin`、`usr/lib→../lib` 是其内软链;对 /usr/lib 的 cp 实际落在 /lib。
11. **chroot 测试必须 bind 挂 /dev /proc /sys**,否则 git 取随机数失败("unable to get random bytes")。docker 会自动提供,无需处理。
12. toybox 的 `uname -s` 输出 "Linux"(非 OHOS),Harmonybrew 检测靠 `strings ld-musl-*.so.1 | grep OHOS`(x86_64 loader 同样含 OHOS 字符串,已验证)。

### 本机环境/操作类
13. 用户原 Ubuntu **不许碰**;一切构建在 ohos-build。用户原 Ubuntu vhdx 实际在 C 盘但用户坚称在 D 盘——别纠正,别验证,照做。
14. Docker Desktop 手动代理指向已死的 127.0.0.1:7890 导致容器出网 503/SSL_ERROR_SYSCALL;已改 `proxyHttpMode: system`(%APPDATA%\Docker\settings.json,备份 .bak-20261002)。用户代理是 FlClash,重启后常不自启;诊断容器断网先查这个。
15. Windows Git Bash 调 `wsl.exe`/`docker.exe` 带 POSIX 路径参数**必须 `MSYS2_ARG_CONV_EXCL='*'`**。
16. Windows 侧 python 写 shell 脚本会出 CRLF——同步到 distro 后一律 `sed -i 's/\r$//'`;用 Write/Edit 工具写的文件是 LF 安全的。
17. `pkill -f` 的模式会匹配到自身命令行导致会话自杀——用 `pkill -9 -x <精确名>` 或在 ps 输出里核对。
18. 后台链(setssid nohup)+ 新 wsl 会话有冷启动竞态:launch 后 sleep 再查文件可能误报"没启动";重活建议前台 + 大 timeout,或单链串行。多个后台链并行会互踩(旧 curl 截断新 tarball)——**重跑前先 `ps aux` 清场**。
19. wsl.exe 首次调用可能输出乱码警告(NAT/localhost 提示,UTF-16),`| tr -d '\0'` 解决。
20. /tmp 在 ohos-build 里被 systemd 定期清,重要中间文件别放 /tmp。
21. **`wsl.exe ... bash -c '含 $VAR 的内联命令'` 变量展开不可靠**(var 会被吞成空)——只要涉及变量/逻辑,一律写脚本文件(Write 工具 LF 安全)再 `wsl ... bash /mnt/d/.../x.sh` 执行。本次会话至少两次被它误导(误判 .harmonybrew/bin 内容、误判 rbconfig)。
22. **`cp -aL` 拷 .so 时若目标位置已有同名符号链接会产出断链**(ruby 报 "Error loading shared library libz.so" 即此因)——拷库一律 `find -L $d -maxdepth 1 -name '*.so*' -type f -exec cp -fL --remove-destination {} dst/ \;`,只拷真实文件,并清残留断链(-xtype l)。
23. 后台命令经管道(如 `| tail`)时 exit code 是管道末端的——**判定成败要看日志内容**(本次 ruby 构建实际 configure 失败但报 exit 0)。
24. Alpine `.apk` 就是 gzip tar 可直接解;索引 href 里 `+` 是 `%2B`,且库主版本可能两位(匹配前缀别写成 `libgcc-1.`);alpine 的 clang 实体在 `usr/lib/llvm15/bin`,`usr/bin/clang-15` 只是相对符号链接,拷贝时必须带上 llvm15 目录。
25. **`cp -a src/. dst/` 穿越软链(dst 是 `/usr/bin→../bin` 这类软链)后,若源里有与 toybox 应用小程序同名的真实文件(strings/ar/tar…),GNU cp 会穿透过同名软链直接覆盖 `/bin/toybox` 本体**——全容器 ls/grep/sed 全灭且报错极具迷惑性(usage 头是 argv0,显示 "grep:" 但内容是 strings)。铁律:逐条目 `cp -a --remove-destination`(先删目标软链再放真身),并先验 toybox 完好(`/bin/toybox echo TOYBOX_ALIVE`,裸调用输出的是 applet 列表不可作判据)。stage-v3.sh 已内置自检+从 v1 基底 tar 自愈。
26. **Alpine 的 LLVM 不含 OHOS 工具链分支**(libLLVM 无 ohos 字符串;OHOS SDK clang 是其 fork)。alpine clang 对 `-target x86_64-linux-ohos` 走 generic Linux 默认:glibc loader、crtbeginS、-lgcc 全错。wrapper 必须编译期显式 `-isystem <sysroot>/usr/include/x86_64-linux-ohos`(bits/alltypes.h 所在,driver 不自动加),链接期 `-nostdlib` 自排 Scrt1/crti/crtn + `-lc`/`-lc++` + `-Wl,-dynamic-linker=/lib/ld-musl-x86_64.so.1` + `-no-pie` + `-Wl,-rpath-link,/lib`(GNU ld 解析传递 NEEDED 不认 -L)。
27. **容器内 gem 原生扩展全灭的根因**:rbconfig 烤的是宿主机 SDK 工具链绝对路径。stage-v3.sh 把 rbconfig 的 CC/CXX/AR/RANLIB/NM/STRIP/LD 重定向到容器内 ohos-clang/binutils 后,prism/bigdecimal 等原生 gem 即可编译(Tier-2 gem 生态前提)。
28. **brew bottle 硬依赖 GNU tar**(`--hard-dereference`,toybox tar 无):alpine `tar` 包(b装在 /bin 不是 /usr/bin!)+ 依赖 `acl-libs`。
29. **brew 环境白名单**:`HOMEBREW_INTERNAL_ALLOW_PACKAGES_FROM_PATHS` 会在 brew 入口被洗掉;`HOMEBREW_DEVELOPER=1` 能穿透并翻转 `forbid_packages_from_paths`(默认 true)——本地 bottle pour 需要 DEVELOPER + `brew trust <tap>` 两件套。
30. **Harmonybrew 的 Gemfile.lock PLATFORMS 只有 arm64 系**:容器(x86_64-linux-{ohos,musl})连 bundle install 都拒绝;且冻结模式要求 lock 对声明平台解析完整,需 `bundle lock --add-platform` 正规补齐(幂等标记 `.x86-lock-done`)。
31. **ruby 的 CA 路径**:OHOS SDK openssl 编译期 OPENSSLDIR 容器内不存在,SSL_CERT_FILE 指向 /etc/ssl/certs/cacert.pem;brew 启动的 bundle 子进程不继承该变量,需再写 ~/.gemrc 与 ~/.bundle/config(ssl_ca_cert)双保险。
32. **huaweicloud 的 /zlib/ 路径返回 200 但内容是 HTML 错误页**——下载源码包必须做内容校验(`tar tzf`),不能只看 HTTP 状态码;GitHub release 直链在本机 curl 可用。

## 五、复现/续跑命令速查

```bash
# 进入构建环境
wsl -d ohos-build -u root      # 默认 root,无需密码
# V1 全量重跑(如需):v1/dockerharmony-x86/stageA.sh(下载解压删包)→ stageB.sh(编译→curl→rootfs→tar)
# V2 ruby4.0 重编:/root/ohos-x86/v2/build-ruby40-host-then-cross.sh(host baseruby→/opt/host-ruby + 交叉→ruby40-stage)
# V2 zsh/git(3.4 时代):/root/ohos-x86/v2/build-deps-x86.sh(.done 标记幂等)
# Alpine clang15(重装):/root/ohos-x86/v2/install-alpine-clang.sh(缓存 .apk 在 v2/.deps/alpine-clang15/apk)
# rootfs 组装(幂等总入口,含补丁重放与 brew.env 烘焙):bash /root/ohos-x86/v2/stage-brew.sh
# brew 补丁重放(update 后必跑;含 Gemfile.lock 平台补丁):bash /root/ohos-x86/v2/apply-brew-patches.sh
# V3 容器内编译工具链(幂等:补件+sysroot+wrapper+formula+冒烟):
#   bash /mnt/d/share/interesting/openharmony_x86_brew/v3/stage-v3.sh
# V3 八步全链验证(源码构建→test→bottle→pour):
#   bash /mnt/d/share/interesting/openharmony_x86_brew/v3/verify-v3.sh
# V3 打包与容器 e2e:v3/pack-rootfs-v3.sh → docker import → docker run v3/docker-e2e.sh
# chroot 调试三件套:
mount --bind /dev  /root/ohos-x86/rootfs/dev
mount --bind /proc /root/ohos-x86/rootfs/proc
mount --bind /sys  /root/ohos-x86/rootfs/sys
chroot /root/ohos-x86/rootfs /bin/zsh
# brew 手动调用(chroot 内;容器里 brew.env 已烘焙,免手工 export):
export HOME=/root PATH=/opt/ruby40/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
/storage/Users/currentUser/.harmonybrew/bin/brew --version
# docker 镜像重打:v2/pack-rootfs.sh 出 tar → Windows 侧(Git Bash 必须 MSYS2_ARG_CONV_EXCL='*'):
# docker import --change 'CMD ["/bin/sh"]' D:\share\...\v2\rootfs-v2.tar dockerharmony:x86_64
```

## 六、后续路线(V3+)

1. **V2 收尾**:brew update/--version/本地 formula 安装验证 → 重打 docker 镜像 → V2 报告
2. **上游回馈**:把 x86 适配(install.sh/os.sh 的 `$(uname -m)` 泛化、GN 补丁、bottle 架构标签)以 PR 形式提给 Harmonybrew,避免长期分叉
3. **V3 bottle 生态**:Harmonybrew ci 仓库扩展 x86_64 构建矩阵(容器即构建机)→ Ruby/Python/Node 等引导包 → 分 Tier 重编 homebrew-core
4. **社区协同**:向 Harmonybrew 提 issue 确认 x86_64 路线图,争取共享 CI 资源
5. **可选路线 A**:OHOS 用户态 + 通用 Linux 内核的 x86 发行版形态(rootfs 直接装机)

## 七、关键验证基线(回归时对照)

- chroot/容器内:`ruby 4.0.7 +PRISM [x86_64-linux-musl]`(/bin/ruby→/opt/ruby40;3.4.11 仍在 /opt/ruby34)、`git 2.46.0`、`zsh 5.9`、`curl 8.8.0 + OpenSSL 3.0.9`、`Alpine clang 15.0.7`(target x86_64-alpine-linux-musl)
- brew:`brew --version` → `Homebrew 7.0.6_3-dirty`;`brew list` 含 hello;`brew install ohos/local/hello` 端到端绿
- 容器内:`/storage/Users/currentUser/.harmonybrew/opt/hello/bin/hello.sh` → `Hello from Harmonybrew on x86_64 OHOS!`
- 镜像:`dockerharmony:x86_64` 687MB(2026-10-03,sha 3de3b73d5212);rootfs tar:`v2/rootfs-v2.tar` 675MB
- CI 产物:`ghcr.io/zd200572/openharmony-x86-brew/dockerharmony:{x86_64,latest}`(2026-10-03,digest sha256:51dda0ef…,镜像 633MB,CI 内含 docker run 自检:brew --version + hello.sh)
- 容器内 HTTPS:`curl https://repo.huaweicloud.com/openharmony/` 应返回 7888 字节
- V1 组件集:GN 138,518 targets / ninja 4,687 全绿
- brew 目录:`/storage/Users/currentUser/.harmonybrew/Homebrew`(tag 7.0.6_3,含 harmonybrew/core tap 与 os.sh 等本地补丁)
- **V3(2026-10-03)**:chroot 八步全绿(VERIFY_V3_ALL_DONE,日志 `v3/artifacts/v3-verify.log`);bottle `zlib-1.3.1.x86_64_ohos.bottle.tar.gz` 183KB;docker e2e `DOCKER_E2E_ALL_DONE`;镜像 id `80ec959f457d`(807MB);容器内基线:Alpine clang 15.0.7 + GNU ld 2.44 + GNU tar 1.35 + ohos-clang(wrapper /opt/ohos-clang/bin);zlib formula 在 ohos/local tap(url file:///opt/src-cache/zlib-1.3.1.tar.gz)
