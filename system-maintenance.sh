#!/bin/bash

set -uo pipefail

LOGFILE="$HOME/maintenance-$(date +%F-%H%M%S).log"
STATE_FILE=$(mktemp)
: > "$LOGFILE"

STEPS=(
  "Update package lists"
  "Full upgrade"
  "Fix broken installs"
  "Configure dpkg"
  "Autoremove"
  "Clean cache"
  "Purge rc packages"
  "User cache cleanup"
  "Journal cleanup (7d)"
)

WEIGHTS=(5 40 5 5 15 5 5 5 15)
TOTAL=${#STEPS[@]}
CW=48   # dashboard inner content width

declare -a STATUS_ARR
for ((i=0; i<TOTAL; i++)); do STATUS_ARR[$i]="waiting"; done

SPIN_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

GREEN=$(tput setaf 2);  RED=$(tput setaf 1); YELLOW=$(tput setaf 3)
GRAY=$(tput setaf 8);   CYAN=$(tput setaf 6); BOLD=$(tput bold); RESET=$(tput sgr0)

START_TIME=$(date +%s)
CURRENT_IDX=0
STEP_START=$START_TIME
PKG_CUR=0
PKG_TOTAL=0
HAS_FAILED=0
ABORTED=0
CURRENT_CMD_PID=""

fmt_time() {
  local s=$1
  printf '%02d:%02d:%02d' $((s/3600)) $(((s%3600)/60)) $((s%60))
}

border() {
  local left=$1 mid=$2 right=$3
  printf '%s' "$left"
  printf -- '─%.0s' $(seq 1 "$CW")
  printf '%s\n' "$right"
}

write_state() {
  local tmp
  tmp=$(mktemp)
  {
    echo "CURRENT_IDX=$CURRENT_IDX"
    echo "CURRENT_TASK=\"${STEPS[$CURRENT_IDX]:-Done}\""
    echo "STEP_START=$STEP_START"
    for ((i=0; i<TOTAL; i++)); do
      echo "STATUS_$i=${STATUS_ARR[$i]}"
    done
    echo "PKG_CUR=$PKG_CUR"
    echo "PKG_TOTAL=$PKG_TOTAL"
    echo "HAS_FAILED=$HAS_FAILED"
    echo "ABORTED=$ABORTED"
  } > "$tmp"
  mv "$tmp" "$STATE_FILE"
}
write_state

renderer() {
  local spin_i=0
  while true; do
    if [ -f "$STATE_FILE" ]; then
      # shellcheck disable=SC1090
      source "$STATE_FILE" 2>/dev/null
    fi

    local now elapsed step_elapsed
    now=$(date +%s)
    elapsed=$((now - START_TIME))
    step_elapsed=$((now - STEP_START))

    # --- overall progress: completed weight + asymptotic fraction of current step
    local completed_w=0
    for ((i=0; i<CURRENT_IDX && i<TOTAL; i++)); do completed_w=$((completed_w + WEIGHTS[i])); done
    local cur_w=0
    [ "$CURRENT_IDX" -lt "$TOTAL" ] && cur_w=${WEIGHTS[$CURRENT_IDX]}
    local tc=$(( cur_w < 3 ? 3 : cur_w ))
    local pct
    pct=$(awk -v cw="$completed_w" -v curw="$cur_w" -v t="$step_elapsed" -v tc="$tc" -v cap=100 \
      'BEGIN{ f=1-exp(-t/tc); if (f>0.92) f=0.92; v=cw+curw*f; if (v>cap) v=cap; printf "%d", v }')
    [ "$CURRENT_IDX" -ge "$TOTAL" ] && pct=100

    local barlen=30
    local filled=$(( pct * barlen / 100 ))
    local bar="" j
    for ((j=0; j<filled; j++)); do bar+="█"; done
    for ((j=filled; j<barlen; j++)); do bar+="░"; done

    spin_i=$(( (spin_i + 1) % 10 ))
    local spin="${SPIN_FRAMES[$spin_i]}"

    # --- bar color: green while filling, cyan on clean completion,
    #     red if any step failed or the run was aborted (Ctrl+C)
    local bar_color status_suffix
    if [ "${ABORTED:-0}" = "1" ]; then
      bar_color="$RED"
      status_suffix="  ABORTED"
    elif [ "${HAS_FAILED:-0}" = "1" ]; then
      bar_color="$RED"
      status_suffix=""
    elif [ "$pct" -ge 100 ]; then
      bar_color="$CYAN"
      status_suffix=""
    else
      bar_color="$GREEN"
      status_suffix=""
    fi

    tput cup 0 0

    border "╭" "" "╮"
    printf "│%s%-*.*s%s│\n" "$BOLD" "$CW" "$CW" "Maintenance" "$RESET"
    border "├" "" "┤"

    printf -v line "Current task : %s" "${CURRENT_TASK:-}"
    printf "│%-*.*s│\n" "$CW" "$CW" "$line"

    printf -v line "Runtime      : %s" "$(fmt_time "$elapsed")"
    printf "│%-*.*s│\n" "$CW" "$CW" "$line"

    if [ "${PKG_TOTAL:-0}" -gt 0 ]; then
      printf -v line "Packages     : %s/%s" "${PKG_CUR:-0}" "${PKG_TOTAL:-0}"
    else
      printf -v line "Packages     : -"
    fi
    printf "│%-*.*s│\n" "$CW" "$CW" "$line"

    border "├" "" "┤"

    for ((i=0; i<TOTAL; i++)); do
      local st_var="STATUS_$i"
      local st="${!st_var:-waiting}"
      local icon color
      case "$st" in
        done)    icon="✔"; color="$GREEN"  ;;
        running) icon="$spin"; color="$YELLOW" ;;
        failed)  icon="✗"; color="$RED"    ;;
        *)       icon="•"; color="$GRAY"   ;;
      esac
      local plain padded
      plain="$icon ${STEPS[$i]}"
      printf -v padded "%-*.*s" "$CW" "$CW" "$plain"
      printf "│ %s%s%s │\n" "$color" "$padded" "$RESET"
    done

    border "├" "" "┤"

    local plain_bar padded_bar
    plain_bar=$(printf "%s %3d%%%s" "$bar" "$pct" "$status_suffix")
    printf -v padded_bar "%-*.*s" "$CW" "$CW" "$plain_bar"
    printf "│%s%s%s                                │\n" "$bar_color" "$padded_bar" "$RESET"

    border "╰" "" "╯"

    sleep 0.1
  done
}

