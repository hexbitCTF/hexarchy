# Setup user theme folder and seed the default only when no theme exists yet.
mkdir -p ~/.config/hexarchy/themes

if [[ ! -s $HOME/.local/state/hexarchy/current/theme.name ]]; then
  # iso-chroot and provision-owner both run without a live session to notify.
  if [[ ${HEXARCHY_SETUP_CONTEXT:-runtime} != "runtime" ]]; then
    HEXARCHY_THEME_HEADLESS=1 hexarchy-theme-set "Tokyo Night"
    rm -f ~/.config/chromium/SingletonLock # otherwise archiso owns the Chromium singleton
  else
    hexarchy-theme-set "Tokyo Night"
  fi
fi
hexarchy-theme-set-pi --activate

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/hexarchy/current/theme/btop.theme" ~/.config/btop/themes/current.theme
