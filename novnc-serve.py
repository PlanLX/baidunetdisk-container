#!/usr/bin/env python3
"""启动 websockify, 并给 noVNC 静态文件加上 no-cache 头。

浏览器会对没有 Cache-Control 的静态文件做启发式缓存。镜像升级换了新版 noVNC 后,
浏览器可能仍用旧的 app/ui.js 配新的 vnc.html, 于是报
"does not provide an export named ..." 之类的诡异错误。
这里统一让静态资源不缓存, 避免这种版本错配。
"""
import sys


def patch_cache_headers():
    """给所有响应加上 no-cache 头。失败也不要影响启动。"""
    try:
        import websockify.websockifyserver as wss
    except Exception as exc:  # pragma: no cover
        print(f"warn: noVNC 静态文件未加 no-cache 头: {exc}", file=sys.stderr)
        return

    # 不同 websockify 版本里类名不一样
    handler = getattr(wss, "WebSocketRequestHandler", None) \
        or getattr(wss, "WebSockifyRequestHandler", None)
    if handler is None:
        return

    original_end_headers = handler.end_headers

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        original_end_headers(self)

    handler.end_headers = end_headers


patch_cache_headers()

# 入口点在不同版本里位置不同
try:
    from websockify.websockify import websockify_init
except ImportError:
    from websockify.websocketproxy import websockify_init

sys.exit(websockify_init())
