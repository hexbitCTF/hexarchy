-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Statically point every app Hyprland launches at a fixed D-Bus session bus
-- path, and actually start the daemon there (see start-dbus-session.sh for
-- why: relying on lazy dbus-launch autolaunch caused runaway fork storms).
hl.env("DBUS_SESSION_BUS_ADDRESS", "unix:path=" .. os.getenv("XDG_RUNTIME_DIR") .. "/bus")
o.exec_on_start(os.getenv("HOME") .. "/.config/hypr/start-dbus-session.sh")

-- Expose the session bus at $XDG_RUNTIME_DIR/bus (systemd-free D-Bus fix).
o.exec_on_start(os.getenv("HOME") .. "/.config/hypr/setup-session-bus.sh")

-- Luke Smith style fast key repeat.
o.exec_on_start("xset r rate 300 50")

-- Runit session-equivalents of Hexarchy's systemd --user services.
-- Lock before suspend (was hexarchy-sleep-lock.service).
o.exec_on_start("hexarchy-system-sleep-monitor")
-- Crash notifications (was hexarchy-crash-watch.service).
o.exec_on_start("hexarchy-crash-watch")
-- Input method (was hexarchy-fcitx5.service).
o.exec_on_start("fcitx5 -d")
-- Monitor profile daemon (was hyprmoncfgd.service).
o.exec_on_start("hyprmoncfgd")

-- Un-freeze the headphone-jack sense at boot when earphones were plugged in
-- before power-on (kicks the codec, then converges with WirePlumber).
o.exec_on_start(os.getenv("HOME") .. "/.local/bin/hexarchy-analog-kickstart")

-- Mic noise gate: own client (was a systemd --user unit elsewhere) + wiring.
o.exec_on_start("pipewire -c mic-noise-gate.conf")
o.exec_on_start(os.getenv("HOME") .. "/.local/bin/mic-noise-gate-connect")
-- Keep the split analog ACP profiles (Speaker/Headphones) in step with the
-- headphone jack, and clear a manual microphone pick on plug/unplug.
o.exec_on_start(os.getenv("HOME") .. "/.local/bin/hexarchy-analog-watch")

-- hyprmoncfgd owns monitor layout and lid policy, so keep Hexarchy's default
-- monitor-watch (which re-enables the internal panel at scale 2, fighting the
-- profile) from surviving session start.
o.exec_on_start("pkill -f '[h]exarchy-hyprland-monitor-watch'")

-- This Hyprland fork reports dpmsStatus=false while displays are on, which
-- makes hyprmoncfgd believe all screens are asleep and pause automatic
-- switching. Keep DPMS explicitly enabled so the daemon never gets stuck.
o.exec_on_start("(while :; do hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })' >/dev/null 2>&1; sleep 4; done &)")
