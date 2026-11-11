# syntax=docker/dockerfile:1
# amd64: official horizon-server-linux-x86_64 tarball.
# arm64: compile at HORIZON_SOURCE_SHA (Horizon ships no Linux ARM server tarball yet).
# Build: --target runtime-amd64 | runtime-arm64 (CI merges both into one manifest).

ARG HORIZON_GIT_REF=nightly
ARG HORIZON_SOURCE_SHA=
ARG HORIZON_VERSION=nightly
ARG IMAGE_VERSION=0.0.0

FROM debian:bookworm-slim AS horizon-fetch
ARG HORIZON_GIT_REF
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN --mount=type=secret,id=github_token,required=false \
    set -eu; \
    GH_TOKEN=""; \
    if [ -f /run/secrets/github_token ]; then GH_TOKEN=$(cat /run/secrets/github_token); fi; \
    ASSET=horizon-server-linux-x86_64.tar.gz; \
    if [ -n "$GH_TOKEN" ]; then \
      JSON=$(curl -fsSL -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/horizon-rust/horizon/releases/tags/${HORIZON_GIT_REF}"); \
    else \
      JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/horizon-rust/horizon/releases/tags/${HORIZON_GIT_REF}"); \
    fi; \
    FIELDS=$(printf '%s\n' "$JSON" | awk -v asset="$ASSET" ' \
      /"name": / { line=$0; sub(/.*"name": "/, "", line); sub(/".*/, "", line); current=line } \
      current == asset && /"digest": / { line=$0; sub(/.*"digest": "sha256:/, "", line); sub(/".*/, "", line); digest=line } \
      current == asset && /"browser_download_url": / { line=$0; sub(/.*"browser_download_url": "/, "", line); sub(/".*/, "", line); url=line } \
      END { print url; print digest }'); \
    URL=$(printf '%s\n' "$FIELDS" | sed -n '1p'); \
    EXPECT=$(printf '%s\n' "$FIELDS" | sed -n '2p'); \
    [ -n "$URL" ] && [ -n "$EXPECT" ] || { echo "missing asset $ASSET on release ${HORIZON_GIT_REF}" >&2; exit 1; }; \
    if [ -n "$GH_TOKEN" ]; then \
      curl -fL -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/octet-stream" --progress-bar -o "/tmp/${ASSET}" "$URL"; \
    else \
      curl -fL --progress-bar -o "/tmp/${ASSET}" "$URL"; \
    fi; \
    GOT=$(sha256sum "/tmp/${ASSET}" | awk '{print $1}'); \
    [ "$GOT" = "$EXPECT" ] || { echo "SHA-256 mismatch (got $GOT, expected $EXPECT)" >&2; exit 1; }; \
    mkdir -p /extract; \
    tar xzf "/tmp/${ASSET}" -C /extract

FROM debian:bookworm-slim AS horizon-amd64
ARG HORIZON_SOURCE_SHA=
COPY --from=horizon-fetch /extract /extract
RUN set -eu; \
    SRC=$(dirname "$(find /extract -name horizon-server -type f | head -n1)"); \
    [ -n "$SRC" ] || { echo "horizon-server not found in archive" >&2; exit 1; }; \
    mkdir -p /out; \
    cp -a "${SRC}/." /out/; \
    [ -x /out/horizon-server ] && { [ -x /out/horizon-engine ] || [ -x /out/horizon-client ]; } \
      || { echo "incomplete server binaries" >&2; exit 1; }; \
    printf 'pin=%s\n' "${HORIZON_SOURCE_SHA:-latest}" > /out/.horizon-source-pin

FROM rust:1-slim-bookworm AS horizon-arm64
ARG HORIZON_SOURCE_SHA
ARG HORIZON_VERSION
ENV HORIZON_VERSION=${HORIZON_VERSION}
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      git ca-certificates pkg-config libssl-dev libasound2-dev libudev-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN set -eu; \
    [ -n "${HORIZON_SOURCE_SHA}" ] || { echo "HORIZON_SOURCE_SHA required for arm64 build" >&2; exit 1; }; \
    git clone --filter=blob:none --no-checkout https://github.com/horizon-rust/horizon.git .; \
    git checkout "${HORIZON_SOURCE_SHA}"
COPY --from=horizon-fetch /extract/horizon-server-linux-x86_64/exporters ./exporters
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/build/target,sharing=locked \
    set -eu; \
    cargo build --release --locked -p horizon-server --bin horizon-server; \
    cargo build --release --locked -p horizon-prepare --bin horizon-prepare; \
    cargo build --release --locked -p horizon-client --no-default-features --bin horizon-client; \
    cargo run --locked -p xtask -- package-server target/release/horizon-client /tmp/pkg; \
    mkdir -p /out; \
    cp -a /tmp/pkg/. /out/; \
    [ -x /out/horizon-server ] && [ -x /out/horizon-engine ] \
      || { echo "incomplete arm64 server bundle" >&2; exit 1; }; \
    printf 'pin=%s\n' "${HORIZON_SOURCE_SHA}" > /out/.horizon-source-pin

FROM debian:bookworm-slim AS runtime-base
ARG HORIZON_GIT_REF
ARG HORIZON_SOURCE_SHA
ARG IMAGE_VERSION
LABEL org.opencontainers.image.source="https://github.com/Cleboost/horizon-serveur-docker" \
      org.opencontainers.image.title="horizon-server" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.description="Horizon dedicated server (no Minecraft assets in image)" \
      io.horizon.git-ref="${HORIZON_GIT_REF}" \
      io.horizon.source.sha="${HORIZON_SOURCE_SHA}"
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates gosu \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --home-dir /data --shell /usr/sbin/nologin horizon \
    && mkdir -p /data /opt/horizon/.local/horizon-client \
    && chown horizon:horizon /data
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH=/opt/horizon:$PATH \
    HORIZON_NO_AUDIO=1
WORKDIR /data
VOLUME /data
EXPOSE 25565 8130
STOPSIGNAL SIGTERM
ENTRYPOINT ["/entrypoint.sh"]

FROM runtime-base AS runtime-amd64
COPY --from=horizon-amd64 /out/ /opt/horizon/

FROM runtime-base AS runtime-arm64
COPY --from=horizon-arm64 /out/ /opt/horizon/

# Local default: amd64 tarball path.
FROM runtime-amd64
