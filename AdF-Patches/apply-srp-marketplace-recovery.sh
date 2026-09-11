#!/usr/bin/env bash
set -euo pipefail

BASE_CANDIDATE_SHA="66c2788afe2fea5399245d5b45d51758d09b56d6"
EXPECTED_ALTSIGN_SHA="790b9ccdaf2cec831689395c527e80f1f2838041"
EXPECTED_PACKAGE_BLOB="737824392a138517f0c12f80d6c6c70ff8368292"
EXPECTED_GSA_BLOB="d5dff0a84eb837f312ab9e9624e12f6cfba55293"
EXPECTED_PROJECT_BLOB="ed41e94d673ec936e3e34afbb9f401c6bba89e67"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! git merge-base --is-ancestor "$BASE_CANDIDATE_SHA" HEAD; then
  echo "ERROR: 0.2.5c candidate $BASE_CANDIDATE_SHA is not an ancestor of HEAD" >&2
  exit 30
fi

printf -v expected_gitlink_line '160000 commit %s\tDependencies/AltSign' "$EXPECTED_ALTSIGN_SHA"
actual_gitlink_line="$(git ls-tree HEAD Dependencies/AltSign)"
if [[ "$actual_gitlink_line" != "$expected_gitlink_line" ]]; then
  echo "ERROR: AltSign gitlink mismatch" >&2
  exit 31
fi

git submodule update --init --recursive Dependencies/AltSign
actual_altsign_sha="$(git -C Dependencies/AltSign rev-parse HEAD)"
[[ "$actual_altsign_sha" == "$EXPECTED_ALTSIGN_SHA" ]] || { echo "ERROR: checked-out AltSign SHA mismatch" >&2; exit 32; }

package_rel="Package.swift"
gsa_rel="AltSign/Sources/GSAContext.swift"
project_rel="AltStore.xcodeproj/project.pbxproj"

package_blob="$(git -C Dependencies/AltSign hash-object "$package_rel")"
gsa_blob="$(git -C Dependencies/AltSign hash-object "$gsa_rel")"
project_blob="$(git hash-object "$project_rel")"

[[ "$package_blob" == "$EXPECTED_PACKAGE_BLOB" ]] || { echo "ERROR: AltSign Package.swift blob mismatch: $package_blob" >&2; exit 33; }
[[ "$gsa_blob" == "$EXPECTED_GSA_BLOB" ]] || { echo "ERROR: GSAContext.swift blob mismatch: $gsa_blob" >&2; exit 34; }
[[ "$project_blob" == "$EXPECTED_PROJECT_BLOB" ]] || { echo "ERROR: project.pbxproj blob mismatch: $project_blob" >&2; exit 35; }

python3 - <<'PY'
from pathlib import Path

package = Path('Dependencies/AltSign/Package.swift')
text = package.read_text()
old = '''            ],\n            swiftSettings: [\n                .define("MARKETPLACE")\n            ]\n'''
new = '''            ]\n'''
if text.count(old) != 1:
    raise SystemExit(f'ERROR: expected exactly one AltSign MARKETPLACE swiftSettings block, got {text.count(old)}')
package.write_text(text.replace(old, new, 1))

project = Path('AltStore.xcodeproj/project.pbxproj')
text = project.read_text()
debug_old = 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG MARKETPLACE";'
release_old = 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = MARKETPLACE;'
if text.count(debug_old) != 1:
    raise SystemExit(f'ERROR: expected one Debug MARKETPLACE condition, got {text.count(debug_old)}')
if text.count(release_old) != 1:
    raise SystemExit(f'ERROR: expected one Release MARKETPLACE condition, got {text.count(release_old)}')
text = text.replace(debug_old, 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;', 1)
text = text.replace(release_old, 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "";', 1)
project.write_text(text)
PY

if grep -Fq '.define("MARKETPLACE")' Dependencies/AltSign/Package.swift; then
  echo "ERROR: MARKETPLACE remains enabled in AltSign Package.swift" >&2
  exit 36
fi
if grep -Fq 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = MARKETPLACE;' "$project_rel" || grep -Fq 'DEBUG MARKETPLACE' "$project_rel"; then
  echo "ERROR: MARKETPLACE remains enabled in project compile conditions" >&2
  exit 37
fi

post_gsa_blob="$(git -C Dependencies/AltSign hash-object "$gsa_rel")"
[[ "$post_gsa_blob" == "$EXPECTED_GSA_BLOB" ]] || { echo "ERROR: GSAContext.swift changed unexpectedly" >&2; exit 38; }

package_after="$(git -C Dependencies/AltSign hash-object "$package_rel")"
project_after="$(git hash-object "$project_rel")"

printf 'SRP_BASE_CANDIDATE=%s\n' "$BASE_CANDIDATE_SHA"
printf 'ALTSIGN_BASE=%s\n' "$EXPECTED_ALTSIGN_SHA"
printf 'ALTSIGN_PACKAGE_BEFORE=%s\n' "$EXPECTED_PACKAGE_BLOB"
printf 'ALTSIGN_PACKAGE_AFTER=%s\n' "$package_after"
printf 'GSA_CONTEXT_UNCHANGED=%s\n' "$post_gsa_blob"
printf 'PROJECT_BEFORE=%s\n' "$EXPECTED_PROJECT_BLOB"
printf 'PROJECT_AFTER=%s\n' "$project_after"
echo 'MARKETPLACE_COMPILE_CONDITION_COUNT=0'
echo 'SRP_MARKETPLACE_RECOVERY_RESULT=PASS'
