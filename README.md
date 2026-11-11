# horizon-serveur-docker

Docker image and Compose setup for a [Horizon](https://github.com/horizon-rust/horizon) dedicated server (Minecraft Java **26.3**). The image contains **Horizon only** — game assets are mounted from your host.

Published on GHCR: `ghcr.io/cleboost/horizon-serveur-docker` (multi-arch **amd64** + **arm64**).

## Quick start

1. **Prepare game files** on the host (once per machine / after updates):

   ```bash
   just prepare
   ```

   Requires [Horizon server install](https://github.com/horizon-rust/horizon/blob/main/docs/hosting.md) (`horizon-prepare`, launcher 26.3, JDK). Output: `./prepared-26.3/`.

2. **Start the server**:

   ```bash
   just up
   # or: docker compose up -d --pull always
   ```

3. Accept the EULA via Compose (`HORIZON_EULA: "true"` in `docker-compose.yml`).

Server data (world, `server.toml`, logs, backups) lives in **`./data`** next to this repo — not in an anonymous Docker volume. On start, the entrypoint (as root) sets ownership of `/data` to the `horizon` user so a fresh host folder does not need manual `chown`.

## Configuration

Environment variables in `docker-compose.yml` are applied on every start via `horizon-server config set`. On first boot, `entrypoint.sh` runs `horizon-server init` with the same settings (see [Horizon hosting docs](https://github.com/horizon-rust/horizon/blob/main/docs/hosting.md)).

| Variable | Effect |
|----------|--------|
| `HORIZON_WHITELIST` | `"false"` → `init --no-whitelist` and `server.whitelist=false` |
| `HORIZON_ONLINE` | `"false"` → `init --offline` and `server.online_mode=false` |
| `HORIZON_WORLD`, `HORIZON_PORT`, `HORIZON_SEED` | World name, port, seed at init |
| `HORIZON_PLAYERS`, `HORIZON_OP` | Comma-separated names for `--player` / `--op` at init |
| `HORIZON_PANEL` | `"true"` to enable the web panel (see logs for login link) |

Extra keys: space-separated `KEY=value` in `HORIZON_CONFIG`.

## Console and commands

The container runs `horizon-server run` in the foreground with a TTY (`stdin_open` + `tty` in Compose), so you can attach after `docker compose up -d`:

```bash
docker attach horizon-server
```

Detach without stopping the server: **Ctrl+P**, **Ctrl+Q**. **Ctrl+C** sends SIGINT and can stop the server.

**Alternative** — Horizon console via exec (detach with Ctrl+D):

```bash
docker exec -it horizon-server horizon-server console
```

**Single command**:

```bash
docker exec horizon-server horizon-server cmd say Hello
docker exec horizon-server horizon-server cmd list
```

Other useful commands (same binary, `--dir /data` is the default workdir):

```bash
docker exec horizon-server horizon-server status
docker exec horizon-server horizon-server logs -f
docker exec horizon-server horizon-server backup
```

Full reference: [hosting.md — Running the server](https://github.com/horizon-rust/horizon/blob/main/docs/hosting.md).

## Local build

```bash
just build    # image horizon-server:local
just run      # local image + docker compose up (no GHCR pull)
```

## Image tags

| Tag | Meaning |
|-----|---------|
| `latest` | Last successful build on `main` (default in `docker-compose.yml`) |
| `nightly` | Same as `latest` today — Horizon channel is `HORIZON_GIT_REF=nightly` in `versions.env` |
| `1.0.0`, … | **Semver of this Docker packaging** — bump `IMAGE_VERSION` in `versions.env` when you change the image; pin prod to this |

Which Horizon engine commit is inside the image: `docker inspect … --format '{{index .Config.Labels "io.horizon.source.sha"}}'`. List published tags with `just tags`.

## Layout

| Path | Role |
|------|------|
| `./prepared-26.3/` | Mojang/Horizon game files (host, read-only mount) |
| `./data/` | Server state (`server.toml`, `world/`, logs) — gitignored except `.gitkeep` |
| `docker-compose.yml` | Pull GHCR image and run (`docker compose up -d`) |
