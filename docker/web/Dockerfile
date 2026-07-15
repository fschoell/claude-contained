# Claude Contained — web flavor
# Browser automation (Playwright/Chromium + Xvfb), Bun, and the TypeScript
# language server. Chromium runs headless under a virtual framebuffer started
# by the entrypoint hook (docker/web/entrypoint.d/20-web.sh).
FROM claude-contained-base:latest

# ---- Chromium runtime libraries + virtual framebuffer -----------------------
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
      libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 \
      libcups2 libdbus-1-3 libdrm2 libgbm1 libgtk-3-0 \
      libnspr4 libnss3 libpango-1.0-0 libxcomposite1 libxdamage1 \
      libxfixes3 libxkbcommon0 libxrandr2 libxtst6 xvfb \
    && rm -rf /var/lib/apt/lists/*

# ---- Install Bun ------------------------------------------------------------
ARG BUN_VERSION=latest
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      arm64)  BUN_ARCH="aarch64" ;; \
      amd64)  BUN_ARCH="x64" ;; \
      *)      echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    if [ "$BUN_VERSION" = "latest" ]; then \
      BUN_VERSION=$(curl -fsSL https://api.github.com/repos/oven-sh/bun/releases/latest | grep -oP '"tag_name": "bun-v\K[^"]+'); \
    fi; \
    echo "Installing Bun v${BUN_VERSION}"; \
    URL="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${BUN_ARCH}.zip"; \
    curl -fL "$URL" -o /tmp/bun.zip; \
    unzip -q /tmp/bun.zip -d /tmp; \
    mv /tmp/bun-linux-${BUN_ARCH}/bun /usr/local/bin/bun; \
    chmod +x /usr/local/bin/bun; \
    rm -rf /tmp/bun.zip /tmp/bun-linux-${BUN_ARCH}; \
    bun --version

# ---- TypeScript language server ---------------------------------------------
RUN npm install -g typescript typescript-language-server \
  && npm cache clean --force

# ---- Playwright browser (build-time install for reliability) ----------------
# Install Chromium to a fixed location instead of user cache for container use
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npx playwright@1.61.0 install --with-deps chromium chromium-headless-shell \
  && chown -R dev:dev /ms-playwright

# ---- Chrome wrapper for Playwright MCP compatibility ------------------------
# When projects use @playwright/mcp without --browser flag, it looks for Chrome.
# This wrapper redirects to our installed Playwright Chromium.
RUN mkdir -p /opt/google/chrome && cat <<'EOF' > /opt/google/chrome/chrome
#!/bin/bash
exec /ms-playwright/chromium-*/chrome-linux/chrome --no-sandbox "$@"
EOF
RUN chmod +x /opt/google/chrome/chrome

# ---- Runtime hook: Xvfb + playwright cache ownership ------------------------
COPY docker/web/entrypoint.d/20-web.sh /etc/claude-contained/entrypoint.d/20-web.sh
