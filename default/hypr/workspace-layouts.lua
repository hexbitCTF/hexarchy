-- Restore workspace layouts saved by hexarchy-hyprland-workspace-layout-toggle.

local paths = require("default.hypr.paths")
local require_all = require("default.hypr.require_all")

local layouts_dir = paths.state_home .. "/hexarchy/workspace-layouts"

require_all.files(layouts_dir, "hexarchy.workspace-layouts", { reload = true })
