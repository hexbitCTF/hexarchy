# Personal overlay

Personal, machine-independent overrides on top of the Hexarchy defaults in `default/`, `config/`, and `themes/`. This is not part of the Hexarchy package and is never installed by `install/setup.sh`.

Run `bash personal/apply.sh` on a machine that already has Hexarchy's base packages, Quickshell, and Hyprland set up, to bring over:

- `hypr/bindings.lua`, `hypr/input.lua` -- personal Hyprland keybind and input overrides
- Firefox live-theme sync setup (needs `hexarchy-firefox-themes` / `hexarchy-install-firefox-theme` from `bin/`, added alongside this)
- A clone of the separately-versioned Neovim config (`github.com/hexbitCTF/nvim`)

Deliberately excluded (hardware-specific to the source machine, not portable): monitor layout, the D-Bus session workaround, and audio codec fixes that used to live in this user's `~/.config/hypr/autostart.lua` and `monitors.lua`.
