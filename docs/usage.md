# 使用说明

> 面向使用者的中文说明。项目概览和英文快速入门见根目录 [README](../README.md)。

## 快速开始

```bash
mkdir -p .data/config .data/downloads
docker compose up -d        # 或改用现成镜像: docker compose pull && docker compose up -d
```

打开 **http://localhost:6080** 自动进入桌面, 密码自动填, 不用管它。

## 常用操作

```bash
docker compose logs -f              # 看日志(含 VNC 密码和访问地址)
docker compose restart              # 重启
docker compose down                 # 停止
docker compose pull                 # 拉最新镜像
docker compose up -d --build        # 改了 Dockerfile / entrypoint 后重新构建
docker exec -it baidupan bash       # 进容器
docker exec baidupan bdrestore      # 把客户端窗口拉回前台(黑屏时)
```

## 登录与持久化

- **登录态** 存在 `./.data/config`, 挂载到容器 `/home/baidu/.config/baidunetdisk`,
  重建容器不用重新扫码登录。
- **下载目录** 是 `./.data/downloads`, 文件直接落在宿主机本地。
- `./.data/` 已被 git 和 docker 忽略, 不会进仓库也不会进镜像。

## 把链接 / 文字粘贴进客户端

两种办法, 第二种最省心。

**方法一**, 用 noVNC 自带的剪贴板面板: 点左侧控制栏的剪贴板图标 → 在文本框里粘贴 →
**然后在文本框外面点一下(或按 Tab)让它失焦** → 回到客户端按 Ctrl+V。
最后那步"失焦"是关键: noVNC 1.6.0 绑的是 `change` 事件, 光粘进去不点别处,
内容不会发到远端。

**方法二**, 直接从宿主机推文字进去(不用碰剪贴板, 最稳):

```bash
# 先在客户端里点一下目标输入框, 再执行:
printf '%s' 'https://pan.baidu.com/s/xxxx' | docker exec -i baidupan bdpaste
```

`bdpaste` 会把文字放进容器内的 X 剪贴板, 并自动给客户端发一次 Ctrl+V。

## VNC 密码

浏览器打开 6080 会自动填入密码, 不用管它。要用原生 VNC 客户端的话:

- 密码文件: `cat .data/config/.vnc-password`
- `VNC_PASSWORD` 未设置时随机生成, 并保存到上面这个文件, 重启容器沿用。

需要固定密码, 在 `.env` 里写 `VNC_PASSWORD=你的密码`。

## 常见问题

### 界面变成全黑, 只剩左下角"拖拽至此上传"

这是点了客户端右上角的关闭(缩到托盘)或者最小化。容器用 fluxbox, 底部有任务栏,
一般直接从任务栏把客户端点回来即可。任务栏也找不到时:

```bash
docker exec baidupan bdrestore
```

### 下载失败【1252016】, 进度一直是 0B

根因是缺系统库 `libatomic1`。客户端的下载内核 `libkernel.so` 依赖 `libatomic.so.1`,
而 Debian slim 底座不带 GCC 运行库。镜像里已显式安装 `libatomic1`, 并在构建时校验:

```bash
# 确认依赖完整 (在本机跑, 输出为空即正常)
docker exec baidupan ldd /opt/baidunetdisk/libkernel.so | grep 'not found'
```

如果你是从旧版本镜像升级, 需要 `docker compose up -d --build` 重新构建。
另外旧任务记录的直链已过期, **在客户端里删掉失败任务再重新添加下载**。

批量下载小文件时建议一次少选一些, 传完一批再传下一批。

### 打开 6080 报 `does not provide an export named ...`

浏览器缓存了旧版 noVNC 的 JS。本镜像的静态文件放在带版本+哈希的目录里(每次升级换
命名空间), 根路径 `/` 只是个跳板页, 理论上不会出现;**强刷一次(Ctrl+Shift+R)即可**。

### 客户端窗口是灰的, 只有背景

渲染进程崩了, 通常是容器 `/dev/shm` 太小。镜像已内置 `--disable-dev-shm-usage` 规避;
若自己改过启动参数, 记得加回来, 或启动时加 `--shm-size=1g`。

### 日志在哪

```bash
docker exec baidupan cat /var/log/baidunetdisk/app.log        # 客户端日志
docker exec baidupan cat /var/log/baidunetdisk/websockify.log # noVNC 隧道日志
```

## 中文输入

镜像里没装输入法(省 60-80MB)。在 noVNC 里输入中文用**剪贴板粘贴**即可:
先在宿主机复制文字, 在 noVNC 侧边栏点剪贴板图标, 粘贴, 再在容器里 Ctrl+V。

确实需要输入法: 在 Dockerfile 里安装 `fcitx fcitx-googlepinyin fcitx-ui-classic dbus-x11`,
并在 entrypoint 里给客户端进程加上 `XMODIFIERS=@im=fcitx GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx`。

## 安全提示

容器里跑的是一个完整桌面, 拿到 VNC 密码就能操作网盘和挂载进去的目录。
远程使用请套一层带认证的反向代理, 别把 6080 直接暴露公网。详见 [SECURITY](../SECURITY.md)。