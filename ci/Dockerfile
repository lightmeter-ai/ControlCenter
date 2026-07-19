# syntax=docker/dockerfile:1

FROM node:16.20.2-alpine3.18@sha256:a1f9d027912b58a7c75be7716c97cfbc6d3099f3a97ed84aa490be9dee20e787 AS node-toolchain

FROM golang:1.21-alpine3.18@sha256:d390d5f2006c4c9cf19709d449a8463e7188643f444d06fcaa96f45b6c29363d AS toolchain

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    gcc \
    gettext \
    git \
    graphviz \
    libc-dev \
    make \
    python3 \
    ragel \
    rsync

# Keep the legacy Vue build on the same exact Node 16 toolchain as GitHub CI.
COPY --from=node-toolchain /usr/local/bin/node /usr/local/bin/node
COPY --from=node-toolchain /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

FROM toolchain AS source
COPY . /src
WORKDIR /src

FROM source AS test
RUN make mocks && go test ./... -race -count=1

FROM source AS builder
ARG LIGHTMETER_COMMIT
ARG LIGHTMETER_REF
ARG IMAGE_TAG
RUN --mount=type=cache,target=/root/.npm \
    make static_release \
      GIT_COMMIT="$LIGHTMETER_COMMIT" \
      GIT_BRANCH="$LIGHTMETER_REF"

FROM scratch

ARG LIGHTMETER_VERSION
ARG LIGHTMETER_COMMIT
ARG LIGHTMETER_REF
ARG IMAGE_TAG

LABEL org.opencontainers.image.title="Lightmeter Control Center"
LABEL org.opencontainers.image.source="https://github.com/lightmeter-ai/ControlCenter"
LABEL org.opencontainers.image.url="https://lightmeter.io"
LABEL org.opencontainers.image.description="Mail server delivery monitoring"
LABEL org.opencontainers.image.documentation="https://github.com/lightmeter-ai/ControlCenter/blob/${LIGHTMETER_REF}/README.md"
LABEL org.opencontainers.image.vendor="Lightmeter Project"
LABEL org.opencontainers.image.version="${LIGHTMETER_VERSION}"
LABEL org.opencontainers.image.revision="${LIGHTMETER_COMMIT}"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"

COPY --from=builder /src/lightmeter /lightmeter
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

VOLUME ["/logs", "/workspace"]
EXPOSE 8080

ENTRYPOINT ["/lightmeter"]
