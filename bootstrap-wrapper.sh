#!/bin/bash
# bootstrap-wrapper.sh — Create filtered Zeus wrappers for selected commands

set -euo pipefail

LIBEXEC_COMMON="/usr/local/libexec/zeus_wrapper_common.sh"
WRAPPER_DIR="/usr/local/sbin"
ZEUS_GROUP="zeusgrp"

# List of commands to wrap as they are generally written.
COMMAND_LIST=(
  usermod
  groupadd
  gpasswd
)

# Ensure the shared common logic exists
if [[ ! -f "$LIBEXEC_COMMON" ]]; then
    echo "Missing: $LIBEXEC_COMMON"
    exit 1
fi

for cmd in "${COMMAND_LIST[@]}"; do
    WRAPPER_PATH="$WRAPPER_DIR/$cmd"
    REALCMD="/usr/sbin/$cmd"

    # Avoid overwriting if it already exists
    if [[ -f "$WRAPPER_PATH" ]]; then
        echo "Skipping existing wrapper: $WRAPPER_PATH"
        continue
    fi

    echo "Installing wrapper for $cmd"

    cat <<EOF > "$WRAPPER_PATH"
#!/bin/bash
CMDNAME=\$(basename "\$0")
REALCMD="$REALCMD"

# Custom filtering for $cmd
BLOCKED_PATTERNS=('wheel')

source "$LIBEXEC_COMMON"

fail_if_blocked "\$@"
log "\$@"
exec sudo "\$REALCMD" "\$@"
EOF

    chmod 750 "$WRAPPER_PATH"
    chown root:$ZEUS_GROUP "$WRAPPER_PATH"
done

echo "Zeus wrappers installed in $WRAPPER_DIR"