run_step() {
  local idx=$1; shift
  CURRENT_IDX=$idx
  STEP_START=$(date +%s)
  STATUS_ARR[$idx]="running"
  PKG_CUR=0; PKG_TOTAL=0
  write_state

  local logsize_before
  logsize_before=$(wc -l < "$LOGFILE" 2>/dev/null || echo 0)

  local mode=""
  case $idx in
    1) mode="upgrade" ;;
    4) mode="autoremove" ;;
  esac

  if [ "$mode" = "upgrade" ]; then
    PKG_TOTAL=$(sudo apt-get full-upgrade -s 2>/dev/null | grep -c '^Inst' || true)
  elif [ "$mode" = "autoremove" ]; then
    PKG_TOTAL=$(sudo apt-get autoremove --purge -s 2>/dev/null | grep -c '^Remv' || true)
  fi
  write_state

  {
    echo "=== ${STEPS[$idx]} ==="
    "$@"
  } >> "$LOGFILE" 2>&1 &
  local cmd_pid=$!
  CURRENT_CMD_PID=$cmd_pid

  if [ -n "$mode" ]; then
    while kill -0 "$cmd_pid" 2>/dev/null; do
      if [ "$mode" = "upgrade" ]; then
        PKG_CUR=$(tail -n +"$((logsize_before + 1))" "$LOGFILE" 2>/dev/null | grep -c '^Setting up' || true)
      else
        PKG_CUR=$(tail -n +"$((logsize_before + 1))" "$LOGFILE" 2>/dev/null | grep -c '^Removing' || true)
      fi
      write_state
      sleep 0.3
    done
  fi

  wait "$cmd_pid"
  local rc=$?
  CURRENT_CMD_PID=""

  if [ "$rc" -eq 0 ]; then
    STATUS_ARR[$idx]="done"
    [ -n "$mode" ] && PKG_CUR=$PKG_TOTAL
  else
    STATUS_ARR[$idx]="failed"
    HAS_FAILED=1
  fi
  write_state
  return $rc
}

cleanup() {
  [ -n "${RENDER_PID:-}" ] && kill "$RENDER_PID" 2>/dev/null
  [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
  tput cnorm
  rm -f "$STATE_FILE"
}
trap cleanup EXIT

on_interrupt() {
  ABORTED=1
  [ "$CURRENT_IDX" -lt "$TOTAL" ] && STATUS_ARR[$CURRENT_IDX]="failed"
  write_state
  sleep 0.3   # let the renderer draw the red/aborted frame before we tear down

  [ -n "$CURRENT_CMD_PID" ] && kill "$CURRENT_CMD_PID" 2>/dev/null

  cleanup
  trap - EXIT
  echo
  echo "${RED}=== MAINTENANCE ABORTED (Ctrl+C) ===${RESET}"
  echo "Log saved to: $LOGFILE"
  exit 130
}
trap on_interrupt INT

# Cache sudo credentials up front so the password prompt doesn't collide
echo "Requesting sudo access (needed for the whole run)..."
sudo -v
(
  while true; do
    sudo -n true 2>/dev/null
    sleep 60
    kill -0 "$$" 2>/dev/null || exit
  done
) &
SUDO_KEEPALIVE_PID=$!

clear
tput civis
renderer &
RENDER_PID=$!

FAILED_STEPS=()

run_step 0 sudo apt-get update                          || FAILED_STEPS+=(0)
run_step 1 sudo apt-get full-upgrade -y                  || FAILED_STEPS+=(1)
run_step 2 sudo apt-get install --fix-broken -y           || FAILED_STEPS+=(2)
run_step 3 sudo dpkg --configure -a                       || FAILED_STEPS+=(3)
run_step 4 sudo apt-get autoremove --purge -y             || FAILED_STEPS+=(4)
run_step 5 sudo apt-get clean                              || FAILED_STEPS+=(5)
run_step 6 bash -c '
  RC_PKGS=$(dpkg -l | awk "/^rc/ {print \$2}")
  if [ -n "$RC_PKGS" ]; then
    echo "$RC_PKGS" | xargs -r sudo dpkg --purge
  else
    echo "No rc packages found"
  fi
'                                                          || FAILED_STEPS+=(6)
run_step 7 bash -c 'rm -rf "$HOME/.cache/"*'               || FAILED_STEPS+=(7)
run_step 8 sudo journalctl --vacuum-time=7d                || FAILED_STEPS+=(8)

CURRENT_IDX=$TOTAL
write_state
sleep 0.3

trap - INT
kill "$RENDER_PID" 2>/dev/null
RENDER_PID=""
tput cnorm

echo
echo "=== MAINTENANCE COMPLETE ==="
echo "Total time  : $(fmt_time $(( $(date +%s) - START_TIME )))"
echo "Log saved to: $LOGFILE"

if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
  echo
  echo "The following steps reported errors (see log for details):"
  for i in "${FAILED_STEPS[@]}"; do
    echo "  - ${STEPS[$i]}"
  done
fi
