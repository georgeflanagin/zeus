#!/bin/bash
# Common safety logic for zeus command wrappers

LOGFILE="/var/log/zeus-wrapper.log"

# Default blocklist (can be overridden)
BLOCKED_PATTERNS=("${BLOCKED_PATTERNS[@]:-wheel --remove-home --force}")

log() {
    echo "$(date '+%F %T') | $(whoami) ran: $CMDNAME $*" >> "$LOGFILE"
}

fail_if_blocked() {
    for pattern in "${BLOCKED_PATTERNS[@]}"; do
        if printf '%q ' "$@" | grep -q -w "$pattern"; then
            echo "⚠️  Error: Forbidden option or target: '$pattern'" >&2
            log "[BLOCKED] $*"
            exit 1
        fi
    done
}

