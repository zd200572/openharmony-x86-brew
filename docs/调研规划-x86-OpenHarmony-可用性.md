# 调研规划:让 Harmonybrew 生态在 x86 版 OpenHarmony 上可用

> 调研日期:2026-10-02
> 结论先行:**第一步做 x86 版 DockerHarmony 是正确且必要的第一步**,技术上已被证实可行(而非猜测),但它解决的是"载体"问题;真正的工作量在**x86_64 软件包(bottle)生态的重建**。

---

## 一、调研发现(关键事实)

### 1. Harmonybrew 现状([atomgit.com/Harmonybrew](https://atomgit.com/Harmonybrew))

把 Homebrew 移植到 OpenHarmony 的项目,官网 [harmonybrew.atomgit.com](https://harmonybrew.atomgit.com)。官方支持矩阵:

| 设备形态 | 代表产品 | 最低版本 | 架构 |
|---|---|---|---|
| 鸿蒙 PC | HUAWEI MateBook Pro | HarmonyOS 6.1.0.117 | arm64 |
| 鸿蒙开发板 | dayu200 (rk3568) | OpenHarmony 6.1 | arm64 |
| 鸿蒙容器 | DockerHarmony | OpenHarmony 6.1 | arm64 |

**目前仅支持 arm64**——这正是我们要补的缺口。

组织下 12 个仓库,与本任务直接相关的:

| 仓库 | 作用 | x86 移植含义 |
|---|---|---|
| `brew` | Homebrew/brew 的鸿蒙 fork(Ruby) | 架构无关(Ruby 解释器层面),基本可复用 |
| `homebrew-core` | 从上游搬迁的 formula 仓库 | formula 本身跨架构,但**所有 bottle(预编译包)都是 aarch64**,需整套重编 |
| `ci` | 流水线代码(Python,含 docker) | 需扩展出 x86_64 构建通道 |
| `uname-is-linux` | 伪装 `uname` 输出为 Linux(避开 OHOS 识别问题) | 需出 x86_64 版本 |
| `musl-compat` | musl 兼容层 | 需 x86_64 构建 |
| `formula-migration-tool` | 一键搬运上游 formula | 架构无关,直接复用 |
| `ohos-pip-autosign` | Python 三方库签名 | 仅真机需要,容器阶段不需要 |

安装脚本([install.sh](https://harmonybrew.atomgit.com/install.sh))的关键要求:**Ruby ≥ 3.4、curl ≥ 7.41、git ≥ 2.7、zsh**;arm64 下这些是官方预编译好的,`brew.tar.gz` 直接从服务器下载。x86 侧需要先补齐这组引导依赖。

### 2. DockerHarmony 的真实做法([github.com/hqzing/dockerharmony](https://github.com/hqzing/dockerharmony))

读了它的构建脚本,机制是:**只要用户态,不要内核**。

- 下载 OpenHarmony 7.0-Release 全量源码(压缩包约 71GB,构建机需 ~250GB 磁盘)
- 用 OHOS 自带 LLVM 工具链,以 `--product-name rk3568 --target-cpu arm64` **只编译用户态组件**:
  - musl libc(`musl_install`)、libc++(`libcpp_install`)
  - toybox(基础命令)、mksh(shell)
  - openssl、zlib、libselinux/pcre2、curl
- `build-rootfs.sh` 从 out 目录拼出 rootfs,Dockerfile 只有两行(`FROM scratch; COPY ./rootfs /`)
- 跑在宿主 Linux 内核上(容器内内核就是宿主的),为此打了一个 `disable-hilog.patch` 去掉对 OHOS 内核特性的依赖

**含义:它完全绕开了内核/驱动/图形栈移植,"x86 版" = 把上述构建目标切到 x86_64 工具链重编一遍。**

### 3. x86_64 在 OpenHarmony 工具链里是一等公民(可行性核心证据)

- [build/config/ohos/config.gni](https://gitee.com/openharmony/build/blob/master/config/ohos/config.gni):`current_cpu == "x86_64"` 时 `abi_target = "x86_64-linux-ohos"`——**OHOS 官方构建系统原生支持该三元组**
- [third_party_musl 的 BUILD.gn](https://gitee.com/openharmony/third_party_musl):`musl_arch` 分支显式处理 x86_64
- DevEco 模拟器镜像就是 x86_64 标准系统,Rust([rustc 平台支持](https://doc.rust-lang.org/rustc/platform-support/openharmony.html))、CMake、Zig 等均支持 `x86_64-linux-ohos`
- mini 系统还有现成的 `qemu-x86_64-linux-min` 产品可参考

**结论:工具链、musl、构建系统三层都已具备 x86_64 能力,风险主要在"各组件是否在 x86_64 上被验证过"(模拟器只覆盖了组件子集),预期是个别组件的架构相关代码(内联汇编、JIT 等)需要修补,而不是从零适配。**

---

## 二、对"第一步做 x86 Docker"的判断

**是,应该这么走,理由:**

1. **用最小成本验证最大风险**:x86_64 OHOS 用户态能否在 x86_64 内核上跑起来,是整个项目的技术地基。Docker 容器正是验证它的最短路径,且不用碰任何内核/驱动工作。
2. **与上游同构**:Harmonybrew 官方就把"鸿蒙容器"列为 Tier-1 设备形态,x86 容器天然成为 brew 开发、调试、CI 构建的载体——它不只是验证品,是最终产品的一部分。
3. **为后续真机 OS 铺路**:用户态组件(尤其 brew 及其包生态)在容器里调通后,可整体复用到任何 x86 形态。

**但要纠正两个预期:**

- 不是把 `--platform` 从 arm64 改成 amd64 就完事:dockerharmony 脚本里写死了 `--target-cpu arm64` 和 rk3568 产品,要改成 x86_64 工具链路径,并处理个别组件的编译失败。
- x86 容器跑起来 ≠ 项目成功:Harmonybrew 的全部 bottle 都是 aarch64 的,x86_64 的包生态(bottle 重建 + CI + 托管)才是真正的大头,容器只是让这件事"有地方干"。

---

## 三、分阶段规划

### 阶段 0:x86_64 OHOS 用户态 rootfs(可行性与地基验证)——1~2 周

- 复用 dockerharmony 的三个脚本,`--target-cpu` 切为 x86_64(必要时对个别组件做最小修补),产出 `dockerharmony:x86` 镜像
- 验收标准:`docker run -it --platform linux/amd64` 进去 toybox/mksh/curl/openssl 正常工作,`uname -m` 返回 x86_64
- 资源:一台 Ubuntu 22.04 x86_64 机器,~250GB 磁盘(可先用 `repo`/tarball 裁剪到必需子仓)
- 风险:个别组件(如 musl 的 OHOS 安全增强、selinux)可能有 x86_64 未验证路径 → 预期小修,不影响整体

### 阶段 1:brew 在 x86 容器里跑通(引导链)——2~4 周

按依赖顺序补齐引导链,全部产出 x86_64-linux-ohos 预编译件:

1. Ruby 3.4(brew 的运行时,第一个大件)
2. zsh、git、curl(若 rootfs 里版本不够)
3. `uname-is-linux`、`musl-compat` 的 x86_64 版
4. 跑 Harmonybrew 官方 install.sh(容器形态),验证 brew 能读 formula、解析依赖
5. 手工构建 5~10 个代表性 formula 的 x86_64 bottle(python、node、openssl、gcc/llvm 之一)验证全链路:fetch → build → bottle → install

### 阶段 2:x86_64 包生态规模化(项目主体)——1~3 个月,可持续

- 扩展 Harmonybrew `ci`:构建矩阵加 x86_64(容器本身就是 x86_64 构建机,无需交叉编译),bottle 命名/托管加架构维度
- 用 `formula-migration-tool` 按优先级分批重编:
  - Tier 1(编译器与工具链):llvm/gcc、binutils、make、cmake、pkg-config
  - Tier 2(开发运行时):python、node、rust、go、openjdk
  - Tier 3(常用工具):git、curl、wget、openssh、vim、tmux……
- 建议尽早把 x86_64 构建产线以独立 tap 或上游 PR 的形式回馈 Harmonybrew 社区,避免长期维护私有分叉

### 阶段 3(可选/stretch):真 x86 形态的 OpenHarmony OS

取决于"X86 版本的 OpenHarmony OS 可用"的目标定义,两条路线:

- **路线 A(推荐先走)**:OHOS 用户态 + 通用 Linux 内核的 x86 发行版形态——阶段 0 的 rootfs 直接装进 x86 PC/虚拟机(chroot 或作为 initramfs 根),得到"OpenHarmony 用户态的 x86 系统"。命令行场景即达成"可用",无需碰驱动。
- **路线 B(完整标准系统)**:基于 OHOS `x86_64` 标准系统产品线(模拟器即此形态)做真机适配:UEFI/GRUB 启动、GPU(drm/显卡)、输入、WiFi、Wayland 图形栈。工作量大(内核+HAL+图形),建议以阶段 0-2 的产出为底座、按需立项。

---

## 四、主要风险清单

| # | 风险 | 等级 | 缓解 |
|---|---|---|---|
| 1 | x86_64 下个别用户态组件未经官方验证,编译/运行失败 | 中 | 阶段 0 即暴露;模拟器生态证明工具链可用,预期是小修 |
| 2 | brew formula 上游假设 glibc,OHOS 是 musl | 中 | Harmonybrew 已用 `musl-compat` 解决 arm64 侧同类问题,x86_64 复用同套路 |
| 3 | bottle 生态重建量大,CI 资源不足 | 高 | 分 Tier 推进;容器即构建机,可横向扩容 |
| 4 | Harmonybrew 上游演进与私有 x86 分叉冲突 | 中 | 尽量以 PR/tap 形式回馈上游,减少分叉 |
| 5 | 全量源码下载(71GB,repo.huaweicloud.com)与网络环境 | 低 | 国内网络反而友好;dockerharmony 用 aria2c 分段下载 |

## 五、建议的立即行动(下一步)

1. 准备一台 Ubuntu 22.04 x86_64 构建机(≥250GB 磁盘,可访问 repo.huaweicloud.com)
2. fork dockerharmony,把 `build-components.sh` 的 `--target-cpu arm64` 改为 x86_64,跑通阶段 0,产出首个 `dockerharmony:x86` 镜像
3. 同步向 Harmonybrew 社区(integration/issue)确认 x86_64 是否已在他们路线图上,避免重复建设并争取 CI 资源
