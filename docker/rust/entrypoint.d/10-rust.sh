# rust flavor runtime hook: sourced by the base entrypoint as root, before gosu.
# Keep cargo's registry/git/build caches under the host-parity HOME so they
# don't scatter between the image and the host home. Toolchains stay in the
# image (RUSTUP_HOME=/opt/rustup, inherited); only CARGO_HOME moves. The
# cargo/rustc shims remain on PATH via /opt/cargo/bin and /usr/local/bin.
export CARGO_HOME="${HOME}/.cargo"

# A named volume mounted at the cache is created root-owned; chown so cargo
# (running as dev) can write to it. Non-recursive: only the mountpoint blocks.
mkdir -p "${CARGO_HOME}" 2>/dev/null || true
chown dev:dev "${CARGO_HOME}" 2>/dev/null || true
