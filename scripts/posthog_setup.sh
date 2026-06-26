#!/usr/bin/env bash
#
# posthog_setup.sh — create a dedicated PostHog project for QuickEdit and
# seed the feature flags the app depends on, then print the new project's
# write key (phc_…) so it can be dropped into Info.plist.
#
# Requirements:
#   - POSTHOG_PERSONAL_API_KEY : a PostHog *personal* API key (starts with phx_)
#       Create one at: <host>/settings/user-api-keys
#       It must have scopes: project:write and feature_flag:write
#
# Usage:
#   POSTHOG_PERSONAL_API_KEY=phx_xxx ./scripts/posthog_setup.sh
#   # optional overrides:
#   POSTHOG_API_HOST=https://us.posthog.com \
#   POSTHOG_ORG=@current \
#   PROJECT_NAME=QuickEdit \
#   POSTHOG_PERSONAL_API_KEY=phx_xxx ./scripts/posthog_setup.sh
#
set -euo pipefail

API_HOST="${POSTHOG_API_HOST:-https://us.posthog.com}"   # US cloud API/app host (NOT the i. ingestion host)
ORG="${POSTHOG_ORG:-@current}"
PROJECT_NAME="${PROJECT_NAME:-QuickEdit}"

# Feature flags the app reads (see FeatureFlagManager.swift). Created disabled
# (0% rollout); the payload flag's JSON payload can be set afterwards in the UI.
FLAG_KEYS=(pinned_mode stop_mode_leave_partial autocontext_demo_video_url)

if [[ -z "${POSTHOG_PERSONAL_API_KEY:-}" ]]; then
  echo "❌ POSTHOG_PERSONAL_API_KEY is not set." >&2
  echo "   Create a personal API key (scopes: project:write, feature_flag:write) at:" >&2
  echo "   ${API_HOST}/settings/user-api-keys" >&2
  echo "   Then re-run:  POSTHOG_PERSONAL_API_KEY=phx_xxx $0" >&2
  exit 2
fi

AUTH=(-H "Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}")
JSON=(-H "Content-Type: application/json")

api() {
  # api METHOD PATH [JSON_BODY]
  local method="$1" path="$2" body="${3:-}"
  if [[ -n "$body" ]]; then
    curl -sS -X "$method" "${API_HOST}${path}" "${AUTH[@]}" "${JSON[@]}" -d "$body"
  else
    curl -sS -X "$method" "${API_HOST}${path}" "${AUTH[@]}" "${JSON[@]}"
  fi
}

echo "🏗  Creating project '${PROJECT_NAME}' in org ${ORG} on ${API_HOST}…" >&2
PROJECT_RESP="$(api POST "/api/organizations/${ORG}/projects/" "{\"name\":\"${PROJECT_NAME}\"}")"

read -r PROJECT_ID API_TOKEN <<EOF
$(printf '%s' "$PROJECT_RESP" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("PARSE_ERROR", e, file=sys.stderr); sys.exit(1)
if "id" not in d or "api_token" not in d:
    print("API_ERROR:", json.dumps(d), file=sys.stderr); sys.exit(1)
print(d["id"], d["api_token"])
')
EOF

if [[ -z "${PROJECT_ID:-}" || -z "${API_TOKEN:-}" ]]; then
  echo "❌ Project creation failed. Raw response:" >&2
  echo "$PROJECT_RESP" >&2
  exit 1
fi
echo "✅ Project created: id=${PROJECT_ID}" >&2

for key in "${FLAG_KEYS[@]}"; do
  echo "🚩 Creating feature flag '${key}' (disabled)…" >&2
  body="$(python3 -c '
import json, sys
key = sys.argv[1]
print(json.dumps({
    "key": key,
    "name": key,
    "active": True,
    "filters": {"groups": [{"properties": [], "rollout_percentage": 0}]},
}))' "$key")"
  resp="$(api POST "/api/projects/${PROJECT_ID}/feature_flags/" "$body")"
  printf '%s' "$resp" | python3 -c '
import sys, json
d = json.load(sys.stdin)
if "key" in d:
    print("   ok ->", d["key"], "(id", str(d.get("id"))+")", file=sys.stderr)
else:
    print("   ⚠️  could not create:", json.dumps(d), file=sys.stderr)
'
done

echo >&2
echo "════════════════════════════════════════════════════════════════" >&2
echo "✅ Done. New QuickEdit project write key (set as PostHogApiKey):" >&2
echo "$API_TOKEN"
echo "════════════════════════════════════════════════════════════════" >&2
echo "Next: I'll swap this phc_ key into macos/OnitQuickEdit/Info.plist." >&2
