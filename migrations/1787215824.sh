echo "Install hey (hey-cli) via mise wrapper"

if [[ ! -f $HOME/.local/state/hexarchy/preinstalls-removed ]]; then
  hexarchy-mise-install github:basecamp/hey-cli hey
fi
