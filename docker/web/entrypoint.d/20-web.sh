# web flavor runtime hook: sourced by the base entrypoint as root, before gosu.
# Ensure the Playwright browser cache is owned by the (UID-remapped) dev user,
# and start a virtual framebuffer so headless Chrome/Chromium can run without a
# real display. DISPLAY is exported so it is inherited by the gosu exec.
chown -R dev:dev /ms-playwright 2>/dev/null || true

if [ -z "${DISPLAY:-}" ]; then
  export DISPLAY=:99
  Xvfb :99 -screen 0 1280x1024x24 -nolisten tcp &
fi
