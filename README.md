# 容器-百度盘

**The official Baidu Netdisk Linux client, in a container, streamed to your browser.**

[![Build](https://github.com/planlx/baidunetdisk-container/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/planlx/baidunetdisk-container/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/planlx/baidunetdisk-container)](https://hub.docker.com/r/planlx/baidunetdisk-container)
[![Image Size](https://img.shields.io/docker/image-size/planlx/baidunetdisk-container)](https://hub.docker.com/r/planlx/baidunetdisk-container)
[![License](https://img.shields.io/github/license/planlx/baidunetdisk-container)](LICENSE)

Baidu Netdisk ships an official Linux desktop client but nothing headless or web-based.
This image wraps that client in a virtual display (Xvfb + x11vnc + noVNC), so you get the
full desktop in any browser tab — no VNC viewer, no Wine, no dependency wrangling.

## Features

- **Official client** — the vendor's own amd64 build, not a repack
- **Browser-first** — open `http://localhost:6080` and land straight in the desktop; the
  VNC password is filled in for you
- **Persistent** — login session and downloads live in bind mounts, so you can recreate
  the container freely
- **Secure by default** — random VNC password on first start, native VNC port not published
- **Self-healing** — the client is supervised and restarted if it ever exits
- **CI-published** — every release is built and pushed to Docker Hub and GHCR

## Quick Start

```bash
mkdir -p .data/config .data/downloads
docker compose pull
docker compose up -d
```

Then open **http://localhost:6080**.

> Create those directories first. Otherwise Docker creates them as `root`, and the client
> (running as uid 1000) cannot write its login session.

### Without Compose

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

The Linux client is amd64-only. On Apple Silicon, `--platform linux/amd64` runs it through
Rosetta, which Docker Desktop enables by default.

### From Source

```bash
git clone https://github.com/planlx/baidunetdisk-container.git
cd baidunetdisk-container
docker compose up -d --build
```

## Configuration

Copy `.env.example` to `.env` and edit:

| Variable | Default | Description |
| --- | --- | --- |
| `VNC_PASSWORD` | random | VNC / noVNC password. Generated and persisted on first start if unset |
| `SCREEN` | `1024x768x24` | Virtual display resolution; `1920x1080x24` for widescreen |
| `WEB_PORT` | `6080` | Host port for the web UI |
| `TZ` | `Asia/Shanghai` | Container timezone |
| `IMAGE` | `planlx/baidunetdisk-container:latest` | Image to run |

To read the generated password:

```bash
cat .data/config/.vnc-password
```

**Native VNC client?** Uncomment the port mapping in `docker-compose.yml` and connect to
`vnc://localhost:5901` with the password above.

## Data

| Container path | Host path | Contents |
| --- | --- | --- |
| `/home/baidu/.config/baidunetdisk` | `./.data/config` | Login session and client settings |
| `/home/baidu/baidunetdiskdownload` | `./.data/downloads` | Downloaded files |
| `/var/log/baidunetdisk/app.log` | — | Client log |

Both host paths are git-ignored and never enter the image.

## Images

Published identically to both registries:

| Registry | Image |
| --- | --- |
| Docker Hub | `planlx/baidunetdisk-container` |
| GHCR | `ghcr.io/planlx/baidunetdisk-container` |

Tags: `latest`, `main`, `sha-<short>`, plus `1.0.0` / `1.0` for `v*` releases. To switch
registries, set `IMAGE=ghcr.io/planlx/baidunetdisk-container:latest` in `.env`.

## Security

Port 6080 serves a complete desktop. Keep it off the public internet — put it behind an
authenticating reverse proxy, or bind it to localhost with `WEB_PORT=127.0.0.1:6080`.
See [SECURITY.md](SECURITY.md).

## Contributing

Build instructions, lint commands and the release process are in
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)

Not affiliated with or endorsed by Baidu. This project only packages the official client,
which remains Baidu's property and is subject to their terms of service.
