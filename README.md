# 容器-百度盘

> 把百度网盘官方 Linux 客户端装进 Docker,在浏览器里直接用。

不用装 VNC 客户端,不用 Wine,不用折腾依赖。一条命令起容器,打开
`http://localhost:6080` 就是一个完整桌面,客户端已经开好在那里了。

[![构建镜像](https://github.com/planlx/baidunetdisk-container/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/planlx/baidunetdisk-container/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/planlx/baidunetdisk-container)](https://hub.docker.com/r/planlx/baidunetdisk-container)
[![镜像大小](https://img.shields.io/docker/image-size/planlx/baidunetdisk-container)](https://hub.docker.com/r/planlx/baidunetdisk-container)
[![许可证](https://img.shields.io/github/license/planlx/baidunetdisk-container)](LICENSE)

## 快速开始

### 方式一:用现成镜像(推荐)

```bash
mkdir -p .data/config .data/downloads
docker compose pull
docker compose up -d
```

打开 **http://localhost:6080** 即可,自动连上并进入桌面。

> `mkdir` 那步别省。目录不存在时 Docker 会用 `root` 建出来,而容器里的客户端
> 以 uid 1000 运行,之后写登录态会没有权限(Linux 上尤其明显)。

不想用 compose 的话,等价的 `docker run`:

```bash
mkdir -p .data/config .data/downloads
docker run -d --name baidupan \
  --platform linux/amd64 \
  -p 6080:6080 \
  -v "$PWD/.data/config:/home/baidu/.config/baidunetdisk" \
  -v "$PWD/.data/downloads:/home/baidu/baidunetdiskdownload" \
  --shm-size=512m \
  --restart unless-stopped \
  planlx/baidunetdisk-container:latest
```

> 客户端只有 amd64 版。上面带 `--platform linux/amd64` 是为了在 Apple Silicon 上
> 走 Rosetta 转译(Docker Desktop 默认已开启),amd64 机器上加了也无害。

### 方式二:从源码构建

```bash
git clone https://github.com/planlx/baidunetdisk-container.git
cd baidunetdisk-container
mkdir -p .data/config .data/downloads
docker compose up -d --build
```

国内构建想快一点,换 APT 镜像站和 noVNC 源:

```bash
docker build --platform linux/amd64 \
  --build-arg APT_MIRROR=mirrors.tuna.tsinghua.edu.cn \
  -t planlx/baidunetdisk-container:latest .
```

### 镜像从哪拉

| 仓库 | 地址 | 说明 |
|---|---|---|
| Docker Hub | `planlx/baidunetdisk-container` | 主仓库 |
| GHCR | `ghcr.io/planlx/baidunetdisk-container` | 备选,国内拉 Docker Hub 不通时用 |

两个仓库内容一致,由 CI 同时推送。用 GHCR 就把 compose 里的 `IMAGE` 换掉:

```bash
# .env
IMAGE=ghcr.io/planlx/baidunetdisk-container:latest
```

## 为什么自建

| | johnshine/baidunetdisk-crossover-vnc | 本镜像 |
|---|---|---|
| 构建时间 | 2022-09 | 跟随官方客户端更新 |
| 客户端版本 | 4.12.5 (2022-08) | **8.7.0 (2026-08)** |
| 底座 | Ubuntu 18.04 (已 EOL) | Debian 12 |
| noVNC | 1.1.0 (2020) | 1.6.0 (上游最新) |
| 镜像体积 | 1.93 GB 磁盘 / 497 MB 内容 | 1.79 GB 磁盘 / 493 MB 内容 |
| 打开方式 | `http://localhost:6080/vnc.html` 手动连 | `http://localhost:6080` 自动进桌面 |
| 登录态 | 每次重建都要重新登录 | 挂载卷后保持 |
| 客户端崩溃 | 不自动拉起 | 自动重启 |
| 5901 端口 | 实际连不上 (VNC 只监听容器内 127.0.0.1) | 5900 可直连,带密码 |

> 镜像名里的 `crossover` 其实是误导:它并没有用 CrossOver/Wine,跑的就是官方 Linux 原生客户端。
>
> 体积说明:客户端本体解压后就占 700 MB 左右,这部分省不掉,所以体积只是小幅下降。
> 自建的主要收益是客户端和组件都是新的、启动更省心,以及下面这些细节。

具体做了什么:

- 官方最新客户端 8.7.0,底座换成还在维护的 Debian 12
- 打开 `http://localhost:6080` 直接进桌面,不用记 `/vnc.html`,密码自动填入
- noVNC 文件放在带版本号的路径下(如 `/n/1.6.0-50661039/`)+ 静态资源 `no-cache`,
  浏览器不会出现"新 `app/ui.js` 配旧 `core/*.js`"的缓存错配
- 加 `--disable-dev-shm-usage`,容器默认 64 MB `/dev/shm` 下渲染进程也不会崩
- 客户端崩了自动拉起,并带 healthcheck
- 登录态(`~/.config/baidunetdisk`)和下载目录都可挂载持久化
- 原生 VNC 端口真的能连(旧镜像的 5901 因为 `-localhost` 实际连不上)
- 用上游 noVNC 1.6.0,而不是 Debian 的 1.3.0(Debian 那个包的 `vnc.html` 与 `ui.js` 不匹配,会直接报错)
- VNC 密码默认随机生成,不用手动设

## 配置项

复制 `.env.example` 成 `.env` 再改:

```bash
cp .env.example .env
```

| 环境变量 | 默认值 | 说明 |
|---|---|---|
| `VNC_PASSWORD` | 未设置时随机生成 | VNC/noVNC 密码,也兼容旧名 `vnc_password` |
| `SCREEN` | `1024x768x24` | 虚拟屏分辨率,宽屏显示器可调 `1920x1080x24` |
| `WEB_PORT` | `6080` | noVNC 网页的宿主机端口 |
| `TZ` | `Asia/Shanghai` | 时区 |
| `IMAGE` | `planlx/baidunetdisk-container:latest` | 用哪个镜像 |
| `WEBSOCKET_PORT` | `6080` | 容器内 noVNC 端口,一般不用改 |
| `VNC_PORT` | `5900` | 容器内原生 VNC 端口,一般不用改 |

## 目录说明

| 容器内路径 | 宿主机路径 | 用途 |
|---|---|---|
| `/home/baidu/.config/baidunetdisk` | `./.data/config` | 登录态/配置,挂载后免重复登录 |
| `/home/baidu/baidunetdiskdownload` | `./.data/downloads` | 下载目录,文件直接落本地 |
| `/var/log/baidunetdisk/app.log` | — | 客户端日志,出问题先看这里 |

`./.data/` 已在 `.gitignore` 和 `.dockerignore` 里排除,不会进仓库也不会进镜像。

## 常见问题

**怎么把链接/文字粘贴进客户端?**

两种办法,第二种最省心。

方法一,用 noVNC 自带的剪贴板面板:点左侧控制栏的剪贴板图标 → 在文本框里粘贴 →
**然后在文本框外面点一下(或按 Tab)让它失焦** → 回到客户端按 Ctrl+V。
最后那步"失焦"是关键:noVNC 1.6.0 绑的是 `change` 事件, 光粘进去不点别处, 内容不会发到远端,
这也就是很多人觉得"VNC 剪切板进不去"的原因。

方法二,直接从宿主机推文字进去(不用碰剪贴板, 最稳):

```bash
# 先在客户端里点一下目标输入框, 再执行:
printf '%s' 'https://pan.baidu.com/s/xxxx' | docker exec -i baidupan bdpaste
```

`bdpaste` 会把文字放进容器内的 X 剪贴板, 并自动给客户端发一次 Ctrl+V。

**VNC 密码在哪看?**

浏览器打开 6080 会自动填入密码,不用管它。要用原生 VNC 客户端的话:

```bash
docker compose logs baidupan | grep 'VNC 密码'
```

不设置 `VNC_PASSWORD` 时入口脚本会随机生成,密码同时保存在
`./.data/config/.vnc-password`(重启容器复用同一把)。需要固定密码,在 `.env` 里写
`VNC_PASSWORD=你的密码` 即可。

**界面变成全黑, 只剩左下角"拖拽至此上传"**

这是点了客户端右上角的关闭(缩到托盘)或者最小化。容器用 fluxbox, 底部有任务栏,
一般直接从任务栏把客户端点回来即可。任务栏也找不到时跑一下就能恢复:

```bash
docker exec baidupan bdrestore
```

**下载失败【1252016】, 进度一直是 0B**

**根因是缺系统库 `libatomic1`。** 客户端的下载内核 `libkernel.so` 依赖
`libatomic.so.1`, 而 Debian slim 底座不带 GCC 运行库。内核加载失败后,
任务一创建就失败, 表现就是"能建目录、文件 0B、状态 1252016"。
(网上说的"改成本地磁盘/关杀毒软件"对本镜像不适用 —— 下载目录本来就在本地盘上。)

镜像里已显式安装 `libatomic1`, 并在构建时校验:

```bash
# 确认依赖完整 (在本机跑, 输出为空即正常)
docker exec baidupan ldd /opt/baidunetdisk/libkernel.so | grep 'not found'
```

如果你是从旧版本镜像升级, 需要 `docker compose up -d --build` 重新构建。
另外旧任务记录的直链已过期, **在客户端里删掉失败任务再重新添加下载**。

批量下载小文件时建议一次少选一些, 传完一批再传下一批。

**打开 6080 报 `does not provide an export named ...` 或 `Cannot read properties of null`**

早期版本把 noVNC 直接放在网站根目录,浏览器会按 URL 长期缓存那些 JS。
镜像升级后,新的 `app/ui.js` 会和缓存里的旧 `core/*.js` 打架,就报这个错。

现在的版本已经不存在这个问题:noVNC 文件放在带版本+哈希的目录里(每次升级换命名空间),
根路径 `/` 只是个跳板页。所以**刷新一下页面就行**。

如果强刷新都还卡着,直接用跳板页给的目标地址(带版本号的路径),它绝对不会命中旧缓存:

```bash
docker logs baidupan | grep 直达链接
# 直达链接 : http://localhost:6080/n/1.6.0-xxxxxxxx/vnc.html?autoconnect=1&resize=scale&password=xxxxxxxx
```

**客户端窗口是灰的,只有背景**

渲染进程崩了,通常是容器 `/dev/shm` 太小。镜像已内置 `--disable-dev-shm-usage` 规避;
若自己改过启动参数,记得加回来,或启动时加 `--shm-size=1g`。

**日志在哪**

```bash
docker exec baidupan cat /var/log/baidunetdisk/app.log        # 客户端日志
docker exec baidupan cat /var/log/baidunetdisk/websockify.log # noVNC 隧道日志
```

## 常用操作

```bash
docker compose logs -f              # 看日志(含 VNC 密码和访问地址)
docker compose restart              # 重启
docker compose down                 # 停止
docker compose pull                 # 拉最新镜像
docker exec -it baidupan bash       # 进容器
docker exec baidupan bdrestore      # 把客户端窗口拉回前台
docker exec baidupan cat /var/log/baidunetdisk/app.log   # 客户端日志
```

## 安全

容器里跑的是一个完整桌面,拿到 VNC 密码就能操作网盘和挂载进去的目录。

- **别把 6080 直接暴露到公网。** 要远程用就套一层带认证的反向代理。
- 只在 `127.0.0.1` 上监听:`.env` 里写 `WEB_PORT=127.0.0.1:6080`。
- 自己设一个密码,别用默认值。
- 详见 [SECURITY.md](SECURITY.md)。

## 开发

```bash
git clone https://github.com/planlx/baidunetdisk-container.git
cd baidunetdisk-container
docker compose up -d --build
docker compose logs -f
```

改了 `entrypoint.sh` / `Dockerfile` 之后 `docker compose up -d --build` 即可生效。

本地想跑一遍 CI 里那套检查:

```bash
shellcheck entrypoint.sh bdpaste bdrestore
docker run --rm -i hadolint/hadolint:latest < Dockerfile
docker compose config --quiet
```

### 发布新版本

CI 在 `.github/workflows/docker-publish.yml`:

- 推到 `main` → 构建并推送 `latest` + `main` + `sha-xxxxxxx`
- 打 `v*.*.*` 标签 → 额外推送语义化版本号
- PR → 只构建,不推送

```bash
git tag v1.0.0
git push origin v1.0.0
```

会在 Docker Hub 和 GHCR 产出 `1.0.0` / `1.0` / `latest` 三个标签。

需要先在仓库里配好两个 Secret(Settings → Secrets and variables → Actions):

| Secret | 内容 |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub 用户名 |
| `DOCKERHUB_TOKEN` | Docker Hub 的 [Access Token](https://hub.docker.com/settings/security)(不是登录密码) |

GHCR 用内置的 `GITHUB_TOKEN`,不用额外配。

### 升级客户端版本

只改一处:`Dockerfile` 里的 `ARG CLIENT_VERSION=8.7.0`。CI 会从那里读版本号,
不用同步改 workflow。想临时试别的版本,手动触发 workflow 时填 `client_version` 即可。

## 关于中文输入

镜像里没装输入法(省 60-80MB)。在 noVNC 里输入中文用**剪贴板粘贴**即可:
先在宿主机复制文字,在 noVNC 侧边栏点剪贴板图标,粘贴,再在容器里 Ctrl+V。

确实需要输入法的话,在 Dockerfile 里加一条:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    fcitx fcitx-googlepinyin fcitx-ui-classic dbus-x11 && rm -rf /var/lib/apt/lists/*
```

并在 entrypoint 里给客户端进程加上 `XMODIFIERS=@im=fcitx GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx`。

## 免责声明

本项目只是把百度网盘**官方** Linux 客户端打包进容器,不分发任何修改版客户端,
也不提供任何破解或加速功能。客户端版权归百度所有,使用请遵守其服务条款。

## 许可证

[MIT](LICENSE)
