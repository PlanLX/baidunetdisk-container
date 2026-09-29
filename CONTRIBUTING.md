# Contributing

## Layout

| File | Purpose |
| --- | --- |
| `Dockerfile` | Image build. `ARG CLIENT_VERSION` is the single source of truth for the bundled client version |
| `entrypoint.sh` | Brings up Xvfb → x11vnc → noVNC, generates the VNC password, supervises the client |
| `novnc-serve.py` | Wraps websockify and adds no-cache headers to noVNC assets |
| `bdpaste`, `bdrestore` | In-container helpers: paste text into the client, bring its window back |
| `docker-compose.yml` | Local run configuration |

## Development

```bash
docker compose up -d --build
docker compose logs -f
```

Re-run `docker compose up -d --build` after editing the Dockerfile or `entrypoint.sh`.

## Checks

The same checks CI runs:

```bash
shellcheck entrypoint.sh bdpaste bdrestore
docker run --rm -i hadolint/hadolint:latest < Dockerfile
docker compose config --quiet
```

hadolint ignores a handful of rules on purpose — see `.hadolint.yaml` for the reasoning
behind each one.

## Releasing

`.github/workflows/docker-publish.yml` builds the image and pushes it to Docker Hub and GHCR.

| Trigger | Tags |
| --- | --- |
| Push to `main` | `latest`, `main`, `sha-<short>` |
| Tag `v*.*.*` | Adds `1.0.0` and `1.0` |
| Pull request | Build only, no push |

```bash
git tag v1.0.0
git push origin v1.0.0
```

Two repository secrets are required (Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub [access token](https://hub.docker.com/settings/security), not the account password |

GHCR authenticates with the built-in `GITHUB_TOKEN`, so it needs no extra setup.

## Updating the bundled client

Change `ARG CLIENT_VERSION` in the `Dockerfile` and rebuild. CI reads the version from
there, so the workflow needs no matching edit. To try a one-off version without committing,
run the workflow manually and fill in `client_version`.
