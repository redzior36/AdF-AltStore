# AdF AltSign SRP MARKETPLACE recovery

Purpose: restore the SRP implementation required by AltServer Apple authentication after the 0.2.5c GrandSlam transport recovery exposed `AltStore.AppleDeveloperError 3020` (`Failed to perform authentication handshake with server`).

## Evidence

The exact pinned AltSign source `790b9ccdaf2cec831689395c527e80f1f2838041` defines `MARKETPLACE` in `Package.swift`. Its exact `GSAContext.swift` guards real CoreCrypto SRP behind `#if !MARKETPLACE`; with the flag active, `makeAKey()` and `makeM1()` return `nil`, `verifyServerVerificationMessage()` returns `false`, and related key derivation/checksum paths are disabled.

The exact controlled AltStore baseline also contains `MARKETPLACE` in two project compile-condition entries: one Debug and one Release. Upstream AltStore PR #1713 independently identifies this as the cause of Error 3020.

## Immutable inputs

- 0.2.5c controlled candidate ancestor: `66c2788afe2fea5399245d5b45d51758d09b56d6`
- AltSign gitlink: `790b9ccdaf2cec831689395c527e80f1f2838041`
- AltSign `Package.swift` blob before: `737824392a138517f0c12f80d6c6c70ff8368292`
- AltSign `GSAContext.swift` blob: `d5dff0a84eb837f312ab9e9624e12f6cfba55293`
- AltStore `project.pbxproj` blob before: `ed41e94d673ec936e3e34afbb9f401c6bba89e67`
- upstream correlation: `altstoreio/AltStore` PR #1713 (`Fix authentication handshake failure (Error 3020)`).

## Exact delta

`AdF-Patches/apply-srp-marketplace-recovery.sh` performs only these source transformations after verifying the immutable inputs:

1. removes the single `.define("MARKETPLACE")` Swift setting from the AltSign target in `Dependencies/AltSign/Package.swift`;
2. replaces the single `DEBUG MARKETPLACE` project condition with `DEBUG`;
3. replaces the single Release `MARKETPLACE` condition with an empty condition string;
4. verifies `GSAContext.swift` is byte-for-byte unchanged.

The script refuses to continue if the expected occurrence counts or source blobs differ.

## Deliberately excluded from upstream PR #1713

This candidate does **not** import the PR's unrelated changes to:

- Pods / dependency sources;
- Sparkle or Nuke versions;
- SDK-specific `libcorecrypto.tbd` path;
- ProcessInfo / IOKit compatibility;
- anisette device description;
- Xcode/auth headers already handled separately by 0.2.5c where relevant.

The macOS 26 anisette VM proposal (AltStore PR #1770) is also excluded until a live test produces typed anisette evidence.

## Verification boundary

Credential-free CI must:

- first re-apply and verify the exact 0.2.5c GrandSlam production/test blobs;
- apply this SRP recovery transformation;
- prove `MARKETPLACE` is absent from the active AltSign/package/project compile conditions;
- prove `GSAContext.swift` stayed unchanged;
- run the exact 17-scenario GrandSlam transport suite;
- build AltServer Release arm64 on Xcode 26.

This proves the previous compile-time SRP kill-switch is removed and the candidate builds. It does not prove live Apple authentication; that remains the manual Personal Team proof in AdF issue #59 / PR #62.
