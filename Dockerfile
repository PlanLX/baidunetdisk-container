# 百度网盘官方 Linux 客户端 + noVNC 自建镜像
#
# 特点:
#   - 官方最新 Linux 客户端 (8.7.0, 2026-08), 非第三方改版
#   - Debian 12 精简底座, 只装真正需要的运行时依赖
#   - 浏览器里直接用: 打开 http://localhost:6080 自动进桌面, 不用记 /vnc.html
#   - 登录态持久化: 挂一个卷到 /home/baidu/.config/baidunetdisk 就不用每次重新登录
#   - 下载目录挂载到宿主机, 文件直接落在本地
#
# 注意: 客户端只有 amd64 版本, Apple Silicon 上会自动走 Rosetta 运行。

FROM --platform=linux/amd64 debian:12-slim

# RUN 里多处用到管道。没有 pipefail 的话, 前半段失败会被后半段的成功盖住,
# 比如 `ldd ... | grep -q 'not found'` 的构建期校验会形同虚设。
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# APT_MIRROR 可换成镜像站, 例如 mirrors.tuna.tsinghua.edu.cn / mirrors.aliyun.com
ARG APT_MIRROR=deb.debian.org
ARG CLIENT_VERSION=8.7.0
ARG CLIENT_URL=https://pkg-ant.baidu.com/issue/netdisk/LinuxGuanjia/${CLIENT_VERSION}/baidunetdisk_${CLIENT_VERSION}_amd64.deb
# 用上游 noVNC: Debian 自带的 1.3.0 打包有问题(vnc.html 与 ui.js 不匹配, 页面会报错)
ARG NOVNC_URL=https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    HOME=/home/baidu \
    USER=baidu \
    DISPLAY=:1 \
    SCREEN=1024x768x24 \
    WEBSOCKET_PORT=6080 \
    VNC_PORT=5900

# OCI 标准标签。Docker Hub / GHCR 的页面、以及各种镜像扫描工具都读这些。
LABEL org.opencontainers.image.title="容器-百度盘" \
      org.opencontainers.image.description="百度网盘官方 Linux 客户端 + noVNC, 浏览器里直接用" \
      org.opencontainers.image.source="https://github.com/planlx/baidunetdisk-container" \
      org.opencontainers.image.url="https://github.com/planlx/baidunetdisk-container" \
      org.opencontainers.image.documentation="https://github.com/planlx/baidunetdisk-container#readme" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${CLIENT_VERSION}"

RUN set -eux; \
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
        sed -i "s|deb.debian.org|${APT_MIRROR}|g" /etc/apt/sources.list.d/debian.sources; \
    else \
        sed -i "s|deb.debian.org|${APT_MIRROR}|g" /etc/apt/sources.list; \
    fi; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl tini locales tzdata \
        xvfb x11vnc python3 python3-websockify \
        xclip xdotool scrot x11-utils x11-xserver-utils \
        dbus-x11 xdg-user-dirs xdg-utils \
        fluxbox \
        fonts-wqy-microhei fonts-dejavu-core \
        desktop-file-utils \
        libatomic1 \
        libgtk-3-0 libgtkmm-2.4-1v5 libnss3 libnspr4 libasound2 libxss1 libxtst6 \
        libatspi2.0-0 libuuid1 libsecret-1-0 libgbm1 libxkbcommon0 libdrm2 \
        libcups2 libpango-1.0-0 libcairo2 libcairo-gobject2 libxcomposite1 \
        libxdamage1 libxfixes3 libxrandr2 libxrender1 libexpat1 libdbus-1-3 \
        libglib2.0-0 libgl1 libx11-xcb1 libxi6 libsm6 libice6 libpci3 procps; \
    echo "${TZ}" > /etc/timezone; \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime; \
    sed -i 's/^# *\(zh_CN.UTF-8\)/\1/; s/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen; \
    locale-gen; \
    rm -rf /var/lib/apt/lists/*

