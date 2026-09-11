hl.on("hyprland.start", function()
  -- Set environment for session services (elogind/runit)
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  -- Start PipeWire audio stack (runit has no user services, so launch directly)
  hl.exec_cmd("pipewire &")
  hl.exec_cmd("sleep 0.5 && wireplumber &")
  hl.exec_cmd("sleep 1 && pipewire-pulse &")

  hl.exec_cmd("hexarchy-launch-shell")
  hl.exec_cmd("hexarchy-provision-first-run")
  hl.exec_cmd("hexarchy-powerprofiles-init")
  hl.exec_cmd(o.launch("hexarchy-hyprland-monitor-watch"))
  hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))

  -- Run post-boot hooks after startup config has loaded.
  hl.exec_cmd("sleep 2 && hexarchy-hook post-boot")
end)
