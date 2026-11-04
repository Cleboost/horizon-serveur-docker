# syntax=docker/dockerfile:1
# Binaires = tarball officielle horizon-server-linux-x86_64 (Nightly GitHub).
# Pas de compile Rust ici : le serveur tourne avec horizon-engine (= client sans audio/contrôleurs),
# déjà buildé par Horizon ; compiler nous-mêmes retombe sur horizon-client-render, symphonia, etc.
#
# Build local : just build

ARG HORIZON_GIT_REF=nightly
ARG HORIZON_SOURCE_SHA=
ARG IMAGE_REVISION=0

FROM debian:bookworm-slim AS horizon
ARG HORIZON_GIT_REF
ARG HORIZON_SOURCE_SHA
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN set -eu; \
    ASSET=horizon-server-linux-x86_64.tar.gz; \
    JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/horizon-rust/horizon/releases/tags/${HORIZON_GIT_REF}"); \
    FIELDS=$(printf '%s\n' "$JSON" | awk -v asset="$ASSET" ' \
      /"name": / { line=$0; sub(/.*"name": "/, "", line); sub(/".*/, "", line); current=line } \
      current == asset && /"digest": / { line=$0; sub(/.*"digest": "sha256:/, "", line); sub(/".*/, "", line); digest=line } \
      current == asset && /"browser_download_url": / { line=$0; sub(/.*"browser_download_url": "/, "", line); sub(/".*/, "", line); url=line } \
      END { print url; print digest }'); \
    URL=$(printf '%s\n' "$FIELDS" | sed -n '1p'); \
    EXPECT=$(printf '%s\n' "$FIELDS" | sed -n '2p'); \
    [ -n "$URL" ] && [ -n "$EXPECT" ] || { echo "asset $ASSET introuvable sur release ${HORIZON_GIT_REF}" >&2; exit 1; }; \
    curl -fL --progress-bar -o "/tmp/${ASSET}" "$URL"; \
    GOT=$(sha256sum "/tmp/${ASSET}" | awk '{print $1}'); \
    [ "$GOT" = "$EXPECT" ] || { echo "SHA-256 invalide (got $GOT, expected $EXPECT)" >&2; exit 1; }; \
    mkdir -p /tmp/x /out; \
    tar xzf "/tmp/${ASSET}" -C /tmp/x; \
    SRC=$(dirname "$(find /tmp/x -name horizon-server -type f | head -n1)"); \
    [ -n "$SRC" ] || { echo "pas de horizon-server dans l archive" >&2; exit 1; }; \
    cp -a "${SRC}/." /out/; \
    [ -x /out/horizon-server ] && { [ -x /out/horizon-engine ] || [ -x /out/horizon-client ]; } || { echo "binaires serveur incomplets" >&2; exit 1; }; \
    printf 'pin=%s\n' "${HORIZON_SOURCE_SHA:-latest}" > /out/.horizon-source-pin

FROM debian:bookworm-slim
ARG HORIZON_GIT_REF
ARG HORIZON_SOURCE_SHA
ARG IMAGE_REVISION
LABEL org.opencontainers.image.source="https://github.com/Cleboost/horizon-serveur-docker" \
      org.opencontainers.image.title="horizon-server" \
      org.opencontainers.image.description="Horizon dedicated server (no Minecraft assets in image)" \
      io.horizon.git-ref="${HORIZON_GIT_REF}" \
      io.horizon.source.sha="${HORIZON_SOURCE_SHA}" \
      io.horizon.image.revision="${IMAGE_REVISION}"
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --home-dir /data --shell /usr/sbin/nologin horizon \
    && mkdir -p /data /opt/horizon/.local/horizon-client \
    && chown horizon:horizon /data
COPY --from=horizon /out/ /opt/horizon/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH=/opt/horizon:$PATH \
    HORIZON_NO_AUDIO=1
WORKDIR /data
VOLUME /data
EXPOSE 25565 8130
USER horizon
STOPSIGNAL SIGTERM
ENTRYPOINT ["/entrypoint.sh"]
