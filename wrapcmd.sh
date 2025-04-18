#!/bin/bash
# wrapcmd.sh – Generate a zeus command wrapper that defers to the central logic

set -e

WRAPPER_DIR="/usr/local/sbin"
LIBEXEC_COMMON="/usr/local/libexec/zeus_wrapper_common.sh"
DEFAULT_REALBIN_DIR="/usr/sbin"
GROUP="trustee"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <command> [real binary path]"
    exit 1
fi

CMD="$1"
REALBIN="${2:-$DEFAULT_REALBIN_DIR/$CMD}"
WRAPPER_PATH="$WRAPPER_DIR/$CMD"

if [[ -e $WRAPPER_PATH ]]; then
    echo "Error: $WRAPPER_PATH already exists."
    exit 1
fi

cat <<EOF > "$WRAPPER_PATH"
#!/bin/bash
CMDNAME=\$(basename "\$0")
REALCMD="$REALBIN"

# Optional: define command-specific block patterns here
BLOCKED_PATTERNS=('wheel')

source "$LIBEXEC_COMMON"

fail_if_blocked "\$@"
log "\$@"
exec "\$REALCMD" "\$@"
EOF

chmod 750 "$WRAPPER_PATH"
chown root:$GROUP "$WRAPPER_PATH"

echo "Wrapper created: $WRAPPER_PATH"

