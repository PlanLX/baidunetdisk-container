#!/bin/bash
# 启动 Xvfb -> x11vnc -> noVNC, 并看护百度网盘客户端
set -euo pipefail

SCREEN="${SCREEN:-1024x768x24}"
WEBSOCKET_PORT="${WEBSOCKET_PORT:-6080}"
VNC_PORT="${VNC_PORT:-5900}"
APP_BIN=/opt/baidunetdisk/baidunetdisk
APP_LOG=/var/log/baidunetdisk/app.log
WEBROOT=/opt/novnc-web
# noVNC 文件实际所在的带版本子目录, 例如 /n/1.6.0-3f2a91cc
NOVNC_PATH="$(cat "${WEBROOT}/.novnc-path" 2>/dev/null || echo '')"

log() { echo "[$(date '+%F %T')] $*"; }

# 兼容旧镜像的 vnc_password 变量名
VNC_PASSWORD="${VNC_PASSWORD:-${vnc_password:-}}"
# 随机生成的密码存到挂载卷上, 容器重启后沿用同一把, 原生 VNC 客户端不用重新输
VNC_PASSWORD_FILE="${HOME}/.config/baidunetdisk/.vnc-password"
if [ -z "${VNC_PASSWORD}" ]; then
    if [ -s "${VNC_PASSWORD_FILE}" ]; then
        VNC_PASSWORD="$(<"${VNC_PASSWORD_FILE}")"
        GENERATED_PASSWORD=2
        log "未设置 VNC_PASSWORD, 沿用上次随机生成的密码"
    else
        VNC_PASSWORD="$(head -c 9 /dev/urandom | base64 | tr -d '/+=' | head -c 8)"
        GENERATED_PASSWORD=1
        log "未设置 VNC_PASSWORD, 已随机生成 VNC 密码"
        chmod 700 "${HOME}/.config/baidunetdisk" 2>/dev/null || true
        if printf '%s' "${VNC_PASSWORD}" > "${VNC_PASSWORD_FILE}" 2>/dev/null; then
            chmod 600 "${VNC_PASSWORD_FILE}" 2>/dev/null || true
        fi
    fi
else
    GENERATED_PASSWORD=0
fi

# ---------- 运行环境: XDG 运行时目录 + session dbus ----------
# 没有 XDG_RUNTIME_DIR 和 session dbus 时, GTK/dconf 写不进去,
# 客户端和它的传输服务(netdisk_service)之间也可能协调不正常。
export XDG_RUNTIME_DIR="${HOME}/.runtime"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}" 2>/dev/null || true

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax)"
    log "已启动 session dbus"
fi

# 挂载进来的下载目录 owner 可能不是容器用户, 这里兜底放开权限
chmod 777 "${HOME}/baidunetdiskdownload" 2>/dev/null || true

# ---------- 收尾: 收到停止信号时干净退出 ----------
PIDS=()
cleanup() {
    log "收到停止信号, 正在退出..."
    for pid in "${PIDS[@]:-}"; do
        kill "${pid}" 2>/dev/null || true
    done
    pkill -f "${APP_BIN}" 2>/dev/null || true
    wait 2>/dev/null || true
    exit 0
}
trap cleanup TERM INT

mkdir -p "${HOME}/baidunetdiskdownload" "${HOME}/.config/baidunetdisk" "${HOME}/.vnc"

# ---------- VNC 密码 ----------
x11vnc -storepasswd "${VNC_PASSWORD}" "${HOME}/.vnc/passwd" >/dev/null 2>&1
chmod 600 "${HOME}/.vnc/passwd"

# ---------- 虚拟显示 ----------
log "启动虚拟显示 ${DISPLAY} (${SCREEN})"
Xvfb "${DISPLAY}" -screen 0 "${SCREEN}" -nolisten tcp -ac +extension GLX +render -noreset &
PIDS+=($!)

for _ in $(seq 1 50); do
    [ -e /tmp/.X11-unix/X1 ] && break
    sleep 0.2
done

# 窗口管理器: fluxbox(带底部任务栏)。最小化/缩到托盘的客户端
# 可以从任务栏点回来; 比 matchbox 更适合只有一个主窗口的场景。
# 注意: 不要在 ~/.fluxbox/init 里写 toolbar.visible: false, 否则任务栏消失。
fluxbox >/dev/null 2>&1 &
PIDS+=($!)

# ---------- VNC ----------
# 监听所有网卡是为了 -p 5900:5900 能用原生 VNC 客户端连; 容器内部默认仍建议只走 noVNC
log "启动 x11vnc: ${VNC_PORT} (密码保护)"
x11vnc -display "${DISPLAY}" -rfbauth "${HOME}/.vnc/passwd" -rfbport "${VNC_PORT}" \
       -forever -shared -repeat -noxdamage -nolookup -quiet >/dev/null 2>&1 &
PIDS+=($!)

# ---------- noVNC ----------
# 根路径和 /vnc.html 各放一个跳板页, 跳到带版本号的目录并自动连接
for entry in index.html vnc.html; do
    cat > "${WEBROOT}/${entry}" <<HTML
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>百度网盘</title>
<script>
  // 打开根路径就直接进桌面
  var p = new URLSearchParams(location.search);
  p.set('autoconnect', '1');
  p.set('resize', 'scale');
  p.set('reconnect', '1');
  if (!p.has('password')) p.set('password', ${VNC_PASSWORD@Q});
  location.replace('${NOVNC_PATH}/vnc.html?' + p.toString());
</script>
</head>
<body style="background:#1b1b1b;color:#ccc;font-family:sans-serif">
正在进入桌面... 如果没有自动跳转, 请点击
<a style="color:#6cf" href="${NOVNC_PATH}/vnc.html?autoconnect=1&resize=scale">这里</a>。
</body>
</html>
HTML
done

log "启动 noVNC: http://localhost:${WEBSOCKET_PORT}/"
novnc-serve --web "${WEBROOT}" "${WEBSOCKET_PORT}" "127.0.0.1:${VNC_PORT}" \
    >/var/log/baidunetdisk/websockify.log 2>&1 &
PIDS+=($!)

# ---------- 客户端 ----------
log "启动百度网盘客户端 $(cat /etc/baidunetdisk.version 2>/dev/null || echo '')"
APP_ARGS=(--no-sandbox --disable-dev-shm-usage)
"${APP_BIN}" "${APP_ARGS[@]}" >>"${APP_LOG}" 2>&1 &
APP_PID=$!

cat <<BANNER
============================================================
 百度网盘容器已就绪

 浏览器打开 : http://localhost:${WEBSOCKET_PORT}/
 直达链接   : http://localhost:${WEBSOCKET_PORT}${NOVNC_PATH}/vnc.html?autoconnect=1&resize=scale&password=${VNC_PASSWORD}
 原生 VNC   : vnc://localhost:${VNC_PORT}
 VNC 密码   : ${VNC_PASSWORD}$([ "${GENERATED_PASSWORD}" = 1 ] && echo "  (未指定 VNC_PASSWORD, 已随机生成并保存到挂载卷)")

 下载目录   : /home/baidu/baidunetdiskdownload  (挂载宿主机目录即可)
 登录态     : /home/baidu/.config/baidunetdisk  (挂载后可保持登录)
============================================================
BANNER

# 客户端崩了就拉起来, 保证长时间挂着不挂掉
while true; do
    wait "${APP_PID}" || true
    log "百度网盘客户端退出, 2 秒后重启"
    sleep 2
    "${APP_BIN}" "${APP_ARGS[@]}" >>"${APP_LOG}" 2>&1 &
    APP_PID=$!
done
