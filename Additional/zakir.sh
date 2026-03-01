
#!/usr/bin/env bash

# ============================================
# Script Name : vmas-log-pcap.sh
# Description : Example Bash script with author info
# Author      : Ugandhar Nellore
# Created On  : 2025-12-17
# Version     : 1.0

# Captures logs/pcaps from Kubernetes pods with VLB special-case, strict components selection [pod name: ns-component-index],
# mdp_pdump pre-kill/start with sudo, signal-safe stop with sudo, and reliable copy.
# Short file names, quiet mode, auto-stop using --duration,
# and final summary of local files.
# Refer help or usage section for more supported options.

# ============================================

set -uo pipefail

########################################
# Defaults
########################################
NAMESPACE=""
POD_PATTERNS=""
DO_LOG=0
DO_VLB_LOG=0
DO_PCAP=0
CONTAINER=""
PREFIX="capture"
OUT_DIR="./captures"
REMOTE_DIR_BASE="/tmp/tmpLog"



VPPCTL_BIN="/usr/local/mnvpp-pkg/bin/vppctl"
UPA_SRC_LOG="/data/storage/log/UPA.log"


VLB_LOG_ENABLE=0
VLB_LOG_OUTFILE=""
VLB_TAIL_PID=""
VLB_ACTIVE=false

MLOGC_PATH="/usr/IMS/current/bin/mlogc"
MLOGC_ARGS="-c 127.0.0.1"

PCAP_BASE_CMD="tcpdump -i any -s 0"
MDP_PDUMP_PATH="/usr/local/mnvpp-pkg/bin/mdp_pdump"

TIMESTAMP_FMT="%Y%m%d_%H%M%S"
MATCH_MODE="strict_component"
VLB_TAG="vlb"
DEBUG=0
SHORT_NAMES=1
QUIET=1

SUDO_START=1        # start commands with 'sudo -n' if available
DURATION=0          # seconds; auto-stop if >0
TIMER_PID=""

MERGE=0
COMBINED_NAME=""
MERGE_APPEND=0
MERGE_FORCE_FORMAT=""

EXCLUSIVE=0
LOCK_FILE="/tmp/k8s-log-pcap.lock"
LOCK_TIMEOUT=0
LOCK_NONBLOCK=0

CLEANED=0
RUN_PHASE="init"

########################################
# Helpers
########################################
usage() {
  cat <<EOF
Usage: $0 -n <namespace> [-pods a,b,c] [-l] [-p] [-c <container>] [-x <prefix>] [-o <output_dir>]
            [--mlogc-path <path>] [--pcap-cmd "<cmd>"] [--match-mode strict_component|prefix|substring|regex] [--vlb-tag <str>]
            [--merge] [--combined-name <file>] [--merge-append] [--merge-format pcap|pcapng]
            [--exclusive] [--lock-file <path>] [--lock-timeout <sec>] [--lock-nonblock]
            [--short-names] [--quiet] [--duration <seconds>] [--vlb-log] [--sudo-start|--no-sudo-start] [--debug]

Actions:
  -l   Start logs via mlogc (non-VLB)
  -p   Start pcap (tcpdump non-VLB; mdp_pdump VLB)
  -lp  Start both (pcap-only on VLB; IMS logs not useful VLB use --vlb-log option to enable dbg logs )
  
Selection:
  -pods a,b,c         Component names (strict mode) or tokens; if list contains the VLB tag (default 'vlb'),
                      we automatically include pods whose names contain the tag (e.g., 'vlbfe-*').

Short Names:
  --short-names       Use shorter run-directory and filenames.

Quiet Mode:
  --quiet             Suppress benign kubectl stderr ('Defaulted container …', 'tar: Removing leading …', 'command terminated …').

Auto-stop:
  --duration <sec>    Stop and collect after given seconds (skip interactive 's').

sudo:
  --sudo-start        Start mlogc/tcpdump/mdp_pdump with 'sudo -n' when available (default ON).
  --no-sudo-start     Disable sudo for start commands.

vlb-log:
  --vlb-log  		 Start vlb vpp log [Dangerous Operation use it only in pre-PROD environments]

EOF
}

err()  { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }
warn() { echo "[$(date '+%H:%M:%S')] WARN:  $*" >&2; }
log()  { echo "[$(date '+%H:%M:%S')] $*"; }

gen_run_id() {
  if [[ "$SHORT_NAMES" -eq 1 ]]; then
    local now pid rand
    now=$(date +"%y%m%d_%H%M%S")
    pid="$$"
    rand="$(head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    echo "${now}_${pid}_${rand}"
  else
    local now rand user host pid
    now=$(date +"%Y%m%d_%H%M%S")
    user="${USER:-user}"
    host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo host)"
    pid="$$"
    rand="$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    echo "${now}_${user}_${host}_${pid}_${rand}"
  fi
}

sudo_prefix() {
  if [[ "$SUDO_START" -eq 1 ]] && command -v sudo >/dev/null 2>&1; then
    printf 'sudo -n '
  else
    printf ''
  fi
}

filter_stderr() {
  grep -v -E \
    -e '^Defaulted container ' \
    -e '^tar: Removing leading '  \
    -e '^command terminated with exit code ' \
    >&2
}

