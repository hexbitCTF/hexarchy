# Chromium ships in the base packages, so it never goes through
# hexarchy-install-browser, and fresh installs mark every migration as already
# applied. Without this, the bundled extensions load but have no native
# messaging host to talk to.
hexarchy-install-chromium-copy-url
hexarchy-install-chromium-ytdlp
