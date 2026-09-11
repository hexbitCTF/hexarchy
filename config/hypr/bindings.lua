-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   hexarchy menu keybindings --print

-- To disable every Hexarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.hexarchy"), then add
-- only the bindings you want below:
--   hexarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   hexarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Hexarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Hexarchy menu", "hexarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "hexarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "hexarchy-shell shell toggle hexarchy.emojis")