run_kubectl() {
  if [[ "$QUIET" -eq 1 ]]; then
    kubectl "$@" 2> >(filter_stderr)
  else
    kubectl "$@"
  fi
}

safe_kubectl_exec() {
  set +e
  run_kubectl -n "$NAMESPACE" exec "$@"
  rc=$?
  set -e
  if [[ $rc -eq 129 || $rc -eq 130 || $rc -eq 143 ]]; then
    warn "kubectl exec interrupted (exit=$rc); continuing."
    return 0
  fi
  return $rc
}

kubectl_exec() {
  local pod="$1"; shift
  if [[ -n "$CONTAINER" ]]; then
    run_kubectl -n "$NAMESPACE" exec "$pod" -c "$CONTAINER" -- "$@"
  else
    run_kubectl -n "$NAMESPACE" exec "$pod" -- "$@"
  fi
}

kubectl_cp_from_pod() {
  local pod="$1"; local remote_path="$2"; local local_path="$3"
  mkdir -p "$(dirname "$local_path")" 2>/dev/null || true
  if [[ -n "$CONTAINER" ]]; then
    run_kubectl -n "$NAMESPACE" cp -c "$CONTAINER" "${pod}:${remote_path}" "$local_path"
  else
    run_kubectl -n "$NAMESPACE" cp "${pod}:${remote_path}" "$local_path"
  fi
  if [[ -s "$local_path" ]]; then
    return 0
  else
    warn "Local file missing or empty after copy: $local_path"
    return 1
  fi
}

is_vlb_pod() {
  local lower="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  local tag_lower="$(echo "$VLB_TAG" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower" == *"$tag_lower"* ]]
}

regex_escape() {
  local s="$1" escaped="" c
  for ((i=0; i<${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      '\'|'^'|'.'|'$'|'|'|'?'|'*'|'+'|'('|')'|'{'|'}'|'['|']') escaped+="\\$c" ;;
      *) escaped+="$c" ;;
    esac
  done
  printf '%s' "$escaped"
}

join_alternation() {
  local arr=("$@") out=""
  for i in "${!arr[@]}"; do
    out+="$(regex_escape "${arr[$i]}")"
    [[ $i -lt $((${#arr[@]}-1)) ]] && out+="|"
  done
  printf '%s' "$out"
}

compact_basename() {
  local pod="$1" ts="$2"
  local idx comp comp_idx ts_short
  idx="${pod##*-}"
  comp="${pod%-*}"; comp="${comp##*-}"
  comp_idx="${comp}-${idx}"
  ts_short="${ts:2:6}_${ts:9:6}"
  echo "${PREFIX}_${comp_idx}_${ts_short}"
}

pods_contains_vlb_tag() {
  local tag_lc; tag_lc="$(echo "$VLB_TAG" | tr '[:upper:]' '[:lower:]')"
  IFS=',' read -r -a arr <<< "$POD_PATTERNS"
  for t in "${arr[@]}"; do
    [[ "$(echo "$t" | tr '[:upper:]' '[:lower:]')" == "$tag_lc" ]] && return 0
  done
  return 1
}
grep_ci() {
  local pat="$1"
  awk -v pat="$pat" 'BEGIN{IGNORECASE=1} $0 ~ pat'
}

# Locking
LOCK_FD=200
LOCK_DIR_FALLBACK="/tmp/k8s-log-pcap.lockdir"
acquire_lock() {
  [[ "$EXCLUSIVE" -eq 0 ]] && return 0
  if command -v flock >/dev/null 2>&1; then
    exec {LOCK_FD}> "$LOCK_FILE" || { err "Cannot open lock file: $LOCK_FILE"; exit 3; }
    if [[ "$LOCK_NONBLOCK" -eq 1 ]]; then
      flock -n "$LOCK_FD" || { err "Another run is active (non-blocking)."; exit 3; }
    else
      if [[ "$LOCK_TIMEOUT" -gt 0 ]]; then
        flock -w "$LOCK_TIMEOUT" "$LOCK_FD" || { err "Failed to acquire lock within ${LOCK_TIMEOUT}s."; exit 3; }
      else
        flock "$LOCK_FD"
      fi
    fi
    log "[lock] Exclusive lock acquired via flock: $LOCK_FILE"
  else
    local waited=0
    while ! mkdir "$LOCK_DIR_FALLBACK" 2>/dev/null; do
      if [[ "$LOCK_NONBLOCK" -eq 1 ]]; then
        err "Another run is active (non-blocking, mkdir fallback)."; exit 3
      fi
      if [[ "$LOCK_TIMEOUT" -gt 0 && "$waited" -ge "$LOCK_TIMEOUT" ]]; then
        err "Failed to acquire lock within ${LOCK_TIMEOUT}s (mkdir fallback)."; exit 3
      fi
      sleep 1; waited=$((waited+1))
    done
    log "[lock] Exclusive lock acquired via mkdir: $LOCK_DIR_FALLBACK"
  fi
}
release_lock() {
  [[ "$EXCLUSIVE" -eq 0 ]] && return 0
  if command -v flock >/dev/null 2>&1; then
    flock -u "$LOCK_FD" || true
  else
    rmdir "$LOCK_DIR_FALLBACK" 2>/dev/null || true
  fi
}

########################################
# Parse args
########################################
REMAINDER=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -pods)           POD_PATTERNS="${2:-}"; shift 2;;
    --mlogc-path)    MLOGC_PATH="${2:-}"; shift 2;;
    --pcap-cmd)      PCAP_BASE_CMD="${2:-}"; shift 2;;
    --match-mode)    MATCH_MODE="${2:-}"; shift 2;;
    --vlb-tag)       VLB_TAG="${2:-}"; shift 2;;
    --merge)         MERGE=1; shift 1;;
    --combined-name) COMBINED_NAME="${2:-}"; shift 2;;
    --merge-append)  MERGE_APPEND=1; shift 1;;
    --merge-format)  MERGE_FORCE_FORMAT="${2:-}"; shift 2;;
    --exclusive)     EXCLUSIVE=1; shift 1;;
    --lock-file)     LOCK_FILE="${2:-}"; shift 2;;
    --lock-timeout)  LOCK_TIMEOUT="${2:-0}"; shift 2;;
    --lock-nonblock) LOCK_NONBLOCK=1; shift 1;;
    --short-names)   SHORT_NAMES=1; shift 1;;
    --quiet)         QUIET=1; shift 1;;
	--vlb-log)       DO_VLB_LOG=1; shift 1;;
    --duration)      DURATION="${2:-0}"; shift 2;;
    --sudo-start)    SUDO_START=1; shift 1;;
    --no-sudo-start) SUDO_START=0; shift 1;;
    --debug)         DEBUG=1; shift 1;;
    --)              shift; while [[ $# -gt 0 ]]; do REMAINDER+=("$1"); shift; done; break;;
    -*)              REMAINDER+=("$1"); shift;;
    *)               REMAINDER+=("$1"); shift;;
  esac
