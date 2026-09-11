# Set identification from install inputs
if [[ -n ${HEXARCHY_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$HEXARCHY_USER_NAME"
fi

if [[ -n ${HEXARCHY_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$HEXARCHY_USER_EMAIL"
fi
