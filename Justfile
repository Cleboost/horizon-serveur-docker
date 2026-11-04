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

# Dev: build via docker-compose.yml.
run:
    #!/usr/bin/env bash
    set -euo pipefail
    args=(--env-file versions.env)
    [[ -f .env ]] && args+=(--env-file .env)
    docker compose "${args[@]}" up --build

# Prod: pull GHCR via compose.yaml.
up:
    #!/usr/bin/env bash
    set -euo pipefail
    args=(-f compose.yaml)
    [[ -f .env ]] && args+=(--env-file .env)
    docker compose "${args[@]}" up -d --pull always

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
