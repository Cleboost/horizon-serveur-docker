# horizon-serveur-docker

Docker image and Compose setup for a [Horizon](https://github.com/horizon-rust/horizon) dedicated server (Minecraft Java **26.3**). The image contains **Horizon only** — game assets are mounted from your host.

Published on GHCR: `ghcr.io/cleboost/horizon-serveur-docker:nightly` (multi-arch **amd64** + **arm64**).

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

3. Accept the EULA via Compose (`HORIZON_EULA: "true"` in `compose.yaml`).

Server data (world, `server.toml`, logs, backups) lives in **`./data`** next to this repo — not in an anonymous Docker volume.

## Configuration

Environment variables in `compose.yaml` are applied on every start via `horizon-server config set`. On first boot, `entrypoint.sh` runs `horizon-server init` with the same settings (see [Horizon hosting docs](https://github.com/horizon-rust/horizon/blob/main/docs/hosting.md)).

| Variable | Effect |
|----------|--------|
| `HORIZON_WHITELIST` | `"false"` → `init --no-whitelist` and `server.whitelist=false` |
| `HORIZON_ONLINE` | `"false"` → `init --offline` and `server.online_mode=false` |
| `HORIZON_WORLD`, `HORIZON_PORT`, `HORIZON_SEED` | World name, port, seed at init |
| `HORIZON_PLAYERS`, `HORIZON_OP` | Comma-separated names for `--player` / `--op` at init |
| `HORIZON_PANEL` | `"true"` to enable the web panel (see logs for login link) |

Extra keys: space-separated `KEY=value` in `HORIZON_CONFIG`.

## Console and commands

The container runs `horizon-server run` in the background (`docker compose up -d`). **Do not use `docker attach` for the game console** — stdin is not wired for interactive commands, and **Ctrl+C can stop the server**.

Use Horizon’s CLI inside the running container:

**Interactive console** (logs, TPS, command line — detach with Ctrl+D):

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
just run      # docker-compose.yml with local build
```

CI builds and pushes tags listed in `just tags` (`nightly`, `nightly-<sha7>`, `nightly-<sha7>-r<N>` from `versions.env`).

## Layout

| Path | Role |
|------|------|
| `./prepared-26.3/` | Mojang/Horizon game files (host, read-only mount) |
| `./data/` | Server state (world, config, logs) — gitignored except `.gitkeep` |
| `compose.yaml` | Production: pull from GHCR |
| `docker-compose.yml` | Local build |
