# `just` ou `just --list` — recettes pour build/run local

set dotenv-load := false

default:
    @just --list

# Build l'image Docker (long la 1ère fois). Horizon = tag nightly, révision dans versions.env.
build:
    #!/usr/bin/env bash
    set -euo pipefail
    source versions.env
    HORIZON_GIT_REF=nightly
    VERSION_TAG="nightly-r${IMAGE_REVISION}"
    export DOCKER_BUILDKIT=1
    docker build \
      --build-arg "HORIZON_GIT_REF=${HORIZON_GIT_REF}" \
      --build-arg "IMAGE_REVISION=${IMAGE_REVISION}" \
      -t horizon-server:local \
      -t "horizon-server:${VERSION_TAG}" \
      .

# Lance le serveur (.env optionnel pour HORIZON_RESOURCES et co.).
run:
    #!/usr/bin/env bash
    set -euo pipefail
    args=(--env-file versions.env)
    [[ -f .env ]] && args+=(--env-file .env)
    docker compose "${args[@]}" up --build

# Tag GHCR (nightly + révision image)
tags:
    #!/usr/bin/env bash
    set -euo pipefail
    source versions.env
    echo "ghcr.io/cleboost/horizon-serveur-docker:nightly-r${IMAGE_REVISION}"
