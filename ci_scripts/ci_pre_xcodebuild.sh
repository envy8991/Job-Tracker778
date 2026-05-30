#!/bin/sh
# Xcode Cloud safety-net guardrails.
# Fails fast when future project changes leave the shared scheme/test plan behind.
set -eu

PROJECT_PATH="Job Tracker.xcodeproj"
SCHEME_PATH="$PROJECT_PATH/xcshareddata/xcschemes/Job Tracker.xcscheme"
TEST_PLAN_PATH="Job Tracker Safety Net.xctestplan"
log() {
  printf '[xcode-cloud-safety-net] %s\n' "$1"
}

fail() {
  printf '[xcode-cloud-safety-net] ERROR: %s\n' "$1" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "Missing required file: $1"
}

require_file "$PROJECT_PATH/project.pbxproj"
require_file "$SCHEME_PATH"
require_file "$TEST_PLAN_PATH"

python3 <<'PY'
import json
import re
import sys
from pathlib import Path

project = Path("Job Tracker.xcodeproj/project.pbxproj").read_text()
scheme = Path("Job Tracker.xcodeproj/xcshareddata/xcschemes/Job Tracker.xcscheme").read_text()
plan_path = Path("Job Tracker Safety Net.xctestplan")
plan = json.loads(plan_path.read_text())

errors = []

def check(condition, message):
    if not condition:
        errors.append(message)

check('reference = "container:Job Tracker Safety Net.xctestplan"' in scheme,
      "Shared Job Tracker scheme must use the safety-net test plan.")
check('codeCoverageEnabled = "YES"' in scheme,
      "Shared Job Tracker scheme must keep code coverage enabled for tests.")
check('BlueprintName = "Job TrackerTests"' in scheme and 'skipped = "NO"' in scheme,
      "Shared Job Tracker scheme must include the Job TrackerTests bundle and keep it enabled.")

check(plan.get("version") == 1, "Test plan version must remain 1 for broad Xcode compatibility.")
check(plan.get("defaultOptions", {}).get("codeCoverage") is True,
      "Safety-net test plan must collect code coverage.")
expansion_target = plan.get("defaultOptions", {}).get("targetForVariableExpansion", {})
check(expansion_target.get("name") == "Job Tracker",
      "Safety-net test plan must expand variables against the app target.")

plan_targets = {
    target.get("target", {}).get("identifier"): target.get("target", {}).get("name")
    for target in plan.get("testTargets", [])
}
check(plan_targets.get("CD7E57000000000000000106") == "Job TrackerTests",
      "Safety-net test plan must include the Job TrackerTests target.")

# Future-proofing: if another XCTest target is added to the project later, require it to be added to this plan too.
project_test_targets = {}
for match in re.finditer(r'([A-F0-9]{24}) /\* ([^*]+) \*/ = \{\n\s+isa = PBXNativeTarget;(?P<body>.*?)\n\s+\};', project, re.S):
    identifier, name, body = match.group(1), match.group(2), match.group('body')
    if 'productType = "com.apple.product-type.bundle.unit-test";' in body or 'productType = "com.apple.product-type.bundle.ui-testing";' in body:
        project_test_targets[identifier] = name

missing = {identifier: name for identifier, name in project_test_targets.items() if plan_targets.get(identifier) != name}
check(not missing,
      "Safety-net test plan is missing XCTest targets from the project: " + ", ".join(f"{name} ({identifier})" for identifier, name in missing.items()))

if errors:
    for error in errors:
        print(f"[xcode-cloud-safety-net] ERROR: {error}", file=sys.stderr)
    sys.exit(1)
PY

if command -v xcodebuild >/dev/null 2>&1; then
  log "Checking that Xcode can resolve the shared scheme."
  xcodebuild -list -project "$PROJECT_PATH" >/dev/null
else
  log "xcodebuild is not available; skipped local scheme-resolution check. Xcode Cloud will run it."
fi

log "Safety-net configuration is valid."
