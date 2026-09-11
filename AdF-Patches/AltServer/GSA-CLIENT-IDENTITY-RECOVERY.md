# AdF AltServer GrandSlam client identity recovery

Purpose: recover Apple GrandSlam authentication after the 0.2.5c transport recovery and 0.2.5d SRP recovery exposed a later live blocker: `NSURLErrorDomain -1011` with HTTP 503 from Apple's authentication service.

## Evidence

The third live `PersonalTeamProbe.ipa` attempt reached the real Apple authentication flow but failed with HTTP 503 instead of the earlier plist parser error or SRP handshake error.

Upstream AltStore issue #1789 records the same HTTP 503 for current users. Upstream PR #1790 isolated the rejection to the `X-MMe-Client-Info` client token: requests identifying the client as `com.apple.dt.Xcode/...` are rejected at Apple's GrandSlam edge, while `com.apple.akd/1.0` reaches the GSA service.

## Immutable input

- 0.2.5d controlled candidate ancestor: `b5a2b4b259a402a6e0d57ef81815f7d2111dbab3`
- macOS AltServer anisette source: `AltServer/Anisette Data/AnisetteDataManager.swift`
- exact pre-transform blob: `c3bc69883e3835bda0efdce5fad7baaa22b0a58f`
- upstream correlation: `altstoreio/AltStore` issue #1789 and PR #1790 (`28c15a22ce699e3c9a8d9ff7936007980675274d`)

## Exact delta

`AdF-Patches/apply-gsa-client-identity-recovery.sh` performs one narrow transformation after verifying the exact source blob and ancestor:

- replaces exactly two macOS AltServer occurrences of `com.apple.dt.Xcode/3594.4.19` with `com.apple.akd/1.0`;
- refuses to proceed if the expected occurrence count or source identity differs;
- leaves all anisette values, SRP code, request bodies and credential handling unchanged.

The two replacements cover the active macOS AltServer paths:

1. sanitizing XPC/Mail-derived `deviceDescription`;
2. the locally generated AOSKit `serverFriendlyDescription`.

## Deliberately excluded

This stage does not modify:

- AltDaemon/iOS paths;
- AltSign SRP implementation;
- the 0.2.5c GrandSlam transport code;
- anisette machine ID, OTP, routing info, local user ID, serial number or device ID;
- Apple Account credentials or 2FA handling;
- upstream PR #1770 anisette VM implementation.

## Verification boundary

Credential-free CI must compose 0.2.5c + 0.2.5d + this transform, prove the blocked Xcode token is absent from the active macOS AltServer anisette source, retain the 17-scenario GrandSlam regression, and build AltServer Release arm64 on Xcode 26.

This does not itself prove live Apple authentication or provisioning. The next proof remains the owner's local Personal Team sideload attempt tracked in AdF issue #59 / PR #62.
