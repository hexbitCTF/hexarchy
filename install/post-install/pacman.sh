# Configure pacman after package installation completes. Offline target package
# installs use the live ISO's offline pacman.conf until this final restore.
cp -f "$HEXARCHY_PATH/default/pacman/pacman-${HEXARCHY_MIRROR:-stable}.conf" /etc/pacman.conf
cp -f "$HEXARCHY_PATH/default/pacman/mirrorlist-${HEXARCHY_MIRROR:-stable}" /etc/pacman.d/mirrorlist

# hexarchy-settings skips this override until cups-browsed is actually present
# to avoid pacman creating cups-browsed.conf.pacnew during ISO package install.
if [[ -f $HEXARCHY_PATH/etc-overrides/cups-cups-browsed.conf && -d /etc/cups ]]; then
  cp -f "$HEXARCHY_PATH/etc-overrides/cups-cups-browsed.conf" /etc/cups/cups-browsed.conf
  rm -f /etc/cups/cups-browsed.conf.pacnew
fi

source "$HEXARCHY_INSTALL/hardware/pacman.sh"
