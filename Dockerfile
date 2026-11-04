# syntax=docker/dockerfile:1
# Image horizon-server — build depuis https://github.com/horizon-rust/horizon
# (même logique que packaging/server/Dockerfile upstream, sans copier tout le monorepo ici).
#
# Build local : just build
# Pas de fichiers Minecraft dans l'image : monter le dossier 26.3 préparé (horizon-prepare).

ARG HORIZON_GIT_REF=nightly
ARG HORIZON_SOURCE_SHA=
ARG IMAGE_REVISION=0

FROM rust:1-slim-bookworm AS build
ARG HORIZON_GIT_REF
ARG HORIZON_SOURCE_SHA
WORKDIR /src
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*
# SHA en CI : layer invalidée seulement quand le tag nightly bouge (sinon recompile inutile).
RUN git clone --depth 1 https://github.com/horizon-rust/horizon.git . \
    && if [ -n "${HORIZON_SOURCE_SHA}" ]; then \
         git fetch --depth 1 origin "${HORIZON_SOURCE_SHA}" && git checkout FETCH_HEAD; \
       else \
         git fetch --depth 1 origin "${HORIZON_GIT_REF}" && git checkout FETCH_HEAD; \
       fi
RUN --mount=type=cache,target=/usr/local/cargo/registry,id=horizon-cargo-registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,id=horizon-cargo-git,sharing=locked \
    --mount=type=cache,target=/src/target,id=horizon-target,sharing=locked \
    cargo build --release --locked -p horizon-client --no-default-features --bin horizon-client \
    && cargo build --release --locked -p horizon-server --bin horizon-server \
    && mkdir /out \
    && cp target/release/horizon-client /out/horizon-engine \
    && cp target/release/horizon-server /out/

FROM debian:bookworm-slim
ARG HORIZON_GIT_REF
ARG IMAGE_REVISION
LABEL org.opencontainers.image.source="https://github.com/Cleboost/horizon-serveur-docker" \
      org.opencontainers.image.title="horizon-server" \
      org.opencontainers.image.description="Horizon dedicated server (no Minecraft assets in image)" \
      io.horizon.git-ref="${HORIZON_GIT_REF}" \
      io.horizon.image.revision="${IMAGE_REVISION}" \
      io.horizon.version="${HORIZON_GIT_REF}-r${IMAGE_REVISION}"
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --home-dir /data --shell /usr/sbin/nologin horizon \
    && mkdir -p /data /opt/horizon/.local/horizon-client \
    && chown horizon:horizon /data
COPY --from=build /out/ /opt/horizon/
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
