#!/bin/sh
# scp-distribute.sh
# 2026 Lukasz Bromirski
#
# quick & dirty script to copy local file to multiple destinations
#
# Usage:
#   scp-distribute.sh [-i] <local-file> <hosts-file> [remote-path]
#
#   local-file    File to copy (must exist locally).
#   hosts-file    One "host" or "user@host" per line.  Blank lines and
#                 lines starting with '#' are skipped.  Anything after
#                 the first whitespace-separated token on a line is
#                 ignored
#   remote-path   Destination on the remote, passed verbatim after the
#                 colon. Default: "./"
#
# Options:
#   -i   Interactive: allow password / passphrase prompts.
#
# Exit status: 0 if every host succeeded, non-zero if any failed.
#

set -u

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 1
}

# ---- argument parsing ------------------------------------------------------

INTERACTIVE=0
case "${1:-}" in
    -i)        INTERACTIVE=1; shift ;;
    -h|--help) usage ;;
esac

[ "$#" -lt 2 ] && usage
[ "$#" -gt 3 ] && usage

LOCAL_FILE="$1"
HOSTS_FILE="$2"
REMOTE_PATH="${3:-./}"

# ---- preflight -------------------------------------------------------------

[ -f "$LOCAL_FILE" ] || { echo "ERROR: local file not found: $LOCAL_FILE" >&2; exit 1; }
[ -f "$HOSTS_FILE" ] || { echo "ERROR: hosts file not found: $HOSTS_FILE" >&2; exit 1; }

# ---- scp options -----------------------------------------------------------

SCP_OPTS="-O -q -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
if [ "$INTERACTIVE" -eq 0 ]; then
    SCP_OPTS="$SCP_OPTS -o BatchMode=yes"
fi

# ---- main loop -------------------------------------------------------------

TOTAL=0
OK=0
FAIL=0
FAILED=""

# 'read host rest' splits on IFS (default whitespace), so 'host' gets the
# first token and 'rest' silently absorbs any inline comment after it.
while read -r host rest; do
    case "$host" in
        ''|\#*) continue ;;
    esac

    TOTAL=$((TOTAL + 1))
    printf '[%3d] %-40s ... ' "$TOTAL" "$host"

    # Word-splitting on SCP_OPTS is intentional; do not quote it.
    # shellcheck disable=SC2086
    if scp $SCP_OPTS "$LOCAL_FILE" "${host}:${REMOTE_PATH}"; then
        echo "OK"
        OK=$((OK + 1))
    else
        rc=$?
        echo "FAIL (scp exit $rc)"
        FAIL=$((FAIL + 1))
        FAILED="$FAILED $host"
    fi
done < "$HOSTS_FILE"

# ---- summary ---------------------------------------------------------------

echo ""
echo "----------------------------------------"
echo "Total: $TOTAL   OK: $OK   FAIL: $FAIL"
if [ -n "$FAILED" ]; then
    echo "Failed hosts:"
    for h in $FAILED; do
        echo "  $h"
    done
fi

[ "$FAIL" -eq 0 ]
