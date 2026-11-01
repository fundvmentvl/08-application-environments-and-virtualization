#!/usr/bin/env bash
# Run on the Mac host. Creates, retrieves and cancels its own test reservation.
set -euo pipefail
BASE=${1:-}
BASE=${BASE%/}
[[ "$BASE" =~ ^https?:// ]] || { echo "Usage: bash $0 http://GUEST_IP:8080" >&2; exit 2; }
command -v jq >/dev/null || { echo 'jq is required.' >&2; exit 1; }
WORK=$(mktemp -d "${TMPDIR:-/tmp}/cen4025-http.XXXXXX")
RID=''
request() {
  local method=$1 path=$2 expected=$3 payload=${4-} status
  if [[ -n "$payload" ]]; then
    status=$(curl --silent --show-error --max-time 20 -o "$WORK/body" -w '%{http_code}' -X "$method" -H 'Content-Type: application/json' --data "$payload" "$BASE$path")
  else
    status=$(curl --silent --show-error --max-time 20 -o "$WORK/body" -w '%{http_code}' -X "$method" "$BASE$path")
  fi
  printf '%s %s => HTTP %s\n' "$method" "$BASE$path" "$status"
  cat "$WORK/body"; printf '\n'
  [[ "$status" == "$expected" ]] || { echo "Expected HTTP $expected" >&2; return 1; }
}
cleanup() {
  if [[ -n "$RID" ]]; then
    echo "Cleaning up test reservation $RID" >&2
    curl --silent --show-error --max-time 10 -X DELETE "$BASE/api/reservations/$RID" >&2 || true
  fi
}
trap cleanup EXIT
printf 'Host verification %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
request GET /api/appointments 200
SLOT=$(jq -er '.[0].id' "$WORK/body")
PAYLOAD=$(jq -n --arg slot "$SLOT" '{slotId:$slot,customerName:"Assignment 8 Automated Verification"}')
request POST /api/reservations 201 "$PAYLOAD"
RID=$(jq -er '.id' "$WORK/body")
request GET "/api/reservations/$RID" 200
jq -e --arg rid "$RID" --arg slot "$SLOT" '.id==$rid and .appointmentSlotId==$slot' "$WORK/body" >/dev/null
request DELETE "/api/reservations/$RID" 204
RID=''
request GET /api/appointments 200
jq -e --arg slot "$SLOT" 'any(.[]; .id==$slot)' "$WORK/body" >/dev/null
echo 'ALL HTTP CHECKS PASSED'
echo "Raw final response retained at $WORK/body"
