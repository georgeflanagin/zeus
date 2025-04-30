#!/bin/bash
# create-zeus.sh - Create Zeus, the not-quite root user.

set -euo pipefail

if ! id -u $(whoami) ; then
    echo 'This command must be run as root.'
    exit
fi

echo "Bootstrapping Zeus privilege structure..."

# Constants
ALLOWED_CMDS_FILE="/etc/zeus/allowed-commands"
CHECKSUM_FILE="/var/lib/zeus/allowed-commands.md5"
CRON_SCRIPT="/usr/local/sbin/check-zeus-commands.sh"
LIBEXEC_COMMON="/usr/local/libexec/zeus_wrapper_common.sh"
SUDOERS_FILE="/etc/sudoers.d/zeus"
SUDOERS_GEN="/usr/local/sbin/generate-zeus-sudoers.sh"
TRUSTEE_GROUP="trustee"
WRAPPER_DIR="/usr/local/sbin"
ZEUS_USER="zeus"
ZEUS_GROUP="zeus"



# Create groups if they do not exist.
getent group "$ZEUS_GROUP" >/dev/null || groupadd "$ZEUS_GROUP"
getent group "$TRUSTEE_GROUP" >/dev/null || groupadd "$TRUSTEE_GROUP"

# Create zeus user if missing
if ! id "$ZEUS_USER" &>/dev/null; then
    useradd -m -s /bin/bash -g "$ZEUS_GROUP" "$ZEUS_USER"
    chown root:trustee /home/zeus
    usermod -aG "$TRUSTEE_GROUP" "$ZEUS_USER"
    chmod 0750 /home/zeus
    echo "Created user '$ZEUS_USER'"
fi

# Create /etc/zeus and /var/lib/zeus
mkdir -p /etc/zeus
mkdir -p /var/lib/zeus

# Setup logging.
touch /var/log/zeus-login.log
chown root:trustee /var/log/zeus-login.log
chmod 0620 /var/log/zeus-login.log
chattr +a /var/log/zeus-login.log

touch /var/log/zeus-wrapper.log
chown root:trustee /var/log/zeus-wrapper.log
chmod 0620 /var/log/zeus-wrapper.log
chattr +a /var/log/zeus-wrapper.log

# Set zeus's .bashrc so that /usr/local/sbin is first.
cat <<EOF >/home/zeus/.bashrc
export PATH=/usr/local/sbin:\$PATH
EOF

# Create a starter allowed-commands file if missing
if [[ ! -f "$ALLOWED_CMDS_FILE" ]]; then
    cat <<EOF > "$ALLOWED_CMDS_FILE"
# One command per line, full path only
/usr/sbin/usermod
/usr/sbin/groupadd
/usr/sbin/gpasswd
EOF
    echo "Created initial $ALLOWED_CMDS_FILE"
fi

# Create sudoers generator.
cat <<'EOF' > "$SUDOERS_GEN"
#!/bin/bash
INPUT="/etc/zeus/allowed-commands"
OUTPUT="/etc/sudoers.d/zeus"
ZEUSUSER="zeus"

if [[ ! -f $INPUT ]]; then
    echo "Error: $INPUT not found."
    exit 1
fi

echo -n "$ZEUSUSER ALL=(ALL) NOPASSWD:" > "$OUTPUT"

first=1
while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    if [[ $first -eq 1 ]]; then
        echo -n " $line" >> "$OUTPUT"
        first=0
    else
        echo -n ", $line" >> "$OUTPUT"
    fi
done < "$INPUT"

echo >> "$OUTPUT"
chmod 440 "$OUTPUT"
EOF

chmod +x "$SUDOERS_GEN"

# Generate sudoers from initial command list
"$SUDOERS_GEN"

# Create checksum script
cat <<'EOF' > "$CRON_SCRIPT"
#!/bin/bash
COMMANDS_FILE="/etc/zeus/allowed-commands"
HASH_FILE="/var/lib/zeus/allowed-commands.md5"
SUDOERS_GEN="/usr/local/sbin/generate-zeus-sudoers.sh"

mkdir -p /var/lib/zeus

CURRENT_HASH=$(md5sum "$COMMANDS_FILE" | awk '{print $1}')
LAST_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")

if [[ "$CURRENT_HASH" != "$LAST_HASH" ]]; then
    echo "Change detected in allowed-commands. Regenerating sudoers..."
    "$SUDOERS_GEN"
    echo "$CURRENT_HASH" > "$HASH_FILE"
fi
EOF

chmod +x "$CRON_SCRIPT"

# Add to root’s crontab if not already there
if ! crontab -l 2>/dev/null | grep -q "$CRON_SCRIPT"; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * $CRON_SCRIPT") | crontab -
    echo "Cron job installed to monitor command list changes."
fi

# Create /home/zeus/tmp in fstab and mount it.
FSTAB_LINE='tmpfs /home/zeus/tmp tmpfs rw,nodev,nosuid,noexec,size=128M,uid=zeus,gid=trustee,mode=0700 0 0'

# Check if entry already exists
if grep -q '^tmpfs[[:space:]]\+/home/zeus/tmp' /etc/fstab; then
    echo "An entry for /home/zeus/tmp already exists in /etc/fstab."
else
    echo "Adding tmpfs entry to /etc/fstab..."
    echo "$FSTAB_LINE" >> /etc/fstab
fi

# Create the mount point if it doesn't exist
if [ ! -d /home/zeus/tmp ]; then
    echo "Creating /home/zeus/tmp..."
    mkdir -p /home/zeus/tmp
fi

# Set proper ownership and permissions
echo "Setting ownership and permissions..."
chown zeus:trustee /home/zeus/tmp
chmod 700 /home/zeus/tmp

# Mount it
echo "Mounting /home/zeus/tmp..."
mount /home/zeus/tmp > /dev/null 2>&1
systemctl daemon-reload

# Verify
echo
echo "Mounted filesystem:"
mount | grep -q '/home/zeus/tmp' || echo " Mount failed!"

echo "Disk usage:"
df -h /home/zeus/tmp

echo "creating common code in /usr/libexec"
cat <<EOF >$LIBEXEC_COMMON

#!/bin/bash
# Common safety logic for zeus command wrappers

LOGFILE="/var/log/zeus-wrapper.log"

# Default blocklist (can be overridden)
BLOCKED_PATTERNS=("\${BLOCKED_PATTERNS[@]:-wheel --remove-home --force}")

log() {
    echo "\$(date '+%F %T') | \$(whoami) ran: \$1 \$*" >> "\$LOGFILE"
}

fail_if_blocked() {
    for pattern in "\${BLOCKED_PATTERNS[@]}"; do
        if printf '%q ' "\$@" | grep -q -w "\$pattern"; then
            echo "Error: Forbidden option or target: '\$pattern'" >&2
            log "[BLOCKED] \$*"
            exit 1
        fi
    done
}

EOF

echo "Members of trustee may now su - zeus."

