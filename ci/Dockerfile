FROM golang:1.21-alpine3.18@sha256:d390d5f2006c4c9cf19709d449a8463e7188643f444d06fcaa96f45b6c29363d AS toolchain

RUN apk add --no-cache \
    ca-certificates \
    curl \
    gcc \
    gettext \
    git \
    graphviz \
    libc-dev \
    make \
    npm \
    python3 \
    ragel \
    rsync

# The pinned Vue/Webpack toolchain predates OpenSSL 3.
ENV NODE_OPTIONS=--openssl-legacy-provider

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
ARG IMAGE_TAG

LABEL org.opencontainers.image.title="Lightmeter Control Center"
LABEL org.opencontainers.image.source="https://github.com/lightmeter-ai/ControlCenter"
LABEL org.opencontainers.image.url="https://lightmeter.io"
LABEL org.opencontainers.image.description="Mail server delivery monitoring"
LABEL org.opencontainers.image.documentation="https://github.com/lightmeter-ai/ControlCenter/blob/release/${IMAGE_TAG}/README.md"
LABEL org.opencontainers.image.vendor="Lightmeter Project"
LABEL org.opencontainers.image.version="${LIGHTMETER_VERSION}"
LABEL org.opencontainers.image.revision="${LIGHTMETER_COMMIT}"
LABEL org.opencontainers.image.licenses="AGPL-3.0-or-later"

COPY --from=builder /src/lightmeter /lightmeter
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

VOLUME ["/logs", "/workspace"]
EXPOSE 8080

ENTRYPOINT ["/lightmeter"]
