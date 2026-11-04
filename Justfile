set dotenv-load := false

default:
    @just --list

# Local image build from Dockerfile.
build:
    #!/usr/bin/env bash
    set -euo pipefail
    source versions.env
    HORIZON_GIT_REF=nightly
    sha=$(git ls-remote https://github.com/horizon-rust/horizon.git refs/tags/nightly | awk '{print $1}')
    short=${sha:0:7}
    export DOCKER_BUILDKIT=1
    docker build \
      --build-arg "HORIZON_GIT_REF=${HORIZON_GIT_REF}" \
      --build-arg "HORIZON_SOURCE_SHA=${sha}" \
      --build-arg "IMAGE_REVISION=${IMAGE_REVISION}" \
      -t horizon-server:local \
      -t "horizon-server:nightly" \
      -t "horizon-server:nightly-${short}" \
      -t "horizon-server:nightly-${short}-r${IMAGE_REVISION}" \
      .
    echo "Horizon nightly → ${sha}"

# Dev: local build (docker-compose.yml).
run:
    docker compose -f docker-compose.yml --env-file versions.env up --build

# Prod: pull GHCR (game files in ./prepared-26.3/).
up:
    docker compose up -d --pull always

# Import MC 26.3 data into ./prepared-26.3/ (horizon-prepare + JDK 25 + launcher 26.3 once).
# Optional: HORIZON_SERVER_JAR, HORIZON_MINECRAFT_DIR, HORIZON_ROOT (~/.local/share/horizon/current).
prepare:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}"
    command -v horizon-prepare >/dev/null || {
      echo "horizon-prepare missing — install: curl -fsSL https://raw.githubusercontent.com/horizon-rust/horizon/main/packaging/server/install.sh | sh" >&2
      exit 1
    }
    ROOT="${HORIZON_ROOT:-$HOME/.local/share/horizon/current}"
    MC="${HORIZON_MINECRAFT_DIR:-$HOME/.minecraft}"
    JAR="${HORIZON_SERVER_JAR:-$MC/versions/26.3/server.jar}"
    OUT="./prepared-26.3"
    mkdir -p "$OUT"
    horizon-prepare --prepare --server-jar "$JAR" --minecraft-dir "$MC" --root "$ROOT" --output "$OUT"
    echo "prepared → $OUT"

# Optional ~380 MB sounds from your launcher assets.
prepare-sounds:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}"
    command -v horizon-prepare >/dev/null || exit 1
    ROOT="${HORIZON_ROOT:-$HOME/.local/share/horizon/current}"
    MC="${HORIZON_MINECRAFT_DIR:-$HOME/.minecraft}"
    OUT="./prepared-26.3"
    mkdir -p "$OUT"
    horizon-prepare sounds --minecraft-dir "$MC" --root "$ROOT" --output "$OUT"
    echo "sounds → $OUT"

prepare-check:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}"
    ROOT="${HORIZON_ROOT:-$HOME/.local/share/horizon/current}"
    OUT="./prepared-26.3"
    horizon-prepare --check --root "$ROOT" --output "$OUT"

tags:
    #!/usr/bin/env bash
    set -euo pipefail
    source versions.env
    sha=$(git ls-remote https://github.com/horizon-rust/horizon.git refs/tags/nightly | awk '{print $1}')
    short=${sha:0:7}
    repo=ghcr.io/cleboost/horizon-serveur-docker
    echo "${repo}:nightly"
    echo "${repo}:nightly-${short}"
    echo "${repo}:nightly-${short}-r${IMAGE_REVISION}"
