echo "Install ori (OpenRouter's agent harness) via mise wrapper"

if [[ ! -f $HOME/.local/state/hexarchy/preinstalls-removed ]]; then
  hexarchy-mise-install github:OpenRouterLabs/ori-releases ori
fi
