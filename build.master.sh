#!/bin/sh
#
# freebsd-buildupdate.sh - build & install FreeBSD from source, unattended.
#
# Four gated parts, each timed and logged, each running only if the previous
# one exited cleanly:
#     1. make buildworld
#     2. make buildkernel  KERNCONF=<kernel>
#     3. make installkernel KERNCONF=<kernel>
#     4. make installworld
# followed by an unattended etcupdate(8) config merge, then it drops you back
# into an interactive shell sitting in /usr/src with the summary on screen.
#

set -u

# ------------------------------------------------------------------ config ---
KERNCONF="server15"
SRC="/usr/src"
OBJ="/usr/obj"
JOBS="$(( $(sysctl -n hw.ncpu) * 3 ))"   # 3x ncpu, per your original. See note 6.
MAKE="make -j${JOBS}"                     # word-split on use; do NOT quote $MAKE
DATE="$(date '+%Y-%m-%d.%H%M%S')"
SUMMARY="${SRC}/build.${DATE}.summary.txt"
ETCUPDATE_DB="/var/db/etcupdate"          # default etcupdate working dir

# ------------------------------------------------------------------- state ---
ABORT=0
ROWS=""                                   # accumulated summary table (no arrays in sh)
ETC_CONFLICTS="n/a"
START_ALL="$(date '+%s')"

hms() {
    s=$1
    printf '%02dh:%02dm:%02ds' $((s/3600)) $(((s%3600)/60)) $((s%60))
}
log() { printf '==> %s  %s\n' "$(date '+%F %T')" "$*"; }

# add_row "label" "result" seconds  -> append one formatted line to ROWS
add_row() {
    _r="$(printf '%-16s %-22s %s' "$1" "$2" "$(hms "$3")")"
    ROWS="${ROWS}${_r}
"
}

# run_step "label" "logfile" cmd args...
# Runs cmd (stdout+stderr -> logfile), times it, records pass/fail, and sets
# ABORT on failure so every later step is skipped.
run_step() {
    label="$1"; logf="$2"; shift 2
    if [ "${ABORT}" -eq 1 ]; then
        log "SKIP   ${label} (earlier step failed)"
        add_row "${label}" "SKIPPED" 0
        return 0
    fi
    log "START  ${label}"
    s="$(date '+%s')"
    "$@" >"${logf}" 2>&1
    rc=$?
    e="$(date '+%s')"
    if [ "${rc}" -eq 0 ]; then
        log "OK     ${label}  ($(hms $((e-s))))  -> ${logf}"
        add_row "${label}" "OK" $((e-s))
    else
        log "FAIL   ${label}  rc=${rc}  ($(hms $((e-s))))  -> ${logf}"
        add_row "${label}" "FAILED(rc=${rc})" $((e-s))
        ABORT=1
    fi
    return "${rc}"
}

# --------------------------------------------------------------- preamble ----
cd "${SRC}" || { echo "cannot cd ${SRC}"; exit 1; }

# etcupdate needs a reference tree the first time, or every merge is a no-op /
# error (this is the usual reason it "never works"). Bootstrap from the sources
# that match the CURRENTLY installed world -- i.e. BEFORE we pull new sources.
# -B avoids the gratuitous /etc/mail/*.cf conflicts on first extract.
if [ ! -e "${ETCUPDATE_DB}/current" ]; then
    log "etcupdate: no reference tree, bootstrapping (etcupdate extract -B)"
    etcupdate extract -B || log "etcupdate extract returned non-zero (continuing)"
fi

# Clean object tree (rm is the recommended clean; 'make clean' is slow & weaker).
log "Removing ${OBJ}"
rm -rf "${OBJ}"

# ----------------------------------------------------------------- build -----
# $MAKE is intentionally unquoted so it splits into: make -jN
run_step "git pull"      "${SRC}/build.${DATE}.gitpull.txt"       git -C "${SRC}" pull -4
run_step "buildworld"    "${SRC}/build.${DATE}.buildworld.txt"    $MAKE buildworld
run_step "buildkernel"   "${SRC}/build.${DATE}.buildkernel.txt"   $MAKE buildkernel   "KERNCONF=${KERNCONF}"
run_step "installkernel" "${SRC}/build.${DATE}.installkernel.txt" $MAKE installkernel "KERNCONF=${KERNCONF}"

# ----------------------------------------------------- pre-world etcupdate ---
# -p merges only what installworld needs (new uids/groups etc). Harmless on a
# same-branch update, important across a major version bump.
if [ "${ABORT}" -eq 0 ]; then
    log "START  etcupdate -p (pre-world)"
    if etcupdate -p > "${SRC}/build.${DATE}.etcupdate-p.txt" 2>&1; then
        add_row "etcupdate -p" "OK" 0
    else
        add_row "etcupdate -p" "WARN(see log)" 0
    fi
fi

run_step "installworld"  "${SRC}/build.${DATE}.installworld.txt"  $MAKE installworld

# ----------------------------------------------------- post-world etcupdate --
# etcupdate is non-interactive by design: it auto-merges everything it can and
# leaves only true conflicts behind for you to handle later with
# 'etcupdate resolve'. So this is already "as unattended as possible".
if [ "${ABORT}" -eq 0 ]; then
    log "START  etcupdate (merge /etc)"
    etcupdate > "${SRC}/build.${DATE}.etcupdate.txt" 2>&1
    ETC_CONFLICTS="$(etcupdate status 2>/dev/null | grep -c . || true)"
    add_row "etcupdate" "OK (conflicts: ${ETC_CONFLICTS})" 0
fi

# --------------------------------------------------------------- summary -----
END_ALL="$(date '+%s')"
{
    echo "FreeBSD source build/update summary"
    echo "host:    $(hostname)"
    echo "started: $(date -r "${START_ALL}" '+%F %T' 2>/dev/null || echo "${START_ALL}")"
    echo "kernel:  KERNCONF=${KERNCONF}    jobs: -j${JOBS}"
    echo "logs:    ${SRC}/build.${DATE}.*.txt"
    echo "------------------------------------------------------------"
    printf '%-16s %-22s %s\n' "STEP" "RESULT" "TIME"
    printf '%s' "${ROWS}"
    echo "------------------------------------------------------------"
    printf '%-16s %-22s %s\n' "TOTAL" "" "$(hms $((END_ALL-START_ALL)))"
    if [ "${ABORT}" -eq 1 ]; then
        echo
        echo "RESULT: FAILED - a step did not complete cleanly. Nothing was"
        echo "        installed past the failing step. Check the log above."
    else
        echo
        echo "RESULT: OK - kernel + world built and installed."
        if [ "${ETC_CONFLICTS}" != "0" ] && [ "${ETC_CONFLICTS}" != "n/a" ]; then
            echo "        etcupdate left conflicts: run 'etcupdate resolve'."
        fi
        echo "        Reboot when ready:  shutdown -r now"
        echo "        Afterwards prune stale bits: make check-old / make delete-old"
    fi
} | tee "${SUMMARY}"

# ------------------------------------------------- land the operator in src --
# A child script's 'cd' never reaches your interactive shell -- that is why your
# old 'cd /usr/src' "did nothing". Replacing this process with an interactive
# shell in ${SRC} actually puts you there. (Delete these two lines if you'd
# rather the script just exit.)
cd "${SRC}" || exit 0
exec "${SHELL:-/bin/sh}" -i
