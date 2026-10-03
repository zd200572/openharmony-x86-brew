# OpenHarmony x86_64 + Harmonybrew 移植

把 [Harmonybrew](https://atomgit.com/Harmonybrew)(鸿蒙版 Homebrew,官方仅支持 arm64)生态搬到 **x86_64 版 OpenHarmony**,产出可直接使用的容器镜像 `dockerharmony:x86_64`。

> 当前状态(2026-10-03):**V0-V3 全部打通** —— brew 7.0.6_3 引导链端到端全通,且**容器即构建机**:容器内 `ohos-clang`(Alpine clang15 + OHOS sysroot)可编译/链接/运行 C 与 C++,brew 已能从上游源码构建真实软件包并产出 `x86_64_ohos` bottle(样品:zlib 1.3.1)。CI(push 触发)全自动构建并发布到 ghcr.io。

## 使用

```bash
IMG=ghcr.io/zd200572/openharmony-x86-brew/dockerharmony:x86_64

# brew 基础
docker run --rm $IMG /storage/Users/currentUser/.harmonybrew/bin/brew --version
# Homebrew 7.0.6_3-dirty

docker run --rm -it $IMG /bin/zsh
# 容器内:brew search / brew install ohos/local/hello ...
```

### 容器内编译(容器即构建机)

```sh
# ohos-clang = Alpine clang15 + OHOS sysroot 的包装器(C++ 用 ohos-clang++)
cat > hello.c <<'EOF'
#include <stdio.h>
int main(void) { printf("hello OHOS x86_64\n"); return 0; }
EOF
ohos-clang hello.c -o hello && ./hello

# brew 从真实上游源码构建(样例 formula 在本地 tap ohos/local)
brew install --build-bottle ohos/local/zlib
brew test ohos/local/zlib

# 出 bottle / 从 bottle 安装
brew bottle ohos/local/zlib          # zlib-1.3.1.x86_64_ohos.bottle.tar.gz
brew uninstall zlib && brew install /tmp/zlib-1.3.1.x86_64_ohos.bottle.tar.gz
```

容器内预置:brew 7.0.6_3、ruby 4.0.7(rbconfig 已适配 OHOS,gem 原生扩展可在容器内编译)、zsh 5.9、git 2.46.0、curl 8.8.0、harmonybrew/core tap(4762 formulae)、**编译工具链**:Alpine clang 15.0.7 + `ohos-clang`/`ohos-clang++` wrapper、OHOS sysroot(`/opt/ohos-sysroot`)、GNU binutils 2.44、GNU tar 1.35、make。

## CI 同步构建

`.github/workflows/build-image.yml`:push 触发 → ubuntu-24.04 runner 从零构建(基底 rootfs + OHOS SDK + 交叉编译 + brew 引导 + **V3 容器内编译工具链 + 真实源码构建验证** + docker 自检)→ 发布 ghcr.io。

- 基底 rootfs 12MB 直接进仓库(`v1/ohos-rootfs-x86_64.tar`),其余全部现场构建,脚本即清单
- 手动触发:Actions 页 `workflow_dispatch`
- 近期构建:[run7](https://github.com/zd200572/openharmony-x86-brew/actions/runs/37123577719) 全绿(V3 链路完整跑通)

## 目录结构

```
v1/   V1 阶段:基底 rootfs 构建(GN 补丁、组件编译、curl)
v2/   V2 阶段:ruby4.0/zsh/git 交叉编译、Alpine clang、brew 引导、x86 补丁(全部幂等可重放)
v3/   V3 阶段:容器内编译工具链(stage-v3.sh 幂等装配 / verify-v3.sh 八步全链验证
      / ci-verify-v3.sh CI 专用 / docker-e2e.sh / bottle 产物与日志)
ci/   CI 总构建脚本(全新 ubuntu 可一键跑通)
docs/ V0-V3 验证报告、调研规划
handoff.md  接续文档(环境/踩坑/断点/命令速查)
```

## 关键技术事实(为什么有这些补丁)

1. Harmonybrew 硬编码 aarch64(os.sh、ld.rb 等 6 处)→ `v2/patches/` 归档补丁,`apply-brew-patches.sh` 幂等应用
2. brew update 会 `checkout -f` 发布 tag 抹掉一切本地修改 → 容器烘焙 brew.env 禁 auto-update,补丁可重放
3. brew 要求 ruby major.minor=4.0 → 交叉编译 Ruby 4.0.7,rbconfig target_os 补为 linux-ohos(否则 ruby 侧不认 OHOS)
4. OHOS SDK clang 是 glibc 的,进不了 musl 容器 → 引入 Alpine musl clang15
5. **Alpine 的 LLVM 没有 OHOS 工具链分支**(SDK clang 是 OHOS 自研 fork)→ `ohos-clang` wrapper 自管链接:`-nostdlib` 显式排 OHOS crt + musl dynamic-linker + `-no-pie`,编译期显式 `-isystem` multilib 头目录
6. **brew bottle 硬依赖 GNU tar**(`--hard-dereference`),toybox tar 没有 → 补 alpine GNU tar;本地 bottle 安装需 `HOMEBREW_DEVELOPER=1` + `brew trust <tap>`(Harmonybrew 默认禁止从路径装包)
7. **Gemfile.lock 平台白名单只有 arm64 系** → 补 `x86_64-linux-{ohos,musl}` 并 `bundle lock --add-platform`(进 apply-brew-patches.sh)
8. **rbconfig 烤的是宿主机工具链路径** → 容器内重定向到 ohos-clang/binutils 后,gem 原生扩展(prism 等)可直接编译(Tier-2 gem 生态前提)
9. OHOS musl ldso 不读 /etc/ld-musl-*.path → 运行时库一律放 /lib

详见 `docs/V3-验证报告.md` 与 `handoff.md`(踩坑清单 #1-#32)。

## 路线图

- [x] V0 工具链冒烟 / V1 最小 rootfs / V2 brew 引导链 / CI 全自动构建
- [x] V3 容器内真实源码编译 + bottle 闭环(zlib 样品)
- [ ] 上游回馈:六处 x86 泛化 + V3 四项修复提 PR 给 Harmonybrew
- [ ] harmonybrew ci 仓库加 x86_64 构建矩阵,发布 `packages.x86_64_ohos.jws.json`
- [ ] Tier-1 批量 bottle(xz/zstd 等无依赖包 → ruby/python/node 等引导包)
- [ ] 可选:OHOS 用户态 + 通用 Linux 内核的 x86 发行版形态
