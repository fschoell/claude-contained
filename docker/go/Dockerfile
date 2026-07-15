# Claude Contained — go flavor
# Go toolchain + a C toolchain (for cgo) + common Go dev tools (golangci-lint,
# gopls, delve). The module/build caches are repointed under the host-parity
# HOME at runtime by the entrypoint hook (docker/go/entrypoint.d/10-go.sh).
FROM claude-contained-base:latest

# ---- C toolchain for cgo ----------------------------------------------------
# cgo needs a C compiler + libc headers; pkg-config + make cover most C deps
# and typical project Makefiles.
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
      build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

# ---- Go toolchain -----------------------------------------------------------
ARG GO_VERSION=1.26.4
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      arm64)  GO_ARCH="arm64" ;; \
      amd64)  GO_ARCH="amd64" ;; \
      *)      echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" \
    | tar -C /usr/local -xz; \
    /usr/local/go/bin/go version

ENV PATH="/usr/local/go/bin:${PATH}"
# Build-time default only. The entrypoint hook repoints GOPATH/GOCACHE/GOENV
# under the host-parity HOME at runtime (see entrypoint.d/10-go.sh).
ENV GOPATH=/home/dev/go
ENV GOTOOLCHAIN=auto

# ---- golangci-lint (pinned binary from GitHub releases) ---------------------
ARG GOLANGCI_LINT_VERSION=2.12.2
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      arm64)  GL_ARCH="arm64" ;; \
      amd64)  GL_ARCH="amd64" ;; \
      *)      echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    DIR="golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${GL_ARCH}"; \
    URL="https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/${DIR}.tar.gz"; \
    echo "Downloading: $URL"; \
    curl -fL "$URL" -o /tmp/golangci-lint.tar.gz; \
    tar -xzf /tmp/golangci-lint.tar.gz -C /tmp; \
    mv "/tmp/${DIR}/golangci-lint" /usr/local/bin/golangci-lint; \
    rm -rf /tmp/golangci-lint.tar.gz "/tmp/${DIR}"; \
    golangci-lint --version

# ---- Go dev tools (LSP + debugger) ------------------------------------------
# Install into /usr/local/bin (always on PATH) via GOBIN, so they survive the
# runtime GOPATH repoint. Then drop the build-time caches, which live at
# /home/dev/go and /root and are never used at runtime.
RUN set -eux; \
    GOBIN=/usr/local/bin go install golang.org/x/tools/gopls@latest; \
    GOBIN=/usr/local/bin go install github.com/go-delve/delve/cmd/dlv@latest; \
    go clean -cache -modcache; \
    rm -rf /root/.cache/go-build

COPY docker/go/entrypoint.d/10-go.sh /etc/claude-contained/entrypoint.d/10-go.sh
