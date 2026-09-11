#!/usr/bin/env bash
set -euo pipefail

BASE_ALTSTORE_SHA="56854e66fef2eac32dad88dcbad1dc131d430e60"
EXPECTED_ALTSIGN_SHA="790b9ccdaf2cec831689395c527e80f1f2838041"
EXPECTED_SOURCE_BLOB="2d3e50c21faba2c751ac85a7dc4abe9c1f90d26c"
EXPECTED_PATCHED_BLOB="fcb6c74f7ac0ed5578a9e956404a859295d54af7"
EXPECTED_TEST_BLOB="7527ff1b909dc98cdaa6f669fa3411adddb33be5"
UPSTREAM_TEST_BLOB="d94eea268b203c93082260c201e3840dcfe96fcd"
UPSTREAM_ALTSIGN_PR="https://github.com/rileytestut/AltSign/pull/53"
UPSTREAM_ALTSIGN_HEAD="530e44aee968da15f8efe8d8eef829f3944ee318"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! git merge-base --is-ancestor "$BASE_ALTSTORE_SHA" HEAD; then
  echo "ERROR: controlled AltStore baseline $BASE_ALTSTORE_SHA is not an ancestor of HEAD" >&2
  exit 20
fi

printf -v expected_gitlink_line '160000 commit %s\tDependencies/AltSign' "$EXPECTED_ALTSIGN_SHA"
actual_gitlink_line="$(git ls-tree HEAD Dependencies/AltSign)"
if [[ "$actual_gitlink_line" != "$expected_gitlink_line" ]]; then
  echo "ERROR: AltSign gitlink mismatch" >&2
  echo "Expected: $expected_gitlink_line" >&2
  echo "Actual:   $actual_gitlink_line" >&2
  exit 21
fi

git submodule update --init --recursive Dependencies/AltSign
actual_altsign_sha="$(git -C Dependencies/AltSign rev-parse HEAD)"
if [[ "$actual_altsign_sha" != "$EXPECTED_ALTSIGN_SHA" ]]; then
  echo "ERROR: checked-out AltSign SHA mismatch: $actual_altsign_sha" >&2
  exit 22
fi

source_rel="AltSign/Sources/ALTAppleAPI+Authentication.swift"
actual_source_blob="$(git -C Dependencies/AltSign hash-object "$source_rel")"
if [[ "$actual_source_blob" != "$EXPECTED_SOURCE_BLOB" ]]; then
  echo "ERROR: AltSign authentication source blob mismatch: $actual_source_blob" >&2
  exit 23
fi

patch_path="$repo_root/AdF-Patches/AltSign/0001-grandslam-auth-recovery.patch"
test_source="$repo_root/AdF-Patches/AltSign/Tests/GrandSlamTransport/test_transport.py"
test_target_dir="$repo_root/Dependencies/AltSign/Tests/GrandSlamTransport"

if [[ ! -f "$patch_path" || ! -f "$test_source" ]]; then
  echo "ERROR: controlled patch or regression test is missing" >&2
  exit 24
fi

actual_test_blob="$(git hash-object "$test_source")"
if [[ "$actual_test_blob" != "$EXPECTED_TEST_BLOB" ]]; then
  echo "ERROR: controlled GrandSlam regression test blob mismatch: $actual_test_blob" >&2
  exit 25
fi

git -C Dependencies/AltSign apply --check "$patch_path"
git -C Dependencies/AltSign apply "$patch_path"

patched_blob="$(git -C Dependencies/AltSign hash-object "$source_rel")"
if [[ "$patched_blob" != "$EXPECTED_PATCHED_BLOB" ]]; then
  echo "ERROR: patched authentication source blob mismatch: $patched_blob" >&2
  exit 26
fi

mkdir -p "$test_target_dir"
cp "$test_source" "$test_target_dir/test_transport.py"
chmod 755 "$test_target_dir/test_transport.py"

printf 'CONTROLLED_ALTSTORE_BASE=%s\n' "$BASE_ALTSTORE_SHA"
printf 'ALTSIGN_BASE=%s\n' "$EXPECTED_ALTSIGN_SHA"
printf 'ALTSIGN_AUTH_SOURCE_BEFORE=%s\n' "$EXPECTED_SOURCE_BLOB"
printf 'ALTSIGN_AUTH_SOURCE_AFTER=%s\n' "$patched_blob"
printf 'CONTROLLED_GRANDSLAM_TEST_BLOB=%s\n' "$actual_test_blob"
printf 'UPSTREAM_GRANDSLAM_TEST_BLOB=%s\n' "$UPSTREAM_TEST_BLOB"
printf 'UPSTREAM_ALTSIGN_PR=%s\n' "$UPSTREAM_ALTSIGN_PR"
printf 'UPSTREAM_ALTSIGN_HEAD=%s\n' "$UPSTREAM_ALTSIGN_HEAD"
echo 'GRANDSLAM_AUTH_RECOVERY_PATCH_RESULT=PASS'