# 安装官方客户端 (apt 会自动补依赖)
# 注意: 必须显式装 libatomic1。客户端的下载内核 libkernel.so 依赖
# libatomic.so.1, 而 debian-slim 不带 GCC 运行库, 缺了它内核加载失败,
# 表现就是所有任务 0B 秒失败并报 1252016。
RUN set -eux; \
    curl -fL --retry 3 --retry-delay 2 -o /tmp/baidunetdisk.deb "${CLIENT_URL}"; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/baidunetdisk.deb libatomic1; \
    rm -f /tmp/baidunetdisk.deb; \
    rm -rf /var/lib/apt/lists/*; \
    rm -f /opt/baidunetdisk/chrome-sandbox; \
    ldd /opt/baidunetdisk/libkernel.so | grep -q 'not found' \
        && { echo 'ERROR: 下载内核 libkernel.so 仍有缺失依赖' >&2; exit 1; } || true; \
    find /opt/baidunetdisk/locales -type f -name '*.pak' ! -name 'zh-CN.pak' ! -name 'en-US.pak' -delete; \
    dpkg-query -W -f='${Version}\n' baidunetdisk > /etc/baidunetdisk.version

RUN set -eux; \
    useradd -u 1000 -U -m -d /home/baidu -s /bin/bash baidu; \
    mkdir -p /home/baidu/baidunetdiskdownload \
             /home/baidu/.config/baidunetdisk \
             /home/baidu/.fluxbox \
             /home/baidu/.vnc \
             /home/baidu/.runtime \
             /var/log/baidunetdisk; \
    touch /var/log/baidunetdisk/app.log; \
    chown -R baidu:baidu /home/baidu /var/log/baidunetdisk; \
    chmod 700 /home/baidu/.vnc /home/baidu/.runtime; \
    chmod 777 /home/baidu/baidunetdiskdownload

# fluxbox 默认配置: 单工作区 + 底部任务栏保持可见。
# 任务栏可见才能把最小化/缩到托盘的客户端点回来;
# 千万不要写 toolbar.visible: false, 否则任务栏消失, 窗口找不回。
RUN set -eux; \
    printf '%s\n' \
      'session.screen0.workspaces: 1' \
      'session.screen0.toolbar.visible: true' \
      'session.screen0.toolbar.placement: BottomCenter' \
      'session.screen0.toolbar.widthPercent: 100' \
      > /home/baidu/.fluxbox/init; \
    chown -R baidu:baidu /home/baidu/.fluxbox

# 让客户端的"默认下载目录"落在挂载点上(而不是家目录)。
# 客户端会读 XDG 用户目录; 不写这个文件它就会退回到 $HOME。
RUN set -eux; \
    printf '%s\n' \
      'XDG_DOWNLOAD_DIR="$HOME/baidunetdiskdownload"' \
      'XDG_DESKTOP_DIR="$HOME"' \
      'XDG_DOCUMENTS_DIR="$HOME"' \
      'XDG_MUSIC_DIR="$HOME"' \
      'XDG_PICTURES_DIR="$HOME"' \
      'XDG_VIDEOS_DIR="$HOME"' \
      'XDG_TEMPLATES_DIR="$HOME"' \
      'XDG_PUBLICSHARE_DIR="$HOME"' \
      > /home/baidu/.config/user-dirs.dirs; \
    chown -R baidu:baidu /home/baidu/.config

# 非 root 跑 Xvfb 需要 /tmp/.X11-unix 已存在且有权限
RUN set -eux; \
    mkdir -p /tmp/.X11-unix; \
    chmod 1777 /tmp/.X11-unix

# noVNC 前端 (上游最新版)。
# 关键: 文件放在带版本+哈希的子目录里(例如 /n/1.6.0-3f2a91cc/)。
# 浏览器会把同 URL 的 JS 缓存很久; 如果文件直接放根目录, 升级镜像后浏览器
# 会拿新的 app/ui.js 配旧的 core/*.js, 报 "does not provide an export named ..."。
# 换命名空间后旧缓存永远不会被命中。
RUN set -eux; \
    curl -fL --retry 3 --retry-delay 2 -o /tmp/novnc.tar.gz "${NOVNC_URL}"; \
    ver="$(basename "${NOVNC_URL}" | sed -E 's/^v?([0-9][0-9.]*)\.tar\.gz$/\1/')"; \
    hash="$(sha256sum /tmp/novnc.tar.gz | cut -c1-8)"; \
    dir="/opt/novnc-web/n/${ver}-${hash}"; \
    mkdir -p "${dir}"; \
    tar -xzf /tmp/novnc.tar.gz -C /tmp; \
    cp -a /tmp/noVNC-*/. "${dir}/"; \
    rm -rf /tmp/novnc.tar.gz /tmp/noVNC-* "${dir}/index.html"; \
    printf '/n/%s-%s' "${ver}" "${hash}" > /opt/novnc-web/.novnc-path; \
    chown -R baidu:baidu /opt/novnc-web

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY novnc-serve.py /usr/local/bin/novnc-serve
COPY bdpaste /usr/local/bin/bdpaste
COPY bdrestore /usr/local/bin/bdrestore
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/novnc-serve \
             /usr/local/bin/bdpaste /usr/local/bin/bdrestore

USER baidu
WORKDIR /home/baidu

# 6080 = noVNC 网页入口 (推荐), 5900 = 原生 VNC 客户端入口
EXPOSE 6080 5900
VOLUME ["/home/baidu/.config/baidunetdisk", "/home/baidu/baidunetdiskdownload"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:6080/" >/dev/null && pgrep -f '[b]aidunetdisk' >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
