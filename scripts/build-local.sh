#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$root/versions.env"

ref_slug=$(printf '%s' "$HORIZON_GIT_REF" | tr '/:' '_')
export VERSION_TAG="${ref_slug}-r${IMAGE_REVISION}"

export DOCKER_BUILDKIT=1

case "${1:-build}" in
  build)
    docker build \
      --build-arg "HORIZON_GIT_REF=${HORIZON_GIT_REF}" \
      --build-arg "IMAGE_REVISION=${IMAGE_REVISION}" \
      -t "horizon-server:local" \
      -t "horizon-server:${VERSION_TAG}" \
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
