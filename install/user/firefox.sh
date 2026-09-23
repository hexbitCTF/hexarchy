# Firefox ships in the base packages, so it never goes through
# hexarchy-install-browser. Give it the same treatment the interactive
# installer would: distribution policies and native Wayland mode.
sudo cp -f "$HEXARCHY_PATH/default/firefox/policies.json" /usr/lib/firefox/distribution/policies.json
mkdir -p ~/.config/environment.d
echo "MOZ_ENABLE_WAYLAND=1" > ~/.config/environment.d/hexarchy-firefox-wayland.conf

# Live-sync Firefox's theme to the current Hexarchy theme (generates one
# static theme per installed Hexarchy theme, plus the native messaging host
# that pushes live color updates into a running browser).
hexarchy-firefox-themes
hexarchy-install-firefox-theme