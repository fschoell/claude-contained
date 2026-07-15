# Claude Contained — base image
# Carries the AI coding agents + common runtime + entrypoint. Language toolchains
# live in flavor images (docker/<flavor>/Dockerfile) that build FROM this base.
FROM node:24-bookworm-slim

# ---- System packages + custom packages (single apt-get update) -------------
# Use glob trick: docker/base/Dockerfile always exists, custom-packages.txt is
# optional. Build context is the repo root.
COPY docker/base/Dockerfile custom-packages.tx[t] /tmp/
RUN set -eux; \
    # Base packages (lean: no language toolchains, no browser stack)
    BASE_PACKAGES=" \
      git openssh-client ca-certificates ripgrep jq \
      curl bash xz-utils unzip zip tzdata \
      python3 python3-pip python3-venv \
      iproute2 gosu socat bubblewrap"; \
    \
    # Extract custom packages (non-comment, non-empty lines)
    CUSTOM_PACKAGES=""; \
    if [ -f /tmp/custom-packages.txt ]; then \
      CUSTOM_PACKAGES=$(grep -v '^#' /tmp/custom-packages.txt | grep -v '^[[:space:]]*$' | tr '\n' ' ' || true); \
      echo "Custom packages: [$CUSTOM_PACKAGES]"; \
      rm -f /tmp/custom-packages.txt; \
    fi; \
    \
    # Single apt-get update for all packages
    apt-get update && apt-get install -y --no-install-recommends \
      $BASE_PACKAGES \
      $CUSTOM_PACKAGES \
    && rm -rf /var/lib/apt/lists/*

# ---- Install GitHub CLI (gh) ------------------------------------------------
ARG GH_VERSION=2.96.0
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      arm64)  GH_ARCH="arm64" ;; \
      amd64)  GH_ARCH="amd64" ;; \
      *)      echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz"; \
    echo "Downloading: $URL"; \
    curl -fL "$URL" -o /tmp/gh.tar.gz; \
    tar -xzf /tmp/gh.tar.gz -C /tmp; \
    mv "/tmp/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh" /usr/local/bin/gh; \
    rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_${GH_ARCH}"; \
    gh --version

# ---- AI CLIs (npm) ----------------------------------------------------------
# Language servers that are tool-specific (typescript-language-server) live in
# their flavor; pyright is kept here for now as general Python tooling.
ARG AI_TOOLS_CACHE_BUST=stable
RUN set -eux; \
    echo "Refreshing AI tool layers: ${AI_TOOLS_CACHE_BUST}" >/dev/null; \
    npm install -g \
    @github/copilot \
    @google/gemini-cli \
    @openai/codex \
    pyright \
  && npm cache clean --force

# ---- Native Claude Code binary ----------------------------------------------
# Download native binary to /opt/claude/ (runtime creates user symlinks)
ARG CLAUDE_VERSION=latest
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      arm64)  CLAUDE_PLATFORM="linux-arm64" ;; \
      amd64)  CLAUDE_PLATFORM="linux-x64" ;; \
      *)      echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"; \
    if [ "$CLAUDE_VERSION" = "latest" ]; then \
      CLAUDE_VERSION=$(curl -fsSL "$GCS_BUCKET/latest"); \
    fi; \
    mkdir -p /opt/claude; \
    curl -fsSL "$GCS_BUCKET/$CLAUDE_VERSION/$CLAUDE_PLATFORM/claude" -o /opt/claude/claude; \
    chmod +x /opt/claude/claude; \
    /opt/claude/claude --version

# ---- Mistral Vibe (requires Python 3.12+, use uv for version management) ---
ENV UV_TOOL_BIN_DIR=/usr/local/bin
ENV UV_TOOL_DIR=/opt/uv-tools
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
  && /root/.local/bin/uv tool install mistral-vibe --python 3.12 \
  && chmod -R a+rX /opt/uv-tools /opt/uv-python

# ---- Non-root user ----------------------------------------------------------
RUN useradd -m -s /bin/bash dev \
  && mkdir -p /work \
  && chown -R dev:dev /work /home/dev

# ---- Claude Code clipboard workaround --------------------------------------
# Force the classic inline TUI renderer ("tui": "default") inside the container.
# The newer fullscreen ("no-flicker") renderer (default since ~2.1.168) routes
# copy-on-select only through OSC 52 and captures the mouse. Inside a container
# attached to the host terminal there is no clipboard tool (no pbcopy/display),
# OSC 52 is silently dropped by terminals like Terminal.app, and the mouse
# capture also breaks native shift/option-drag selection -- so copying from
# Claude stops working entirely. See anthropics/claude-code#66192.
#
# This is a managed-settings file (highest precedence, Linux path), so it is
# container-scoped and never touches the host-mounted ~/.claude/settings.json.
# Remove this once the upstream renderer regression is fixed.
RUN mkdir -p /etc/claude-code /etc/claude-contained/entrypoint.d \
    && printf '%s\n' '{ "tui": "default" }' > /etc/claude-code/managed-settings.json

# ---- Entrypoint (host.local setup + path parity + flavor hooks) ------------
RUN cat <<'EOF' > /usr/local/bin/entrypoint.sh
#!/bin/bash
set -e

# Claude binary first on PATH; language toolchains add themselves via flavor
# image ENV / /usr/local/bin symlinks (both already on the default PATH).
export PATH="/opt/claude:$PATH"

# Add host.local pointing to host machine
# Docker Desktop (macOS/Windows): use host.docker.internal
# Apple Containers / Docker on Linux: use gateway IP
if getent ahostsv4 host.docker.internal >/dev/null 2>&1; then
  HOST_IP=$(getent ahostsv4 host.docker.internal | head -1 | awk '{print $1}')
else
  HOST_IP=$(ip route | grep default | awk '{print $3}')
fi
if [ -n "$HOST_IP" ]; then
  grep -q "host.local" /etc/hosts 2>/dev/null || echo "$HOST_IP host.local" >> /etc/hosts
fi

# Forward host ports to container localhost (for MCPs that expect localhost)
if [ -n "${HOST_FORWARD_PORTS:-}" ]; then
  IFS=',' read -ra PORTS <<< "$HOST_FORWARD_PORTS"
  for mapping in "${PORTS[@]}"; do
    if [[ "$mapping" == *:* ]]; then
      local_port="${mapping%%:*}"
      host_port="${mapping##*:}"
    else
      local_port="$mapping"
      host_port="$mapping"
    fi
    socat TCP-LISTEN:${local_port},fork,reuseaddr TCP:host.local:${host_port} &
  done
fi

# Path parity setup: match host HOME and UID/GID
if [ -n "${HOST_HOME:-}" ]; then
  mkdir -p "${HOST_HOME}"

  # Match host UID/GID (handle conflicts)
  if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
    EXISTING_GROUP=$(getent group "${HOST_GID}" | cut -d: -f1)
    if [ -n "$EXISTING_GROUP" ] && [ "$EXISTING_GROUP" != "dev" ]; then
      groupmod -g $((HOST_GID + 10000)) "$EXISTING_GROUP" 2>/dev/null || true
    fi

    EXISTING_USER=$(getent passwd "${HOST_UID}" | cut -d: -f1)
    if [ -n "$EXISTING_USER" ] && [ "$EXISTING_USER" != "dev" ]; then
      usermod -u $((HOST_UID + 10000)) "$EXISTING_USER" 2>/dev/null || true
    fi

    groupmod -g "${HOST_GID}" dev 2>/dev/null || true
    usermod -u "${HOST_UID}" -g "${HOST_GID}" -d "${HOST_HOME}" dev 2>/dev/null || true
  fi

  chown dev:dev "${HOST_HOME}" 2>/dev/null || true
  chown -R dev:dev "${HOST_HOME}/.claude" 2>/dev/null || true

  export HOME="${HOST_HOME}"

  # Create container-side symlink to ~/.claude.json in shared directory
  # (Apple Containers can't bind-mount individual files, so we use symlinks)
  SHARED_CLAUDE_JSON="${HOST_HOME}/.claude-contained/.claude.json"
  if [ -e "${SHARED_CLAUDE_JSON}" ] && [ ! -e "${HOST_HOME}/.claude.json" ]; then
    ln -s "${SHARED_CLAUDE_JSON}" "${HOST_HOME}/.claude.json"
    chown -h dev:dev "${HOST_HOME}/.claude.json" 2>/dev/null || true
  fi

  # Copy .gitconfig for git commit identity (read-only, no sync back needed)
  SHARED_GITCONFIG="${HOST_HOME}/.claude-contained/.gitconfig"
  if [ -e "${SHARED_GITCONFIG}" ] && [ ! -e "${HOST_HOME}/.gitconfig" ]; then
    cp "${SHARED_GITCONFIG}" "${HOST_HOME}/.gitconfig"
    chown dev:dev "${HOST_HOME}/.gitconfig" 2>/dev/null || true
  fi

  # Create native Claude symlink structure (satisfies installMethod: native in shared config)
  mkdir -p "${HOST_HOME}/.local/bin" 2>/dev/null || true
  if [ ! -e "${HOST_HOME}/.local/bin/claude" ]; then
    ln -sf /opt/claude/claude "${HOST_HOME}/.local/bin/claude"
  fi
  chown -R dev:dev "${HOST_HOME}/.local" 2>/dev/null || true
fi

# Protect .git/config files from modification (prevents AI tools from changing remote URLs)
# Files are made root-owned and read-only so the dev user cannot modify or chmod them
if [ -n "${GIT_PROTECT_DIRS:-}" ]; then
  IFS=':' read -ra _git_dirs <<< "$GIT_PROTECT_DIRS"
  for _dir in "${_git_dirs[@]}"; do
    _git_config="${_dir}/.git/config"
    # Handle worktrees where .git is a file pointing elsewhere
    if [ -f "${_dir}/.git" ] && ! [ -d "${_dir}/.git" ]; then
      _gitdir=$(sed -n 's/^gitdir: //p' "${_dir}/.git")
      # Resolve relative paths
      case "$_gitdir" in
        /*) ;;
        *) _gitdir="${_dir}/${_gitdir}" ;;
      esac
      _git_config="${_gitdir}/config"
    fi
    if [ -f "$_git_config" ]; then
      chown root:root "$_git_config" 2>/dev/null || true
      chmod 444 "$_git_config" 2>/dev/null || true
    fi
  done
fi

# Flavor runtime hooks: each flavor image may drop scripts into
# /etc/claude-contained/entrypoint.d/ (e.g. Go/Rust cache setup, web Xvfb).
# They run as root with HOME/HOST_HOME set; vars they export are inherited by
# the gosu exec below (which does not use `env -i`).
if [ -d /etc/claude-contained/entrypoint.d ]; then
  for _hook in /etc/claude-contained/entrypoint.d/*.sh; do
    [ -r "$_hook" ] && . "$_hook"
  done
fi

# Drop to dev user (or stay root if STAY_ROOT=1)
if [ "$(id -u)" = "0" ] && [ "${STAY_ROOT:-}" != "1" ]; then
  USER_HOME="${HOME:-/home/dev}"
  exec gosu dev env \
    PATH="${USER_HOME}/.local/bin:$PATH" \
    HOME="$USER_HOME" \
    "$@"
else
  # Also update PATH for root/non-gosu case
  export PATH="${HOME}/.local/bin:$PATH"
  exec "$@"
fi
EOF
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /work
# HOME is set dynamically in entrypoint based on HOST_HOME

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
