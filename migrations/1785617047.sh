echo "Install oh-my-pi (omp) via mise wrapper"

if [[ ! -f $HOME/.local/state/hexarchy/preinstalls-removed ]]; then
  hexarchy-mise-install github:can1357/oh-my-pi omp
fi