done
set -- "${REMAINDER[@]}"

while getopts ":n:c:x:o:lp" opt; do
  case "$opt" in
    n) NAMESPACE="$OPTARG" ;;
    c) CONTAINER="$OPTARG" ;;
    x) PREFIX="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    l) DO_LOG=1 ;;
    p) DO_PCAP=1 ;;
    \?) err "Invalid option: -$OPTARG"; usage; exit 1 ;;
    :)  err "Option -$OPTARG requires an argument."; usage; exit 1 ;;
  esac
done
shift $((OPTIND -1))

# Preflight
command -v kubectl >/dev/null 2>&1 || { err "kubectl not found in PATH."; exit 1; }
[[ -z "$NAMESPACE" ]] && { err "Namespace (-n) is required."; usage; exit 1; }
[[ "$DO_LOG" -eq 0 && "$DO_PCAP" -eq 0 ]] && { err "Select at least one of -l (log) or -p (pcap)."; usage; exit 1; }
if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then err "--duration must be a non-negative integer"; exit 1; fi

RUN_ID="$(gen_run_id)"
REMOTE_DIR="${REMOTE_DIR_BASE}/${RUN_ID}"
RUN_OUT_DIR="${OUT_DIR%/}/${RUN_ID}"

mkdir -p "$RUN_OUT_DIR" || { err "Could not create output directory: $RUN_OUT_DIR"; exit 1; }

declare -a LOCAL_PCAPS
declare -a LOCAL_LOGS
SELECTED_PODS=""
REGEX=""
TS=""

acquire_lock

