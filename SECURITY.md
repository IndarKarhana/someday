# Someday security model

This is an offline personal keepsake, not a prize lottery or independent certificate. Hardening raises the cost of cheating through the unmodified app. It does not make an attacker-controlled phone trustworthy.

## What is protected

- One randomly generated 256-bit draw key per retained device identity. Dates use stable, domain-separated HMAC-SHA256 with rejection sampling and the published exact ticket probabilities.
- Secret, eligibility bitset, clock anchor, elapsed-time allowance and notification preference reside together in a non-synchronizing Keychain item, shared only between correctly entitled app and widget targets.
- AfterFirstUnlockThisDeviceOnly permits widget use after the first unlock while keeping the item device-bound. This is not Secure Enclave isolation: authorized app code uses the secret in memory.
- App-group files hold only a lock and an identity-present marker. No draw key or authoritative history is saved there.
- Every read/check/commit transaction takes a cross-process advisory lock. Keychain writes finish before new results are released. Locked storage, entitlement errors, corruption, failed writes and lock contention fail closed; none creates a replacement owner.
- The widget can check current eligibility but receives no future-win schedule. Notifications contain only a generic message after a current-day win is committed.
- Receipts use AES-GCM, an HKDF-derived owner key and authenticated context. Import authenticates against the existing owner and returns the current protected collection. It cannot replace a key, restore an old clock, add a hit or roll back history.
- Receipt reads are capped at 512,000 bytes while reading. Non-regular files, symlinks, pipes, corrupt ciphertext, incompatible headers and foreign identities are rejected. File sizes are not trusted.

Receipts are deliberately **not portable backups** and cannot rebuild a lost Keychain authority. PNG cards can be saved anywhere but are not proof of authenticity.

## Fully offline clock policy

The user chose a 24-hour verification pause after an unverified restart rather than adding a server.

The public continuous monotonic clock includes sleep. An observed uptime decrease or a wall-clock discrepancy exceeding three minutes starts a 24-hour verification window from detection. Further discrepancies restart that window. An unchanged fixed anchor, rather than a per-open rebased anchor, prevents accumulating tolerated clock shifts.

Once that window completes, only the resumption date is eligible; dates in the unverified gap are skipped. Ordinary missed days may be reconstructed when elapsed time remains verifiable. Enrollment timezone stays fixed.

An additional persistent allowance charges 86,400 elapsed seconds per new eligible date, apart from the enrollment date and a one-time 93,600-second midnight/seasonal-boundary allowance. Only positive deltas of the system continuous clock refill it. A reset does not renew the starting allowance, and wall time never adds credit. This bounds long-term chances even if someone repeatedly ends quarantine just before midnight. It can delay a later day's draw after clock manipulations. Receipt replay cannot reset this allowance.

We do not claim reliable detection of every reboot. Public uptime and wall time are imperfect witnesses; an undetected reboot whose new uptime is larger can undercount actual elapsed time but does not earn more elapsed credit than was actually spent. There is no private boot-session identifier, jailbreak detector, background timer daemon, or network time call.

## Attacks reproduced and addressed

| Attack | Before hardening | Current response |
| --- | --- | --- |
| Pick seeds until number 1, then import consistent JSON | Jackpot accepted after 65,527 candidates in about 0.41 seconds on this Mac | Legacy unsigned data and foreign-owner receipts rejected; no seed import |
| Advance wall clock 100 years in one observation | 723 wins manufactured in the baseline fixture | Verification pause; no extra eligible dates |
| Export and inspect the random key | Raw key present in backup | No key in receipt; identity stays in Keychain |
| Replay an old valid export | Could replace the journal | Current authority retained, including newer wins and clock/allowance state |
| Repeatedly end quarantine immediately before midnight | First hardening pass still allowed 21 dates in 10 elapsed days | Persistent elapsed allowance bounds total eligibility |
| Import a named pipe instead of a file | A normal file open could wait indefinitely | Nonblocking open and descriptor-level regular-file validation |

The baseline timings are local observations, not general performance promises. The first forged-seed fixture used a different date from the final regression fixture, which finds a candidate in 53,085 attempts.

## Executable validation

Run `make check`. The dependency-free command-line suites use the production core with isolated identities and injected clock readings, not the real device Keychain. They cover exact odds, fixed HMAC vectors, normal catchup, DST, protected serialization, century-sized history, clock acceleration and rollback, gradual drift, repeat reboots, the 24-hour boundary, replay, seed grinding, foreign identities, encrypted-payload bit flips, truncation, malformed imports, nested JSON, hostile file types, corrupted protected data, midnight amplification, and 5,000 randomized clock/reboot events.

Tools/SecurityAudit.py also checks production call-site boundaries and exclusion of preview/test keys. These source checks are regression aids, not a formal proof or an independent external audit.

No third-party cryptography, dependencies, servers, analytics or obfuscation SDKs were added.

## Remaining limits

- A modified/re-signed executable, debugger attached to a developer build, jailbreak, OS compromise or authorized process memory access can bypass local checks or extract secrets.
- Multiple devices and destructive device resets cannot be globally deduplicated offline. Keychain retention after uninstall is not guaranteed; losing both the identity and local marker can permit a new enrollment.
- System-level restoration of older protected state is not covered by the receipt replay guarantee. There is no external immutable counter.
- The first enrollment date is based on an untrusted local clock. Clock tampering can therefore falsify civil dates, even when it cannot cheaply manufacture unlimited draws.
- The elapsed allowance bounds average draw frequency, not independently verified real-world calendar dates. Its small one-time boundary allowance is explicit, not an absolute one-chance-per-24-hours promise.
- Exported images, screenshots, widget presentation and notification delivery are not cryptographic certificates. iOS may defer widget refreshes or notifications.
- An attacker who can edit protected storage directly is outside the threat model. The protected-state decoder is a trusted Keychain-only entry point in shipping call sites, not an import format.
- There are no real prizes or money at stake. Do not add either without redesigning authority around a trusted service and reviewing applicable requirements.

## Release gates still outstanding

This Mac has Command Line Tools but no full Xcode/iOS SDK. Command-line core tests, macOS-SDK typechecking, source parsing, project validation and native SwiftUI design previews do not substitute for:

1. A signed iPhone build with the real app-group and Keychain access-group entitlements on both targets.
2. Physical-device reboot/lock/unlock, widget/app concurrency, background refresh and optional notification testing.
3. Keychain unavailable/corrupt/write-failure and interrupted-write testing on device; confirm no reset or uncommitted result is exposed.
4. Uninstall/reinstall and device-backup/restore behavior for supported iOS versions.
5. Real Files-provider receipt import/export and sharing flows.
6. Release IPA size, launch time, widget energy, and long-history profiling with Instruments.
7. Independent security review before making any strong anti-cheating claims.

## Apple references

- [Device-only accessibility class](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly)
- [Keychain access groups](https://developer.apple.com/documentation/security/ksecattraccessgroup)
- [iOS 18 release notes: boot-session UUID restrictions](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-18-release-notes)
- [Apple DTS discussion of uninstall/Keychain persistence](https://developer.apple.com/forums/thread/36442)
- [Required-reason API declarations](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

The privacy manifest declares continuous-clock elapsed-time and event-date purposes, plus metadata validation of files explicitly chosen by the user. No such information is sent to a server by Someday.
