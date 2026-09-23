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

-- Vim-style window focus: SUPER+H/L for left/right, SUPER+J/K for up/down
hl.unbind("SUPER + LEFT")      -- was Focus on left window
hl.unbind("SUPER + RIGHT")     -- was Focus on right window
hl.unbind("SUPER + L")         -- was Toggle workspace layout
hl.unbind("SUPER + DOWN")      -- was Focus on below window
hl.unbind("SUPER + UP")        -- was Focus on above window
hl.unbind("SUPER + J")         -- was Toggle window split
hl.unbind("SUPER + K")         -- was Keybindings
o.bind("SUPER + H", "Focus left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + L", "Focus right window", hl.dsp.focus({ direction = "r" }))
o.bind("SUPER + J", "Focus below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + DOWN", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + SHIFT + K", "Keybindings", "hexarchy menu keybindings")
o.bind("SUPER + SHIFT + V", "Neovim keybindings", "hexarchy-menu-nvim-keybindings")

-- LocalSend share menu (like OMArchi quattro's Super+Ctrl+S)
o.bind("SUPER + CTRL + S", "Share menu", "hexarchy menu summon trigger.share")

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Hexarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Hexarchy menu", "hexarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Lid closed handling belongs to hyprmoncfgd (its closed-lid policy applies the
-- internal-disabled/external layout); Hexarchy's clamshell would re-enable the
-- internal panel at scale 2 and fight the profile.
hl.unbind("switch:off:Lid Switch")

-- The laptop-display toggle goes through hyprmoncfg's own apply engine
-- (laptop-display-toggle), so the internal panel stays consistent with the
-- active profile instead of fighting it.
hl.unbind("SUPER + CTRL + Delete")
o.bind("SUPER + CTRL + Delete", "Toggle laptop display", "laptop-display-toggle")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "hexarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "hexarchy-shell shell toggle hexarchy.emojis")

-- Browser keybinds: hardwire the hardened launcher in ~/.local/bin (absolute
-- path, since Hyprland puts /usr/share/hexarchy/bin first on PATH). The stock
-- hexarchy-launch-browser breaks when Firefox sets itself as default, because
-- it writes a "userapp-Firefox Developer Edition-XXXX.desktop" entry whose
-- name contains spaces and the stock lookup word-splits on them.
local browser_launch = os.getenv("HOME") .. "/.local/bin/hexarchy-launch-browser"
hl.unbind("SUPER + SHIFT + RETURN")   -- was Browser
hl.unbind("SUPER + SHIFT + B")        -- was Browser
hl.unbind("SUPER + SHIFT + ALT + B")  -- was Browser (private)
o.bind("SUPER + SHIFT + RETURN", "Browser", browser_launch)
o.bind("SUPER + SHIFT + B", "Browser", browser_launch)
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", browser_launch .. " --private")
