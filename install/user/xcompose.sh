# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run hexarchy-restart-xcompose to apply changes

# Include fast emoji access
include "/usr/share/hexarchy/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$HEXARCHY_USER_NAME"
<Multi_key> <space> <e> : "$HEXARCHY_USER_EMAIL"
EOF
