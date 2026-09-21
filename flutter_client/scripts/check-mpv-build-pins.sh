#!/bin/bash
# Canary for the pinned edde746/mpv-build binary dependencies.
#
# We pin exact mpv-build commits/asset hashes in 3 places:
#   - ios/macos/tvos Runner.xcodeproj/project.pbxproj (XCRemoteSwiftPackageReference
#     "mpv-build" -> requirement.revision)
#   - mpv-build.lock.json (android + windows tarball asset names + checksums)
#
# mpv-build publishes every build to one perpetually-growing GitHub Release per
# platform (200+ assets and counting) instead of pruning old ones, and GitHub's
# release-asset CDN has been observed to start 504ing specific old assets over
# time (see the 2026-09-21 incident: a Sept-1 pin died in CI ~3 weeks later,
# while local machines with those assets already cached never noticed).
#
# This script re-checks every URL our pins currently resolve to and fails if
# any of them are no longer servable, so staleness is caught on a schedule
# instead of mid-release. Run standalone (`scripts/check-mpv-build-pins.sh`)
# or via .github/workflows/dependency-canary.yml.
#
# Deliberately avoids bash 4+ features (associative arrays, mapfile): macOS
# runners' default /bin/bash is 3.2.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_DIR="$(dirname "$SCRIPT_DIR")"
cd "$FLUTTER_DIR"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
URLS_FILE="$WORK/urls.tsv"   # url<TAB>label
touch "$URLS_FILE"

# Args: url, label. Appends to URLS_FILE; actual de-dup + checking happens later.
queue_url() {
  printf '%s\t%s\n' "$1" "$2" >> "$URLS_FILE"
}

echo "=== Apple (pbxproj mpv-build revision -> Package.swift asset URLs) ==="

REVISIONS_FILE="$WORK/revisions.txt"
touch "$REVISIONS_FILE"
FAILED=0

for platform in ios macos tvos; do
  pbxproj="$platform/Runner.xcodeproj/project.pbxproj"
  if [[ ! -f "$pbxproj" ]]; then
    echo "  SKIP [$platform] $pbxproj not found"
    continue
  fi

  revision=$(sed -n '/XCRemoteSwiftPackageReference "mpv-build"/,/};/{/revision = /p;}' "$pbxproj" \
    | head -1 | sed -E 's/.*revision = ([a-f0-9]+);/\1/')

  if [[ -z "$revision" ]]; then
    echo "  FAIL [$platform] could not find pinned mpv-build revision in $pbxproj"
    FAILED=$((FAILED + 1))
    continue
  fi

  echo "  [$platform] pinned to $revision"

  if grep -qxF "$revision" "$REVISIONS_FILE" 2>/dev/null; then
    continue
  fi
  echo "$revision" >> "$REVISIONS_FILE"

  package_swift_url="https://raw.githubusercontent.com/edde746/mpv-build/$revision/Package.swift"
  if ! package_swift=$(curl -sfL --max-time 30 "$package_swift_url"); then
    echo "  FAIL [$platform] could not fetch Package.swift at $revision ($package_swift_url)"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Every binaryTarget url is a quoted string on its own `url: "..."` line.
  grep -oE 'url: *"https://[^"]+"' <<< "$package_swift" | sed -E 's/url: *"(.*)"/\1/' \
    | while IFS= read -r asset_url; do
        [[ -n "$asset_url" ]] && queue_url "$asset_url" "mpv-build@$revision"
      done
done

echo ""
echo "=== Android + Windows (mpv-build.lock.json) ==="

lock_file="mpv-build.lock.json"
if [[ -f "$lock_file" ]]; then
  python3 - "$lock_file" <<'PYEOF' >> "$URLS_FILE"
import json
import sys

with open(sys.argv[1]) as f:
    lock = json.load(f)

for platform, entry in lock["artifacts"].items():
    base = entry["assetBase"]
    for asset in entry["assets"].values():
        print(f"{base}/{asset['asset']}\tmpv-build.lock.json:{platform}")
PYEOF
else
  echo "  FAIL $lock_file not found"
  FAILED=$((FAILED + 1))
fi

echo ""
echo "=== Checking $(sort -u "$URLS_FILE" | wc -l | tr -d ' ') unique asset URL(s) ==="

CHECKED=0
while IFS=$'\t' read -r url label; do
  [[ -z "$url" ]] && continue
  CHECKED=$((CHECKED + 1))

  code="000"
  for attempt in 1 2 3; do
    code=$(curl -sL -o /dev/null -w "%{http_code}" --max-time 30 "$url" || echo "000")
    [[ "$code" == "200" ]] && break
    sleep 5
  done

  if [[ "$code" == "200" ]]; then
    echo "  OK   [$label] $url"
  else
    echo "  FAIL [$label] $url -> HTTP $code (after 3 attempts)"
    FAILED=$((FAILED + 1))
  fi
done < <(sort -u -t $'\t' -k1,1 "$URLS_FILE")

echo ""
echo "=== Summary: $CHECKED unique asset(s) checked, $FAILED failed ==="

if [[ "$FAILED" -gt 0 ]]; then
  echo ""
  echo "One or more pinned mpv-build/MPVKit assets are no longer servable from"
  echo "GitHub. Bump the pin (XCRemoteSwiftPackageReference \"mpv-build\" in each"
  echo "project.pbxproj + matching Package.resolved files, and mpv-build.lock.json)"
  echo "to the latest edde746/mpv-build commit/release before this reaches a"
  echo "release build."
  exit 1
fi

echo "All pinned mpv-build/MPVKit assets are servable."
