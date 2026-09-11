#!/usr/bin/env bash
set -euo pipefail

BASE_CANDIDATE_SHA="b5a2b4b259a402a6e0d57ef81815f7d2111dbab3"
EXPECTED_ANISSETTE_BLOB="c3bc69883e3835bda0efdce5fad7baaa22b0a58f"
OLD_CLIENT_TOKEN="com.apple.dt.Xcode/3594.4.19"
NEW_CLIENT_TOKEN="com.apple.akd/1.0"
EXPECTED_OCCURRENCES="2"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! git merge-base --is-ancestor "$BASE_CANDIDATE_SHA" HEAD; then
  echo "ERROR: 0.2.5d candidate $BASE_CANDIDATE_SHA is not an ancestor of HEAD" >&2
  exit 40
fi

anisette_rel="AltServer/Anisette Data/AnisetteDataManager.swift"
anisette_blob="$(git hash-object "$anisette_rel")"
[[ "$anisette_blob" == "$EXPECTED_ANISSETTE_BLOB" ]] || { echo "ERROR: AltServer anisette source blob mismatch: $anisette_blob" >&2; exit 41; }

python3 - <<'PY'
from pathlib import Path

path = Path('AltServer/Anisette Data/AnisetteDataManager.swift')
text = path.read_text()
old = 'com.apple.dt.Xcode/3594.4.19'
new = 'com.apple.akd/1.0'
count = text.count(old)
if count != 2:
    raise SystemExit(f'ERROR: expected exactly two AltServer Xcode client-token occurrences, got {count}')
if text.count(new) != 0:
    raise SystemExit(f'ERROR: replacement client token already present before transform ({text.count(new)})')
path.write_text(text.replace(old, new))
PY

old_count="$( (grep -Fo "$OLD_CLIENT_TOKEN" "$anisette_rel" || true) | wc -l | tr -d ' ')"
new_count="$( (grep -Fo "$NEW_CLIENT_TOKEN" "$anisette_rel" || true) | wc -l | tr -d ' ')"
[[ "$old_count" == "0" ]] || { echo "ERROR: blocked Xcode client token remains in AltServer anisette source" >&2; exit 42; }
[[ "$new_count" == "$EXPECTED_OCCURRENCES" ]] || { echo "ERROR: expected $EXPECTED_OCCURRENCES akd client tokens, got $new_count" >&2; exit 43; }

anisette_after="$(git hash-object "$anisette_rel")"
printf 'GSA_IDENTITY_BASE_CANDIDATE=%s\n' "$BASE_CANDIDATE_SHA"
printf 'ALTSERVER_ANISETTE_SOURCE_BEFORE=%s\n' "$EXPECTED_ANISSETTE_BLOB"
printf 'ALTSERVER_ANISETTE_SOURCE_AFTER=%s\n' "$anisette_after"
printf 'BLOCKED_XCODE_CLIENT_TOKEN_COUNT=%s\n' "$old_count"
printf 'AKD_CLIENT_TOKEN_COUNT=%s\n' "$new_count"
echo 'GSA_CLIENT_IDENTITY_RECOVERY_RESULT=PASS'
