#!/usr/bin/env bash
# docker.sh — Docker container health summary
#
# Output:  "  Docker:    N/N up"
#          "             stopped: svc1, svc2"       (Exited 0 / Created — no ⚠)
#          "             crashed: svc1 exit 1 ⚠"   (non-zero exit / unhealthy /
#                                                    restarting / paused / dead /
#                                                    unknown state)
#
# Service name resolution: for Compose containers, uses the
# com.docker.compose.project + com.docker.compose.service labels
# (e.g. "minecraft/mc"), fetched in the same docker ps call.
# Falls back to the container name if no labels.
#
# Test:    sudo bash checks/docker.sh
# Always exits 0.

set -euo pipefail

if ! command -v docker &>/dev/null; then
  printf "  %-8s   docker not found\n" "Docker:"
  exit 0
fi

CONTAINERS=$(docker ps -a --format \
  '{{.Names}}\t{{.Status}}\t{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.service"}}' \
  2>/dev/null) || {
  printf "  %-8s   error querying containers\n" "Docker:"
  exit 0
}

if [[ -z "$CONTAINERS" ]]; then
  printf "  %-8s   no containers\n" "Docker:"
  exit 0
fi

TOTAL=0; RUNNING=0
STOPPED_NAMES=()
PROBLEM_NAMES=()

while IFS=$'\t' read -r name status project service; do
  (( TOTAL++ )) || true
  svc="$name"
  [[ -n "$project" && -n "$service" ]] && svc="${project}/${service}"

  if [[ "$status" == Up* ]]; then
    if [[ "$status" == *"(unhealthy)"* ]]; then
      PROBLEM_NAMES+=("${svc} unhealthy")
    elif [[ "$status" == *"(Paused)"* ]]; then
      PROBLEM_NAMES+=("${svc} paused")
    else
      (( RUNNING++ )) || true
    fi
  elif [[ "$status" == "Exited (0)"* ]]; then
    STOPPED_NAMES+=("$svc")
  elif [[ "$status" == Exited* ]]; then
    EXIT_CODE=$(echo "$status" | grep -oP '(?<=Exited \()\d+(?=\))' || echo "?")
    PROBLEM_NAMES+=("${svc} crashed exit ${EXIT_CODE}")
  elif [[ "$status" == Created* ]]; then
    STOPPED_NAMES+=("${svc} (never started)")
  elif [[ "$status" == Restarting* ]]; then
    PROBLEM_NAMES+=("${svc} restarting")
  elif [[ "$status" == Dead* ]]; then
    PROBLEM_NAMES+=("${svc} dead")
  else
    # Unknown state — surface it rather than silently counting as up
    PROBLEM_NAMES+=("${svc} ${status}")
  fi
done <<< "$CONTAINERS"

# 13 spaces aligns continuation lines under the value column (2 + 8 label + 3 sep)
INDENT="             "

printf "  %-8s   %s\n" "Docker:" "${RUNNING}/${TOTAL} up"

if [[ ${#PROBLEM_NAMES[@]} -gt 0 ]]; then
  NAMES_STR=$(printf '%s, ' "${PROBLEM_NAMES[@]}")
  NAMES_STR="${NAMES_STR%, }"
  printf "%scrashed: %s ⚠\n" "$INDENT" "$NAMES_STR"
fi

if [[ ${#STOPPED_NAMES[@]} -gt 0 ]]; then
  STOPPED_STR=$(printf '%s, ' "${STOPPED_NAMES[@]}")
  STOPPED_STR="${STOPPED_STR%, }"
  printf "%sstopped: %s\n" "$INDENT" "$STOPPED_STR"
fi
