# Real newlines, not a literal \n: the card renders the body as it arrives, and
# elides past three lines.
hexarchy-notification-send -u critical -g  "Learn Keybindings" \
  $'Super + K for cheatsheet.\nSuper + Space for Hexarchy Menu.' \
  --exec hexarchy-menu-keybindings
