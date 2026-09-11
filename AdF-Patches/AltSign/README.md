# AdF controlled AltSign GrandSlam auth recovery

Purpose: recover AltStore Classic / AltServer Apple authentication when GrandSlam returns an unstructured HTML error page (observed by AdF as `NSCocoaErrorDomain 3840`, `unknown tag html`) without importing unrelated AltSign history.

## Immutable inputs

- AdF controlled AltStore baseline: `56854e66fef2eac32dad88dcbad1dc131d430e60`
- baseline `Dependencies/AltSign` gitlink: `790b9ccdaf2cec831689395c527e80f1f2838041`
- baseline authentication source blob: `2d3e50c21faba2c751ac85a7dc4abe9c1f90d26c`
- patched authentication source blob: `fcb6c74f7ac0ed5578a9e956404a859295d54af7`
- upstream contribution: `rileytestut/AltSign` PR #53
- upstream contribution head: `530e44aee968da15f8efe8d8eef829f3944ee318`
- upstream regression-test blob: `d94eea268b203c93082260c201e3840dcfe96fcd`
- controlled vendored test adaptation blob: `7527ff1b909dc98cdaa6f669fa3411adddb33be5`

The full PR #53 head is intentionally **not** used as the AltSign gitlink. It is on a different AltSign history and carries unrelated crypto/build changes relative to AdF's pinned baseline. The production authentication hunk itself is based on the exact same source blob as the pinned baseline, so this directory publishes only that auditable transport delta.

The Python regression harness is a controlled textual adaptation of the upstream 17-scenario harness necessitated by transport through the repository API. It preserves the same scenario matrix and assertions but is not claimed byte-for-byte identical; both upstream and controlled blob IDs are recorded and the controlled blob is fail-closed pinned by the applicator. The production Swift result **is** required to match the exact upstream patched blob.

## Delta

`0001-grandslam-auth-recovery.patch` changes only `AltSign/Sources/ALTAppleAPI+Authentication.swift`:

- modern AuthKit User-Agent for GrandSlam;
- fresh ephemeral URLSession per attempt;
- monotonic 20-second exchange budget;
- bounded HTTP 5xx recovery (five attempts, 1/2/4/8-second delays);
- structured Apple protocol results take precedence over HTTP status;
- malformed/unstructured responses fail without exposing response body/parser internals.

SRP, password handling, 2FA submission, anisette generation, signing and developer-portal operations are not changed.

## Apply and test

From a checkout of this controlled mirror commit:

```bash
git submodule update --init --recursive
bash AdF-Patches/apply-grandslam-auth-recovery.sh
python3 Dependencies/AltSign/Tests/GrandSlamTransport/test_transport.py
```

The applicator refuses to run unless the expected baseline/gitlink/source/test hashes match exactly.

The regression suite uses only a loopback HTTP server. It does not call Apple services and requires no Apple Account, password, 2FA code, certificate, provisioning profile or device identifier.

## Verification boundary

Passing the local regression and an arm64 AltServer build proves the controlled source is internally consistent and handles the reproduced HTML/5xx transport failure. It does **not** prove live Personal Team authentication. That remains a manual owner test in AdF issue #59 after a candidate build is ready.

The larger macOS 26+ anisette VM proposal in AltStore PR #1770 is deliberately excluded. It will only be considered if the live candidate progresses past the HTML parser failure and reports a specific anisette failure.
