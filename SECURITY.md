# Security

## Reporting a vulnerability

Please don't open a public issue. Use GitHub's
[private vulnerability reporting](https://github.com/planlx/baidunetdisk-container/security/advisories/new),
or email the maintainer directly.

Include reproduction steps, the affected image tag, and what you expected to happen.

## Attack surface

The container runs a **complete desktop**, so treat access to it as access to the account:

| Entry point | Default | Notes |
| --- | --- | --- |
| noVNC `6080` | published | Web UI, password-protected |
| Native VNC `5900` | **not published** | Commented out in `docker-compose.yml`; password-protected when enabled |

Anyone with the VNC password can operate the desktop: use the signed-in Baidu Netdisk
account, and read or write anything in the mounted download directory.

## Deployment hardening

- **Don't expose port 6080 to the public internet.** For remote access, put it behind an
  authenticating reverse proxy (HTTPS + auth, Cloudflare Tunnel, Tailscale, …).
- Bind to localhost only by setting `WEB_PORT=127.0.0.1:6080` in `.env`.
- Set your own password instead of relying on the generated one:
  ```bash
  # .env
  VNC_PASSWORD=<a long random string>
  ```
- Only mount directories you're comfortable exposing to the desktop. Don't mount anything
  sensitive such as `~/.ssh`.
- Keep the image current: `docker compose pull && docker compose up -d`.

## Design notes

- The client runs as the non-root user `baidu` (uid 1000). There is no stronger sandbox
  beyond the container itself; `--no-sandbox` is standard practice for Chromium-based
  clients in containers and is required here.
- The image runs only Xvfb, fluxbox, x11vnc, noVNC and the client. No SSH, no shell
  daemon, no other services are listening.
- The login session under `./.data/config` holds real credentials. It is excluded from
  both git and the Docker build context, but be careful when backing up or sharing the
  project directory.
