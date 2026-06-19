#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Job-Tracker-Info.plist"
ENTITLEMENTS="$ROOT_DIR/Job Tracker/Job Tracker.entitlements"
CARPLAY_DOC="$ROOT_DIR/Documentation/CarPlayEntitlementRequest.md"
DELEGATE="$ROOT_DIR/Job Tracker/Features/CarPlay/JobDispatchCarPlaySceneDelegate.swift"
SERVICE="$ROOT_DIR/Job Tracker/Features/CarPlay/CarPlayJobDispatchService.swift"

fail() {
  echo "❌ $1" >&2
  exit 1
}

pass() {
  echo "✅ $1"
}

[[ -f "$INFO_PLIST" ]] || fail "Missing app Info.plist"
[[ -f "$ENTITLEMENTS" ]] || fail "Missing app entitlements file"
[[ -f "$CARPLAY_DOC" ]] || fail "Missing CarPlay entitlement request packet"
[[ -f "$DELEGATE" ]] || fail "Missing CarPlay scene delegate"
[[ -f "$SERVICE" ]] || fail "Missing CarPlay dispatch service"

/usr/bin/python3 - <<PY
import plistlib
from pathlib import Path
for path in [Path(r"$INFO_PLIST"), Path(r"$ENTITLEMENTS")]:
    with path.open("rb") as fh:
        plistlib.load(fh)
PY
pass "Info.plist and entitlements plist files parse successfully"

rg -q "CPTemplateApplicationSceneSessionRoleApplication" "$INFO_PLIST" \
  || fail "Info.plist does not register the CarPlay scene session role"
rg -q "JobDispatchCarPlaySceneDelegate" "$INFO_PLIST" \
  || fail "Info.plist does not point to JobDispatchCarPlaySceneDelegate"
pass "CarPlay scene is registered in Info.plist"

rg -q "com\.apple\.developer\.carplay-driving-task" "$ENTITLEMENTS" \
  || fail "Approved CarPlay Driving Task entitlement is missing from app entitlements"
pass "Approved CarPlay Driving Task entitlement is embedded"

if /usr/bin/python3 - <<PY
import plistlib
from pathlib import Path
info = plistlib.loads(Path(r"$INFO_PLIST").read_bytes())
for key in ["OPENAI_API_KEY", "GEMINI_API_KEY"]:
    value = info.get(key, "")
    if isinstance(value, str) and value.strip():
        raise SystemExit(1)
PY
then
  pass "Info.plist does not contain hard-coded AI service credentials"
else
  fail "Info.plist contains a hard-coded AI service credential"
fi

rg -q "private let maxJobs = 12" "$SERVICE" \
  || fail "CarPlay job list is not capped to twelve jobs"
rg -q "createdBy == currentUserID" "$SERVICE" \
  || fail "CarPlay service does not filter jobs to the signed-in user"
pass "CarPlay dispatch service keeps the in-car list scoped and capped"

if rg -q "ChatView|Timesheet|Admin|ImagePicker|Photo|PDFEditor|Search" "$DELEGATE"; then
  fail "CarPlay delegate references a non-driving workflow"
fi
pass "CarPlay delegate stays focused on driving-task templates"

pass "CarPlay entitlement request preflight passed"
