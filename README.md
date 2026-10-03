# OpenHarmony x86_64 + Harmonybrew 移植

把 [Harmonybrew](https://atomgit.com/Harmonybrew)(鸿蒙版 Homebrew,官方仅支持 arm64)生态搬到 **x86_64 版 OpenHarmony**,产出可直接使用的容器镜像 `dockerharmony:x86_64`。

> 当前状态:brew 7.0.6_3 引导链在 x86_64 **端到端全通**(install/search/info/list + 本地 tap 源码安装),CI 自动构建发布到 ghcr.io。

## 使用

```bash
docker run --rm ghcr.io/<owner>/<repo>/dockerharmony:x86_64 \
  /storage/Users/currentUser/.harmonybrew/bin/brew --version
# Homebrew 7.0.6_3-dirty

docker run --rm -it ghcr.io/<owner>/<repo>/dockerharmony:x86_64 /bin/zsh
# 容器内:brew search git / brew install ohos/local/hello ...
```

容器内预置:brew 7.0.6_3、ruby 4.0.7(交叉编译,rbconfig 已适配 OHOS)、zsh 5.9、git 2.46.0、curl 8.8.0、Alpine musl clang 15.0.7、harmonybrew/core tap(4762 formulae)。

## CI 同步构建

`.github/workflows/build-image.yml`:push 触发 → ubuntu-24.04 runner 从零构建(基底 rootfs + OHOS SDK + 交叉编译 + brew 引导 + 端到端验证)→ 发布到 ghcr.io。

- 基底 rootfs 12MB 直接进仓库(`v1/ohos-rootfs-x86_64.tar`)
- 其余全部从源码现场构建,脚本即清单
- 手动触发:Actions 页 `workflow_dispatch`

## 目录结构

```
v1/   V1 阶段:基底 rootfs 构建(GN 补丁、组件编译、curl)
v2/   V2 阶段:ruby4.0/zsh/git 交叉编译、Alpine clang、brew 引导、x86 补丁(全部幂等可重放)
ci/   CI 总构建脚本(全新 ubuntu 可一键跑通)
docs/ V0/V1/V2 验证报告、调研规划
handoff.md  接续文档(环境/踩坑/断点/命令速查)
```

## 关键技术事实(为什么有这些补丁)

1. Harmonybrew 硬编码 aarch64(os.sh、ld.rb 等 6 处)→ `v2/patches/` 归档补丁,`apply-brew-patches.sh` 幂等应用
2. brew update 会 `checkout -f` 发布 tag 抹掉一切本地修改 → 容器烘焙 brew.env 禁 auto-update,补丁可重放
3. brew 要求 ruby major.minor=4.0 → 交叉编译 Ruby 4.0.7,rbconfig target_os 补为 linux-ohos(否则 ruby 侧不认 OHOS)
4. OHOS SDK clang 是 glibc 的,进不了 musl 容器 → 引入 Alpine musl clang15
5. OHOS musl ldso 不读 /etc/ld-musl-*.path → 运行时库一律放 /lib

详见 `docs/V2-验证报告.md` 与 `handoff.md`。
