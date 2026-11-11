#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$root/versions.env"

export DOCKER_BUILDKIT=1

case "${1:-build}" in
  build)
    docker build \
      --build-arg "HORIZON_GIT_REF=${HORIZON_GIT_REF}" \
      --build-arg "IMAGE_VERSION=${IMAGE_VERSION}" \
      -t "horizon-server:local" \
      -t "horizon-server:${IMAGE_VERSION}" \
      "$root"
    ;;
  compose)
    docker compose --env-file "$root/versions.env" "${@:2}"
    ;;
  *)
    echo "Usage: $0 build | compose [docker compose args...]" >&2
    exit 1
    ;;
esac
