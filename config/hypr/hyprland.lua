-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Hexarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("HEXARCHY_PATH") or "/usr/share/hexarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Hexarchy default bindings. Add your own in hypr/bindings.lua.
-- hexarchy_default_bindings = false
--
-- Or disable only bindings for Hexarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- hexarchy_preinstalled_bindings = false

-- Load Hexarchy defaults.
require("default.hypr.hexarchy")

-- Put your personal overrides in these files. They're loaded after Hexarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })
