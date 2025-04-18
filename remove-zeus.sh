#!/bin/bash
# uninstall-zeus.sh — Remove Zeus user, wrappers, sudoers config, and related files

set -euo pipefail

echo "This will remove the 'zeus' user, wrappers, group, and sudo access."

read -p "Are you sure you want to proceed? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Constants
ALLOWED_COMMANDS_FILE="/etc/zeus/allowed-commands"
CHECKSUM_FILE="/var/lib/zeus/allowed-commands.md5"
CRON_SCRIPT="/usr/local/sbin/check-zeus-commands.sh"
LOGFILE="/var/log/zeus-login.log"
SUDOERS_FILE="/etc/sudoers.d/zeus"
SUDOERS_GEN="/usr/local/sbin/generate-zeus-sudoers.sh"
WRAPPER_DIR="/usr/local/sbin"
ZEUS_GROUP="zeus"
ZEUS_USER="zeus"
ZEUS_WRAPPER_COMMON="/usr/local/libexec/zeus_wrapper_common.sh"

# 1. Remove user and home directory
if id "$ZEUS_USER" &>/dev/null; then
    echo "Deleting user '$ZEUS_USER'..."
    userdel -r "$ZEUS_USER" || echo "(Home directory not removed or doesn't exist)"
fi

# 2. Remove sudoers file
[[ -f "$SUDOERS_FILE" ]] && rm -v "$SUDOERS_FILE"

# 3. Remove command list and checksum
[[ -f "$ALLOWED_COMMANDS_FILE" ]] && rm -v "$ALLOWED_COMMANDS_FILE"
[[ -f "$CHECKSUM_FILE" ]] && rm -v "$CHECKSUM_FILE"

# 4. Remove cron monitoring script
[[ -f "$CRON_SCRIPT" ]] && rm -v "$CRON_SCRIPT"

# 5. Remove sudoers generator
[[ -f "$SUDOERS_GEN" ]] && rm -v "$SUDOERS_GEN"

# 6. Remove the wrapper common logic
[[ -f "$ZEUS_WRAPPER_COMMON" ]] && rm -v "$ZEUS_WRAPPER_COMMON"

# 7. Remove wrappers
echo "Removing Zeus wrappers from $WRAPPER_DIR..."
find "$WRAPPER_DIR" -type f -user root -group "$ZEUS_GROUP" -perm -750 -exec rm -v {} \;

# 8. Remove group
if getent group "$ZEUS_GROUP" &>/dev/null; then
    echo "Removing group '$ZEUS_GROUP'..."
    groupdel "$ZEUS_GROUP"
fi

# 9. Remove crontab entry if present
crontab -l 2>/dev/null | grep -v "$CRON_SCRIPT" | crontab - || true

# 10. Remove the logfile
chattr -a "$LOGFILE"
rm -f "$LOGFILE"

echo "Zeus has been removed. The workstation may now ascend... to general use."

