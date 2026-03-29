#!/usr/bin/env bash
# docker.sh — Docker container health summary
#
# Output:  "  Docker:    N/N up"
#          "             stopped: svc1, svc2"       (Exited 0 — clean, no ⚠)
#          "             crashed: svc1 exit 1 ⚠"   (non-zero exit / unhealthy / dead)
#
# Service name resolution: for Compose containers, uses the
# com.docker.compose.project + com.docker.compose.service labels
# (e.g. "minecraft/mc"). Falls back to the container name if no labels.
#
# Test:    sudo bash checks/docker.sh
# Always exits 0.

set -euo pipefail

if ! command -v docker &>/dev/null; then
  printf "  %-8s   docker not found\n" "Docker:"
  exit 0
fi

CONTAINERS=$(docker ps -a --format '{{.Names}}\t{{.Status}}' 2>/dev/null) || {
  printf "  %-8s   error querying containers\n" "Docker:"
  exit 0
}

if [[ -z "$CONTAINERS" ]]; then
  printf "  %-8s   no containers\n" "Docker:"
  exit 0
fi

# Helper: resolve a human-readable service name for a container.
# Returns "project/service" if Compose labels exist, else the container name.
# Single inspect call to avoid two subprocesses per container.
service_name() {
  local cname="$1"
  local result
  result=$(docker inspect --format \
    '{{index .Config.Labels "com.docker.compose.project"}}	{{index .Config.Labels "com.docker.compose.service"}}' \
    "$cname" 2>/dev/null || true)
  local project="${result%%	*}"
  local service="${result##*	}"
  if [[ -n "$project" && -n "$service" ]]; then
    echo "${project}/${service}"
  else
    echo "$cname"
  fi
}

TOTAL=0; RUNNING=0
STOPPED_NAMES=()
PROBLEM_NAMES=()

while IFS=$'\t' read -r name status; do
  (( TOTAL++ )) || true
  if [[ "$status" == Up* ]]; then
    if [[ "$status" == *"(unhealthy)"* ]]; then
      svc=$(service_name "$name")
      PROBLEM_NAMES+=("${svc} unhealthy")
    else
      (( RUNNING++ )) || true
    fi
  elif [[ "$status" == "Exited (0)"* ]]; then
    svc=$(service_name "$name")
    STOPPED_NAMES+=("$svc")
  elif [[ "$status" == Exited* ]]; then
    EXIT_CODE=$(echo "$status" | grep -oP '(?<=Exited \()\d+(?=\))' || echo "?")
    svc=$(service_name "$name")
    PROBLEM_NAMES+=("${svc} crashed exit ${EXIT_CODE}")
  elif [[ "$status" == Dead* ]]; then
    svc=$(service_name "$name")
    PROBLEM_NAMES+=("${svc} dead")
  else
    (( RUNNING++ )) || true
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
