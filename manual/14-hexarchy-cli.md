# Hexarchy CLI

Hexarchy is usually controlled through the hotkeys and the Hexarchy menu (`Super + Space`). But you can also control it through the `hexarchy` CLI. This is particularly helpful when you're having an AI agent work with you on customization or configuration.

The CLI has access to all the internal tooling that is used both via the menu and otherwise. You can see everything that's available by running `hexarchy` in the terminal.

It looks something like this:

```
~ ❯ hexarchy
Hexarchy command center

Usage:
  hexarchy <command> [args...]
  hexarchy commands [--all] [--json] [--check]
  hexarchy <group> --help
  hexarchy <group> <command> --help

Common commands:
  hexarchy update              Update Hexarchy and system packages
  hexarchy theme list          List available themes
  hexarchy theme set <name>    Apply a theme
  hexarchy font list           List available fonts
  hexarchy screenshot          Take a screenshot
  hexarchy debug               Print debugging information

Groups:
  agent          AI coding agent usage data
  audio          Audio input and output controls
  bar            Hexarchy shell bar layout and settings
  battery        Battery status helpers
  bluetooth      Bluetooth device controls
  branch         Hexarchy git branch management
  branding       About and screensaver branding
  brightness     Display and keyboard brightness
  capture        Screenshots and screen recording
  channel        Hexarchy release channel management
  clipboard      Clipboard helpers
  cmd            Command and shortcut helpers
  config         System configuration helpers
  debug          Diagnostics and support logs
  ...
```

And you can dive deeper on every group:

```
~ ❯ hexarchy capture
Capture commands — Screenshots and screen recording:
  hexarchy capture qr                                                                                                                                                                                                       Decode a QR code from a screenshot region
  hexarchy capture screenrecording [--fullscreen] [--with-desktop-audio] [--with-microphone-audio] [--with-webcam] [--webcam-device=<device>] [--webcam-size=<small|medium|large>] [--resolution=<size>] [--stop-recording]  Start or stop screen recording
  hexarchy capture screenrecording with webcam                                                                                                                                                                              Pick a webcam and start a screen recording with it
  hexarchy capture screenshot [smart|region|windows|fullscreen] [slurp|copy|save] [--editor=<name>]                                                                                                                         Take a screenshot
  hexarchy capture text                                                                                                                                                                                                     Extract text from a screenshot region with OCR
  hexarchy capture webcam resize <smaller|larger|reset|small|medium|large>                                                                                                                                                  Resize the active webcam recording overlay
```

Every command takes `--help` too, whether you ask a whole group (`hexarchy capture --help`) or a single command (`hexarchy capture screenshot --help`).

### Opening the menu from the terminal

The Hexarchy menu is scriptable as well, which is handy for your own keybindings. `hexarchy menu` opens it at the root, and you can jump straight to any point in the tree by naming it: `hexarchy menu summon style.theme` goes right to the theme picker, `hexarchy menu toggle system` opens the system menu and closes it again if it's already up, and `hexarchy menu close` puts it away.
