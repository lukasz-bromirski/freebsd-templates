#!/usr/bin/env sh
# prepare-system.sh — FreeBSD system hardening and preparation
# Usage: prepare-system.sh [module ...] | prepare-system.sh all
#
# Modules: ssh chrony sysctl build
# Default (no args): ssh chrony sysctl build
#
# Assumptions:
#   - Run as root
#   - Source files (sshd_config, chrony.conf, sysctl.conf, make.conf, server15)
#     are in the same directory as this script
#   - git(1) is already installed
#   - Target arch is amd64; kernel config is named server15
#   - FreeBSD branch: stable/15

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGFILE="/var/log/prepare-system.log"

# ── helpers ──────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" | tee -a "$LOGFILE"; }
die() { log "ERROR: $*"; exit 1; }

require_root() {
    [ "$(id -u)" -eq 0 ] || die "Must be run as root"
}

require_file() {
    [ -f "${SCRIPT_DIR}/$1" ] || die "Required source file not found: ${SCRIPT_DIR}/$1"
}

backup() {
    local target="$1"
    if [ -f "$target" ]; then
        cp -p "$target" "${target}.bak.$(date '+%Y%m%d%H%M%S')"
        log "Backed up $target"
    fi
}

# ── modules ───────────────────────────────────────────────────────────────────

do_ssh() {
    log "==> [ssh] Hardening OpenSSH"
    require_file "sshd_config"

    # Filter weak DH params (keep >= 3072-bit only)
    # Ref: https://ssl-config.mozilla.org/#server=openssh
    awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.safe \
        && mv /etc/ssh/moduli.safe /etc/ssh/moduli \
        || die "Failed to filter /etc/ssh/moduli"

    # Regenerate host keys — remove all, generate RSA-4096 and Ed25519 only
    rm -f /etc/ssh/ssh_host_*
    ssh-keygen -t rsa     -b 4096 -f /etc/ssh/ssh_host_rsa_key     -N "" -q
    ssh-keygen -t ed25519          -f /etc/ssh/ssh_host_ed25519_key -N "" -q
    log "Host keys regenerated (RSA-4096, Ed25519)"

    backup /etc/ssh/sshd_config
    cp "${SCRIPT_DIR}/sshd_config" /etc/ssh/sshd_config
    chmod 600 /etc/ssh/sshd_config

    /etc/rc.d/sshd restart || die "sshd restart failed"
    log "sshd restarted"
}

do_chrony() {
    log "==> [chrony] Installing hardened NTP config"
    require_file "chrony.conf"

    backup /usr/local/etc/chrony.conf
    cp "${SCRIPT_DIR}/chrony.conf" /usr/local/etc/chrony.conf
    chmod 644 /usr/local/etc/chrony.conf

    service chronyd enable  || die "Failed to enable chronyd"
    service chronyd restart || die "Failed to start chronyd"
    log "chronyd enabled and started"
}

do_sysctl() {
    log "==> [sysctl] Applying hardened sysctl settings"
    require_file "sysctl.conf"

    backup /etc/sysctl.conf
    cp "${SCRIPT_DIR}/sysctl.conf" /etc/sysctl.conf
    chmod 644 /etc/sysctl.conf

    /sbin/sysctl -f /etc/sysctl.conf || die "sysctl -f failed"
    log "sysctl applied"
}

do_build() {
    log "==> [build] Setting up FreeBSD src tree (stable/15)"
    require_file "make.conf"
    require_file "server15"

    backup /etc/make.conf
    cp "${SCRIPT_DIR}/make.conf" /etc/make.conf
    chmod 644 /etc/make.conf

    log "Cleaning /usr/src"
    rm -rf /usr/src
    install -d -o root -g wheel -m 0755 /usr/src

    log "Cloning stable/15 (shallow)"
    git clone --depth 1 -b stable/15 https://git.FreeBSD.org/src.git /usr/src \
        || die "git clone failed"

    log "Installing kernel config server15"
    cp "${SCRIPT_DIR}/server15" /usr/src/sys/amd64/conf/
    chmod 644 /usr/src/sys/amd64/conf/server15

    log "build module complete"
}

# ── dispatch ──────────────────────────────────────────────────────────────────

require_root

ALL_MODULES="ssh chrony sysctl build"

# Default: run everything
if [ $# -eq 0 ]; then
    MODULES="$ALL_MODULES"
elif [ "$1" = "all" ]; then
    MODULES="$ALL_MODULES"
else
    MODULES="$*"
fi

log "Starting prepare-system.sh — modules: ${MODULES}"

for module in $MODULES; do
    case "$module" in
        ssh)    do_ssh    ;;
        chrony) do_chrony ;;
        sysctl) do_sysctl ;;
        build)  do_build  ;;
        *)      die "Unknown module '$module'. Valid: ${ALL_MODULES}" ;;
    esac
done

log "All requested modules complete."
