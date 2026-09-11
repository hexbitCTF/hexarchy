-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Expose the session bus at $XDG_RUNTIME_DIR/bus (systemd-free D-Bus fix).
o.exec_on_start(os.getenv("HOME") .. "/.config/hypr/setup-session-bus.sh")

-- Runit session-equivalents of the systemd --user services.
o.exec_on_start("hexarchy-system-sleep-monitor") -- was hexarchy-sleep-lock.service
o.exec_on_start("hexarchy-crash-watch")          -- was hexarchy-crash-watch.service
o.exec_on_start("fcitx5 -d")                     -- was hexarchy-fcitx5.service
o.exec_on_start("hyprmoncfgd")                   -- was hyprmoncfgd.service
