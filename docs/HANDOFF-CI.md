# HANDOFF-CI:GitHub Actions 构建迭代(已完结)

> ✅ **2026-10-03 完结**:run5 `37102593171`(commit 500eeac)全绿,镜像已发布 `ghcr.io/zd200572/openharmony-x86-brew/dockerharmony:{x86_64,latest}`,digest `sha256:51dda0eff2f270b7c7eeb1c41b5c08849e0a9572077dbc35e6d27eba20ae904d`。最终修复链:e02111f(SDK 嵌套 unzip)→ c783afd(/dev 节点)→ 0206cd1(zsh/regex 静态编入 + clang 裸名链接 + 严格验证)→ 500eeac(resolv.conf)。以下为排障过程记录,归档自仓库根目录。

> 2026-10-03 · 本文档自包含。项目背景看 `handoff.md`(V0-V2 全史)与 `docs/V2-验证报告.md`,本文只讲 CI 这条线。

## 一、目标与现状

**目标**:让 https://github.com/zd200572/openharmony-x86-brew 的 Actions 构建变绿,自动发布镜像到 `ghcr.io/zd200572/openharmony-x86-brew/dockerharmony:x86_64`(+latest)。

**现状(截至本文)**:
- 本地 V2 链路全绿(brew 7.0.6_3 端到端验证过,细节见 V2 报告),CI 是把同一套脚本在 ubuntu-24.04 runner 上复刻
- CI 已跑 2 次,**均失败于 "Build rootfs & image" 步骤**(即 `sudo -E bash ci/build-image.sh`):
  - run1 `37094387201`(commit 853636b):**根因已确认**——SDK 下载本身极快(3.1GB 仅 14s,390MiB/s,华为云对 runner 无障碍),但外层 tar 解出的是 `ohos-sdk/linux/native-*.zip` **嵌套 zip**,脚本没二次解压 → "SDK 就位失败"
  - 修复 commit `e02111f`(已 push):unzip 嵌套包 + 软链 SDK 到 build-curl 期望的 `$V2/.build/ohos-sdk/ohos-sdk` + 下载 ruby-4.0.7.tar.xz + 失败时自动 `ls -la` 诊断
  - run2 `37095610384`(job `111124789487`,commit e02111f):**仍失败,同一表格步骤,日志尚未取到,失败点未知** ← 新 agent 的第一件事

## 二、网络与凭据(本机,Windows Git Bash)

- 代理 `http://127.0.0.1:7890`(FlClash;用户刚重启过软件,**用前先探端口**:`(echo > /dev/tcp/127.0.0.1/7890)`)
- github.com / api.github.com:必须走代理(`export HTTPS_PROXY=http://127.0.0.1:7890`)
- 匿名可查:runs/jobs 列表端点(`api.github.com/repos/zd200572/openharmony-x86-brew/actions/...`)不需要 token
- **要 token 的只有:下载日志**。取 token:
  ```
  TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill | grep ^password= | cut -d= -f2)
  ```
  ⚠️ **2026-10-03 下午实测 credential fill 退出码 43(失效)**——用户重启软件后 GCM 状态变了。处理:让用户在任意终端跑一次 `git ls-remote https://github.com/zd200572/openharmony-x86-brew.git`(会弹浏览器授权)或直接给一个 PAT。**绝不在无人值守时跑 credential fill——GCM 弹窗无人点会卡死整个会话(上一个子代理就是这么死的,先 push 成功、后死在凭据)**
- 本机 curl/git 均可用;有 python(用于解析 JSON)

## 三、拿 run 日志的完整配方(已验证可行)

```bash
cd /d/share/interesting/openharmony_x86_brew
export HTTPS_PROXY=http://127.0.0.1:7890
TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill | grep ^password= | cut -d= -f2)
JOB=$(curl -s -m 30 -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/zd200572/openharmony-x86-brew/actions/runs/<RUN_ID>/jobs" \
  | python -c "import json,sys; print(json.load(sys.stdin)['jobs'][0]['id'])")
LOC=$(curl -s -m 30 -o /dev/null -w "%{redirect_url}" -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/zd200572/openharmony-x86-brew/actions/jobs/$JOB/logs")
# LOC 指向 productionresultssa12.blob.core.windows.net 带签名 URL(签名约10分钟过期,取到立刻下)
# ⚠️ 该 blob 走代理会 000,必须 --noproxy 直连:
curl -s -m 90 --noproxy '*' -o ci-log2.txt "$LOC"
grep -nE "error|FAILED|failed|unzip|cannot|No such" ci-log2.txt | tail -30
```
run1 的日志已在仓库根目录 `ci-log.txt`(勿提交;已列入 .gitignore 待 push)。