########################################
# Cleanup
########################################
stop_and_collect_all() {
  [[ "$CLEANED" -eq 1 ]] && return 0
  CLEANED=1
  RUN_PHASE="stopping"
  trap '' INT TERM HUP
  [[ -n "${TIMER_PID:-}" ]] && kill "$TIMER_PID" 2>/dev/null || true
  [[ -z "${TS:-}" ]] && TS=$(date +"$TIMESTAMP_FMT")

  [[ -z "$SELECTED_PODS" ]] && { log "[cleanup] No pods recorded."; return 0; }

  for POD in $SELECTED_PODS; do
    log "Stopping and collecting from pod: $POD"

    # Ensure remote files readable
    safe_kubectl_exec "$POD" -- sh -c "
      if command -v sudo >/dev/null 2>&1; then sudo -n chmod -R a+r '${REMOTE_DIR}' 2>/dev/null || true;
      else chmod -R a+r '${REMOTE_DIR}' 2>/dev/null || true; fi
    " || warn "chmod remote failed."

    if is_vlb_pod "$POD"; then
	 	ACTIVE=$(kubectl_exec "$POD" sh -c "readShm | grep vnfcHAMode | grep -q ACTIVE && echo ACTIVE || echo INACTIVE" 2>/dev/null || echo INACTIVE)

    	if [[ "$ACTIVE" != "ACTIVE" ]]; then
        	log "  [VLB] HA mode not ACTIVE in $POD; skipping mdp debug enable and VLB log start."
        	continue
    	fi

	  if [[ "$DO_VLB_LOG" -eq 1 ]]; then
	  
      safe_kubectl_exec "$POD" -- sh -c "
        PGIDFILE=''${REMOTE_DIR}/UPA_tail_${RUN_ID}.pgid'; PIDFILE=''${REMOTE_DIR}/UPA_tail_${RUN_ID}.pgid'
        if [ -f \"\$PGIDFILE\" ]; then
          PGID=\$(cat \"\$PGIDFILE\" 2>/dev/null || true)
          [ -n \"\$PGID\" ] && kill -TERM \"-\$PGID\" 2>/dev/null || true
          i=0; while kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
          kill -KILL \"-\$PGID\" 2>/dev/null || true
        elif [ -f \"\$PIDFILE\" ]; then
          PID=\$(cat \"\$PIDFILE\" 2>/dev/null || true)
          if [ -n \"\$PID\" ] && kill -0 \"\$PID\" 2>/dev/null; then
            PGID=\"\$PID\"
            kill -TERM \"-\$PGID\" 2>/dev/null || true
            i=0; while kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
            kill -KILL \"-\$PGID\" 2>/dev/null || true
          fi
        fi
      " || warn "stop upa log interrupted."
      

	safe_kubectl_exec "$POD" -- sh -c "
    	VPPCTL_BIN_IN_POD='${VPPCTL_BIN:-/usr/local/mnvpp-pkg/bin/vppctl}'
    	if [ -x \"\$VPPCTL_BIN_IN_POD\" ]; then
      		$(sudo_prefix) \"\$VPPCTL_BIN_IN_POD\" set mdp log level warn || true
    	else
      		echo 'WARN: vppctl not found at' \"\$VPPCTL_BIN_IN_POD\" >&2
    	fi
 		 " || warn "Failed to set mdp log level to warn in $POD"
  		log "  [VLB] MDP log level -> warn"


      REMOTE_LOGS=$(kubectl_exec "$POD" sh -c "for f in '${REMOTE_DIR}'/*.log; do [ -e \"\$f\" ] && echo \"\$f\"; done 2>/dev/null || true")
      if [[ -n "$REMOTE_LOGS" ]]; then
        while IFS= read -r RLOG; do
          [[ -z "$RLOG" ]] && continue
          BASENAME=$(basename "$RLOG"); LOCAL_PATH="${RUN_OUT_DIR}/${BASENAME}"
          kubectl_cp_from_pod "$POD" "$RLOG" "$LOCAL_PATH" || warn "Failed to copy $RLOG from $POD"
          log "  copied: $LOCAL_PATH"; LOCAL_LOGS+=("$LOCAL_PATH")
        done <<< "$REMOTE_LOGS"
      fi
      kubectl_exec "$POD" sh -c "rm -f '${REMOTE_DIR}/mlogc_${RUN_ID}.pid' '${REMOTE_DIR}/mlogc_${RUN_ID}.pgid' '${RLOG}'/ 2>/dev/null || true" || true
    fi


      if [[ "$DO_PCAP" -eq 1 ]]; then
        # STOP VLB (sudo PGID/PID, then sudo pattern)
        safe_kubectl_exec "$POD" -- sh -c "
          PGIDFILE='${REMOTE_DIR}/mdp_pdump_${RUN_ID}.pgid'; PIDFILE='${REMOTE_DIR}/mdp_pdump_${RUN_ID}.pid'
          if [ -f \"\$PGIDFILE\" ]; then
            PGID=\$(cat \"\$PGIDFILE\" 2>/dev/null || true)
            if [ -n \"\$PGID\" ]; then
              sudo -n kill -INT \"-\$PGID\" 2>/dev/null || true
              i=0; while sudo -n kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
              sudo -n kill -TERM \"-\$PGID\" 2>/dev/null || true
              i=0; while sudo -n kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
              sudo -n kill -KILL \"-\$PGID\" 2>/dev/null || true
            fi
          elif [ -f \"\$PIDFILE\" ]; then
            PID=\$(cat \"\$PIDFILE\" 2>/dev/null || true)
            if [ -n \"\$PID\" ] && sudo -n kill -0 \"\$PID\" 2>/dev/null; then
              PGID=\"\$PID\"  # setsid -> PGID equals PID
              sudo -n kill -INT \"-\$PGID\" 2>/dev/null || true
              i=0; while sudo -n kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
              sudo -n kill -TERM \"-\$PGID\" 2>/dev/null || true
              i=0; while sudo -n kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
              sudo -n kill -KILL \"-\$PGID\" 2>/dev/null || true
            fi
          fi
        " || warn "sudo stop mdp_pdump interrupted."

        safe_kubectl_exec "$POD" -- sh -c "
          if command -v pkill >/dev/null 2>&1; then
            sudo -n pkill -f '${MDP_PDUMP_PATH} .* -w ${REMOTE_DIR}/' 2>/dev/null || true
          else
            for P in \$(sudo -n pgrep -f '${MDP_PDUMP_PATH} .* -w ${REMOTE_DIR}/' 2>/dev/null || true); do
              sudo -n kill -TERM \"\$P\" 2>/dev/null || true
            done
          fi
        " || warn "sudo pattern stop mdp_pdump interrupted."

        sleep 0.7  # flush

        # Copy .pcap & .pcapng
        REMOTE_PCAPS=$(kubectl_exec "$POD" sh -c "for f in '${REMOTE_DIR}'/*.pcap '${REMOTE_DIR}'/*.pcapng; do [ -e \"\$f\" ] && echo \"\$f\"; done 2>/dev/null || true")
        if [[ -n "$REMOTE_PCAPS" ]]; then
          while IFS= read -r RPCAP; do
            [[ -z "$RPCAP" ]] && continue
            BASENAME=$(basename "$RPCAP"); LOCAL_PATH="${RUN_OUT_DIR}/${BASENAME}"
            kubectl_cp_from_pod "$POD" "$RPCAP" "$LOCAL_PATH" || warn "Failed to copy $RPCAP from $POD"
            log "  copied: $LOCAL_PATH"; LOCAL_PCAPS+=("$LOCAL_PATH")
          done <<< "$REMOTE_PCAPS"
        else
          warn "  [VLB] no .pcap/.pcapng in ${REMOTE_DIR}"
        fi

        kubectl_exec "$POD" sh -c "rm -f '${REMOTE_DIR}/mdp_pdump_${RUN_ID}.pid' '${REMOTE_DIR}/mdp_pdump_${RUN_ID}.pgid' '${RPCAP}' 2>/dev/null || true" || true

		kubectl_exec "$POD" sh -c "rm -rf '${REMOTE_DIR_BASE}'/* 2>/dev/null || true" || true

      fi
      continue
    fi

    # Non-VLB stop: mlogc & tcpdump
    if [[ "$DO_LOG" -eq 1 ]]; then
      safe_kubectl_exec "$POD" -- sh -c "
        PGIDFILE='${REMOTE_DIR}/mlogc_${RUN_ID}.pgid'; PIDFILE='${REMOTE_DIR}/mlogc_${RUN_ID}.pid'
        if [ -f \"\$PGIDFILE\" ]; then
          PGID=\$(cat \"\$PGIDFILE\" 2>/dev/null || true)
          [ -n \"\$PGID\" ] && kill -TERM \"-\$PGID\" 2>/dev/null || true
          i=0; while kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
          kill -KILL \"-\$PGID\" 2>/dev/null || true
        elif [ -f \"\$PIDFILE\" ]; then
          PID=\$(cat \"\$PIDFILE\" 2>/dev/null || true)
          if [ -n \"\$PID\" ] && kill -0 \"\$PID\" 2>/dev/null; then
            PGID=\"\$PID\"
            kill -TERM \"-\$PGID\" 2>/dev/null || true
            i=0; while kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
            kill -KILL \"-\$PGID\" 2>/dev/null || true
          fi
        fi
      " || warn "stop mlogc interrupted."
      safe_kubectl_exec "$POD" -- sh -c "
        if command -v pkill >/dev/null 2>&1; then pkill -f '${MLOGC_PATH} ${MLOGC_ARGS}' 2>/dev/null || true;
        else for P in \$(pgrep -f '${MLOGC_PATH} ${MLOGC_ARGS}' 2>/dev/null || true); do kill -TERM \"\$P\" 2>/dev/null || true; done; fi
      " || warn "pattern stop mlogc interrupted."
      REMOTE_LOGS=$(kubectl_exec "$POD" sh -c "for f in '${REMOTE_DIR}'/*.log; do [ -e \"\$f\" ] && echo \"\$f\"; done 2>/dev/null || true")
      if [[ -n "$REMOTE_LOGS" ]]; then
        while IFS= read -r RLOG; do
          [[ -z "$RLOG" ]] && continue
          BASENAME=$(basename "$RLOG"); LOCAL_PATH="${RUN_OUT_DIR}/${BASENAME}"
          kubectl_cp_from_pod "$POD" "$RLOG" "$LOCAL_PATH" || warn "Failed to copy $RLOG from $POD"
          log "  copied: $LOCAL_PATH"; LOCAL_LOGS+=("$LOCAL_PATH")
        done <<< "$REMOTE_LOGS"
      fi
      kubectl_exec "$POD" sh -c "rm -f '${REMOTE_DIR}/mlogc_${RUN_ID}.pid' '${REMOTE_DIR}/mlogc_${RUN_ID}.pgid' '${RLOG}' 2>/dev/null || true" || true
    fi

    if [[ "$DO_PCAP" -eq 1 ]]; then
      safe_kubectl_exec "$POD" -- sh -c "
        PGIDFILE='${REMOTE_DIR}/tcpdump_${RUN_ID}.pgid'; PIDFILE='${REMOTE_DIR}/tcpdump_${RUN_ID}.pid'
        if [ -f \"\$PGIDFILE\" ]; then
          PGID=\$(cat \"\$PGIDFILE\" 2>/dev/null || true)
          [ -n \"\$PGID\" ] && kill -INT \"-\$PGID\" 2>/dev/null || true
          i=0; while kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
          kill -TERM \"-\$PGID\" 2>/dev/null || true
          i=0; while kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
          kill -KILL \"-\$PGID\" 2>/dev/null || true
        elif [ -f \"\$PIDFILE\" ]; then
          PID=\$(cat \"\$PIDFILE\" 2>/dev/null || true)
          if [ -n \"\$PID\" ] && kill -0 \"\$PID\" 2>/dev/null; then
            PGID=\"\$PID\"
            kill -INT \"-\$PGID\" 2>/dev/null || true
            i=0; while kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
            kill -TERM \"-\$PGID\" 2>/dev/null || true
            i=0; while kill -0 \"-\$PGID\" 2>/dev/null && [ \$i -lt 10 ]; do sleep 0.3; i=\$((i+1)); done
            kill -KILL \"-\$PGID\" 2>/dev/null || true
          fi
        fi
      " || warn "stop tcpdump interrupted."
      safe_kubectl_exec "$POD" -- sh -c "
        if command -v pkill >/dev/null 2>&1; then pkill -f 'tcpdump .* -w ${REMOTE_DIR}/' 2>/dev/null || true;
        else for P in \$(pgrep -f 'tcpdump .* -w ${REMOTE_DIR}/' 2>/dev/null || true); do kill -TERM \"\$P\" 2>/dev/null || true; done; fi
      " || warn "pattern stop tcpdump interrupted."
      REMOTE_PCAPS=$(kubectl_exec "$POD" sh -c "for f in '${REMOTE_DIR}'/*.pcap '${REMOTE_DIR}'/*.pcapng; do [ -e \"\$f\" ] && echo \"\$f\"; done 2>/dev/null || true")
      if [[ -n "$REMOTE_PCAPS" ]]; then
        while IFS= read -r RPCAP; do
          [[ -z "$RPCAP" ]] && continue
          BASENAME=$(basename "$RPCAP"); LOCAL_PATH="${RUN_OUT_DIR}/${BASENAME}"
          kubectl_cp_from_pod "$POD" "$RPCAP" "$LOCAL_PATH" || warn "Failed to copy $RPCAP from $POD"
          log "  copied: $LOCAL_PATH"; LOCAL_PCAPS+=("$LOCAL_PATH")
        done <<< "$REMOTE_PCAPS"
      fi

      kubectl_exec "$POD" sh -c "rm -f '${REMOTE_DIR}/tcpdump_${RUN_ID}.pid' '${REMOTE_DIR}/tcpdump_${RUN_ID}.pgid' '${RPCAP}' 2>/dev/null || true" || true
    fi

	kubectl_exec "$POD" sh -c "rm -rf '${REMOTE_DIR_BASE}'/* 2>/dev/null || true" || true

  done

  RUN_PHASE="done"

  echo ""
  log "Summary: local files in ${RUN_OUT_DIR}"
  find "$RUN_OUT_DIR" -maxdepth 1 -type f -printf "  - %f (%s bytes)\n" 2>/dev/null || ls -lh "$RUN_OUT_DIR"
}

########################################
# Signal traps
########################################
on_signal() {
  local sig="$1"
  if [[ "$RUN_PHASE" != "done" ]]; then
    log "[signal:$sig] Cleanup requested. Stopping captures and collecting files..."
    stop_and_collect_all
  fi
  release_lock
  case "$sig" in
    INT) exit 130 ;;
    TERM) exit 143 ;;
    HUP) exit 129 ;;
    *) exit 1 ;;
  esac
}
on_exit() {
  if [[ "$CLEANED" -eq 0 ]] && [[ "$RUN_PHASE" != "done" ]]; then
    stop_and_collect_all
  fi
  release_lock
}
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM
trap 'on_signal HUP' HUP
trap 'on_exit' EXIT

########################################
# Discover & Select
########################################
log "Discovering pods in namespace: $NAMESPACE"
ALL_PODS=$(run_kubectl -n "$NAMESPACE" get pods --no-headers -o custom-columns=NAME:.metadata.name | sed '/^[[:space:]]*$/d') || {
  err "Failed to list pods in namespace $NAMESPACE"; exit 1;
}

REGEX=""
if [[ -n "${POD_PATTERNS}" ]]; then
  IFS=',' read -r -a PAT_ARR <<< "$POD_PATTERNS"
  case "$MATCH_MODE" in
    strict_component) REGEX="^.+-($(join_alternation "${PAT_ARR[@]}"))-[0-9]+$" ;;
    prefix)
      REGEX="^(" ; for i in "${!PAT_ARR[@]}"; do REGEX+=$(regex_escape "${PAT_ARR[$i]}"); [[ $i -lt $((${#PAT_ARR[@]}-1)) ]] && REGEX+="|"; done
      REGEX+=")([.-]|$)"
      ;;
    substring)
      REGEX="(" ; for i in "${!PAT_ARR[@]}"; do REGEX+=$(regex_escape "${PAT_ARR[$i]}"); [[ $i -lt $((${#PAT_ARR[@]}-1)) ]] && REGEX+="|"; done
      REGEX+=")"
      ;;
    regex) REGEX="$POD_PATTERNS" ;;
    *) err "Unknown --match-mode '$MATCH_MODE'"; exit 1;;
  esac
  SELECTED_PODS=$(printf '%s\n' "$ALL_PODS" | grep -E "$REGEX" || true)

  if pods_contains_vlb_tag; then
    VLB_PODS=$(printf '%s\n' "$ALL_PODS" | grep_ci "$VLB_TAG" || true)
    [[ "$DEBUG" -eq 1 ]] && { log "[debug] VLB-tag union adds:"; printf '%s\n' "$VLB_PODS" | sed 's/^/  - /'; }
    SELECTED_PODS=$(printf '%s\n%s\n' "$SELECTED_PODS" "$VLB_PODS" | awk '!seen[$0]++')
  fi
else
  SELECTED_PODS="$ALL_PODS"
fi

TS=$(date +"$TIMESTAMP_FMT")

[[ "$DEBUG" -eq 1 ]] && {
  log "[debug] MATCH_MODE=$MATCH_MODE; POD_PATTERNS='${POD_PATTERNS:-<none>}' ; REGEX='${REGEX:-<none>}'"
  log "[debug] DO_LOG=$DO_LOG; DO_PCAP=$DO_PCAP; VLB_TAG='$VLB_TAG'; CONTAINER='${CONTAINER}'"
  log "[debug] RUN_ID=$RUN_ID; REMOTE_DIR=$REMOTE_DIR; RUN_OUT_DIR=$RUN_OUT_DIR; TS=$TS; SHORT_NAMES=$SHORT_NAMES; QUIET=$QUIET; DURATION=$DURATION; SUDO_START=$SUDO_START"
}

[[ -z "$SELECTED_PODS" ]] && { err "No pods matched the given criteria."; [[ -n "$REGEX" ]] && err "Regex used: $REGEX"; exit 1; }

log "Target pods:"
echo "$SELECTED_PODS" | sed 's/^/  - /'

########################################
# START phase
########################################

RUN_PHASE="started"

for POD in $SELECTED_PODS; do
  log "Initializing in pod: $POD"
  kubectl_exec "$POD" sh -c "mkdir -p '$REMOTE_DIR'" || { err "Failed to prepare remote dir in $POD"; continue; }
  

  if is_vlb_pod "$POD"; then
    [[ "$DO_LOG" -eq 1 ]] && log "  [VLB] IMS Logs are not required for VLB pods; no IMS log will be started in $POD"
    
	ACTIVE=$(kubectl_exec "$POD" sh -c "readShm | grep vnfcHAMode | grep -q ACTIVE && echo ACTIVE || echo INACTIVE" 2>/dev/null || echo INACTIVE)
    
	if [[ "$ACTIVE" != "ACTIVE" ]]; then
  		log "  [VLB] HA mode not ACTIVE in $POD; skipping mdp debug enable and VLB log start."
  		continue
	fi
 
	 if [[ "${DO_VLB_LOG:-0}" -eq 1 ]]; then

        if [[ "$SHORT_NAMES" -eq 1 ]]; then base="$(compact_basename "$POD" "$TS")"; LOG_FILE="${REMOTE_DIR}/${base}.log"; else LOG_FILE="${REMOTE_DIR}/${PREFIX}_${POD}_${TS}.log"; fi
      # Decide remote output file for UPA.log

      # Set mdp log level to DEBUG inside the VLB pod
      VPPCTL_BIN_IN_POD="${VPPCTL_BIN:-/usr/local/mnvpp-pkg/bin/vppctl}"

      kubectl_exec "$POD" sh -c "
        if [ -x '${VPPCTL_BIN_IN_POD}' ]; then
          $(sudo_prefix) '${VPPCTL_BIN_IN_POD}' set mdp log level debug || true
        else
          echo 'WARN: vppctl not found at ${VPPCTL_BIN_IN_POD}' >&2
        fi
      " || warn "Failed to set MDP log level to debug in $POD"
      log "  [VLB] MDP log level -> debug"

      # Start tail -F of UPA.log; record PID/PGID files
      kubectl_exec "$POD" sh -c "
        if [ -r '/data/storage/log/UPA.log' ]; then
          nohup setsid $(sudo_prefix) tail -F '/data/storage/log/UPA.log' >> '${LOG_FILE}' 2>&1 &
          pid=\$!; echo \"\$pid\" > '${REMOTE_DIR}/UPA_tail_${RUN_ID}.pid'
          echo \"\$pid\" > '${REMOTE_DIR}/UPA_tail_${RUN_ID}.pgid'   # PGID == PID (setsid leader)
        else
          echo 'WARN: /data/storage/log/UPA.log not readable' > '${REMOTE_DIR}/UPA_tail_${RUN_ID}.out'
        fi
      " || warn "Failed to start UPA.log tail in $POD"
      log "  [VLB] UPA.log -> ${LOG_FILE}"
    fi

    if [[ "$DO_PCAP" -eq 1 ]]; then
      if [[ "$SHORT_NAMES" -eq 1 ]]; then base="$(compact_basename "$POD" "$TS")"; PCAP_FILE="${REMOTE_DIR}/${base}.pcap"; else PCAP_FILE="${REMOTE_DIR}/${PREFIX}_${POD}_${TS}.pcap"; fi

      # PRE-START: kill any mdp_pdump (sudo)
      kubectl_exec "$POD" sh -c "
        if command -v pkill >/dev/null 2>&1; then
          $(sudo_prefix) pkill -f '${MDP_PDUMP_PATH}' 2>/dev/null || true
        else
          for P in \$(pgrep -f '${MDP_PDUMP_PATH}' 2>/dev/null || true); do
            $(sudo_prefix) kill -TERM \"\$P\" 2>/dev/null || true
          done
        fi
      " || warn "Pre-start mdp_pdump kill interrupted."
      sleep 0.3

      kubectl_exec "$POD" sh -c "
        nohup setsid $(sudo_prefix) '${MDP_PDUMP_PATH}' -i all -w '${PCAP_FILE}' > '${REMOTE_DIR}/mdp_pdump_${RUN_ID}.out' 2>&1 &
        pid=\$!; echo \"\$pid\" > '${REMOTE_DIR}/mdp_pdump_${RUN_ID}.pid'
        echo \"\$pid\" > '${REMOTE_DIR}/mdp_pdump_${RUN_ID}.pgid'   # PGID == PID (setsid leader)
      " || { err "Failed to start mdp_pdump in $POD (VLB pcap)"; }
      log "  [VLB] mdp_pdump -> $PCAP_FILE"
    fi
    continue
  fi

  # Non-VLB
  if [[ "$DO_LOG" -eq 1 ]]; then
    kubectl_exec "$POD" sh -c "command -v '$MLOGC_PATH' >/dev/null 2>&1 || [ -x '$MLOGC_PATH' ]" || { err "mlogc not found in $POD at $MLOGC_PATH"; continue; }
    if [[ "$SHORT_NAMES" -eq 1 ]]; then base="$(compact_basename "$POD" "$TS")"; LOG_FILE="${REMOTE_DIR}/${base}.log"; else LOG_FILE="${REMOTE_DIR}/${PREFIX}_${POD}_${TS}.log"; fi
    kubectl_exec "$POD" sh -c "
      nohup setsid $(sudo_prefix) '$MLOGC_PATH' $MLOGC_ARGS > '$LOG_FILE' 2>&1 &
      pid=\$!; echo \"\$pid\" > '${REMOTE_DIR}/mlogc_${RUN_ID}.pid'
      echo \"\$pid\" > '${REMOTE_DIR}/mlogc_${RUN_ID}.pgid'
    " || { err "Failed to start mlogc in $POD"; }
    log "  mlogc -> $LOG_FILE"
  fi

  if [[ "$DO_PCAP" -eq 1 ]]; then
    if [[ "$SHORT_NAMES" -eq 1 ]]; then base="$(compact_basename "$POD" "$TS")"; PCAP_FILE="${REMOTE_DIR}/${base}.pcap"; else PCAP_FILE="${REMOTE_DIR}/${PREFIX}_${POD}_${TS}.pcap"; fi
    kubectl_exec "$POD" sh -c "
      nohup setsid $(sudo_prefix) $PCAP_BASE_CMD -w '$PCAP_FILE' > '${REMOTE_DIR}/tcpdump_${RUN_ID}.out' 2>&1 &
      pid=\$!; echo \"\$pid\" > '${REMOTE_DIR}/tcpdump_${RUN_ID}.pid'
      echo \"\$pid\" > '${REMOTE_DIR}/tcpdump_${RUN_ID}.pgid'
    " || { err "Failed to start tcpdump in $POD (pcap)"; }
    log "  tcpdump -> $PCAP_FILE"
  fi
done



########################################
# Auto-stop scheduling (if requested)
########################################
if [[ "$DURATION" -gt 0 ]]; then
  log "Auto-stop scheduled after ${DURATION}s..."
  PARENT_PID=$$
  ( sleep "$DURATION"; kill -HUP "$PARENT_PID" 2>/dev/null || true ) & TIMER_PID=$!
fi

########################################
# Stop: interactive or timed
########################################
if [[ "$DURATION" -eq 0 ]]; then
  echo ""
  read -r -p "-> Press 's' + Enter to stop and collect files: " STOP
  if [[ "$STOP" != "s" ]]; then
    echo "Aborting: you did not press 's'. Initiating cleanup..."
  fi
fi

########################################
# STOP & COLLECT phase
########################################
stop_and_collect_all

########################################
# Merge pcaps (optional)
########################################
if [[ "$MERGE" -eq 1 ]]; then
  if [[ "${#LOCAL_PCAPS[@]}" -eq 0 ]]; then
    log "Merge requested, but no local pcap files were collected."
  else
    TS_COMBINED=$(date +"$TIMESTAMP_FMT")
    [[ -z "$COMBINED_NAME" ]] && COMBINED_NAME="${PREFIX}_combined_${TS_COMBINED}_${RUN_ID}.pcap"
    COMBINED_PATH="${RUN_OUT_DIR}/${COMBINED_NAME}"
    log "Merging ${#LOCAL_PCAPS[@]} pcap(s) into: ${COMBINED_PATH}"

    MERGE_FLAGS=()
    [[ "$MERGE_APPEND" -eq 1 ]] && MERGE_FLAGS+=("-a")
    if [[ -n "$MERGE_FORCE_FORMAT" ]]; then
      case "$MERGE_FORCE_FORMAT" in
        pcap|pcapng) MERGE_FLAGS+=("-F" "$MERGE_FORCE_FORMAT");;
        *) err "Unknown --merge-format '$MERGE_FORCE_FORMAT' (use 'pcap' or 'pcapng')";;
      esac
    fi

    if command -v mergecap >/dev/null 2>&1; then
      if ! mergecap "${MERGE_FLAGS[@]}" -w "$COMBINED_PATH" "${LOCAL_PCAPS[@]}"; then
        err "mergecap failed; attempting fallback concatenation (packets may be out-of-order; pcapng may be invalid)."
        cat "${LOCAL_PCAPS[@]}" > "$COMBINED_PATH" || err "Concatenation failed."
      fi
    else
      err "mergecap not found. Install Wireshark CLI (mergecap)."
      log "Attempting fallback concatenation (not timestamp-aware; pcapng may be invalid)."
      cat "${LOCAL_PCAPS[@]}" > "$COMBINED_PATH" || err "Concatenation failed."
    fi

    [[ -s "$COMBINED_PATH" ]] && log "Merged pcap ready: ${COMBINED_PATH}" || err "Combined file empty or missing: ${COMBINED_PATH}"
  fi
fi

