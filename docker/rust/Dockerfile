# Claude Contained — rust flavor
# rustup + cargo + stable toolchain. Toolchains live in the image under
# /opt/rustup; cargo's caches are repointed under the host-parity HOME at
# runtime by the entrypoint hook (docker/rust/entrypoint.d/10-rust.sh).
FROM claude-contained-base:latest

ARG RUST_TOOLCHAIN=stable

# Install rustup + toolchain into image-global locations (shared, read-only).
ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
RUN set -eux; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --profile minimal --default-toolchain "${RUST_TOOLCHAIN}"; \
    chmod -R a+rX /opt/rustup /opt/cargo; \
    /opt/cargo/bin/rustc --version

ENV PATH="/opt/cargo/bin:${PATH}"

# Symlink the cargo/rustc shims into /usr/local/bin so they're found even under
# Codex's `bash -lc` PATH reset (same rationale as the java flavor's symlinks).
RUN set -eux; \
    for bin in /opt/cargo/bin/*; do \
      ln -sf "$bin" "/usr/local/bin/$(basename "$bin")"; \
    done

COPY docker/rust/entrypoint.d/10-rust.sh /etc/claude-contained/entrypoint.d/10-rust.sh