## 四、SDK 外层结构(实测,修 SDK 相关问题前先看这个)

`ohos-sdk-windows_linux-public.tar.gz`(3.1GB,URL 已硬编码在 ci/build-image.sh)解开后:
```
ohos-sdk/linux/{ets,js,native,previewer,toolchains}-linux-x64-26.0.0.38-Beta.zip   ← 五个嵌套 zip
ohos-sdk/windows/...                                                                ← 可删
```
CI 只需要 native 一个:解外层 tar → `unzip -q native-*.zip` → 得 `ohos-sdk/linux/native/`(llvm + sysroot)。上游 `v1/dockerharmony-x86/build-curl-x86.sh` 就是这么处理的(可对照)。e02111f 已实现此流程并加了失败时 ls 诊断——**run2 若仍挂在 SDK 段,直接看日志里它打的 ls 输出**。

## 五、可能的后续失败点(按脚本顺序预判,以日志为准)

1. SDK 段(见上)
2. `build-curl-x86.sh`:openssl/zlib/curl 从 gh-proxy.com/ghfast.top 拉——**runner 在美国,gh 代理镜像可能不通**,若卡死改用直连 github release(runner 直连 github 没问题)或 curl.se 官方源
3. `build-deps-x86.sh`:zsh/git,镜像有 tuna/kernel.org 回退,问题不大;git 段曾需手动补跑 make install(脚本已含,验证 git-stage 产物存在)
4. `build-ruby40-host-then-cross.sh`:host baseruby + 交叉,~10 分钟;rbconfig target_os 补丁已内置,失败会打 RBCONFIG PATCH FAILED
5. `stage-brew.sh` / `install-alpine-clang.sh` / `brew-bootstrap.sh`:本地全绿过,主要风险是 alpine CDN / atomgit(brew.tar.gz 121MB)从 runner 的可达性
6. chroot 验证段:`brew tap-new` + hello 安装(本地绿);runner 上 mount --bind 需要 sudo(脚本以 sudo 跑,✓)
7. `docker import` + workflow 的 ghcr push:GITHUB_TOKEN 权限已在 workflow 里配好(packages: write)

## 六、纪律与收尾

- **最多再迭代 3 轮**;每轮:日志证据 → 小修复 → `git diff --stat` 自查 → commit(信息写根因)→ push(自动重触发)→ 轮询(匿名 API 就够,sleep 180~300,单命令别超 9 分钟)
- push 只推必要文件;ci-log*.txt 不进仓库
- 成功后:`docker run --rm ghcr.io/zd200572/openharmony-x86-brew/dockerharmony:x86_64 /bin/sh -c '/storage/Users/currentUser/.harmonybrew/bin/brew --version'` 应输出 `Homebrew 7.0.6_3-dirty`
- 收尾:更新 `handoff.md` 断点段与 memory(ohos-x86-port-project),本文件可删或归档进 docs/
- **勿单独 push 纯文档提交**(workflow paths-ignore 只忽略 docs/** 和 **.md,其他文件会白触发一次必败构建);文档改动随下一次代码修复一起 push

## 七、本地环境备忘

- 工作区即 git 仓库(D:\share\interesting\openharmony_x86_brew,分支 main,远端 origin 已配)
- 全局 git 身份:Dong Zhao <zd200572@gmail.com>
- WSL distro `ohos-build`(root):完整本地构建环境,与 CI 互不依赖;`v2/sync-all-to-distro.sh` 可把工作区脚本同步回 distro
- 本地镜像 `dockerharmony:x86_64`(687MB,sha 3de3b73d5212)是本地构建的可用版本,与 CI 无关
