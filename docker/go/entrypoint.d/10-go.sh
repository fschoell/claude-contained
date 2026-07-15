# go flavor runtime hook: sourced by the base entrypoint as root, before gosu.
# Pin the module cache, build cache, and go env config under the (host-parity)
# HOME so they live beside the host's files instead of scattering between
# /home/dev and the host home. Overrides the image's build-time
# GOPATH=/home/dev/go; the exports are inherited by the gosu exec (no `env -i`).
export GOPATH="${HOME}/go"
export GOMODCACHE="${GOPATH}/pkg/mod"
export GOCACHE="${HOME}/.cache/go-build"
export GOENV="${HOME}/.config/go/env"

# Named volumes mounted at these paths are created root-owned, so Go (running as
# dev) cannot write to them until they are chowned. chown is non-recursive on
# purpose: only the mountpoint's ownership blocks writes, and a recursive chown
# of a multi-GB module cache on every launch would be slow. Intermediate dirs
# created here are world-traversable, so dev can still reach the leaf caches.
mkdir -p "${GOMODCACHE}" "${GOCACHE}" "${HOME}/.config/go" 2>/dev/null || true
chown dev:dev \
  "${GOPATH}" "${GOPATH}/pkg" "${GOMODCACHE}" \
  "${HOME}/.cache" "${GOCACHE}" \
  "${HOME}/.config/go" 2>/dev/null || true
