<div align="center">

# AxonOS SDK for Swift

**A pure-Swift binding for the AxonOS typed intent stream — iOS, iPadOS, macOS, tvOS, watchOS.**

[![CI](https://github.com/AxonOS-org/axonos-sdk-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/AxonOS-org/axonos-sdk-swift/actions/workflows/ci.yml) [![Release](https://img.shields.io/github/v/release/AxonOS-org/axonos-sdk-swift?label=release&color=brightgreen)](https://github.com/AxonOS-org/axonos-sdk-swift/releases)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-blue)
![Kernel ABI](https://img.shields.io/badge/kernel%20ABI-v1-success)
![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue)
[![AxonOS Radar](https://img.shields.io/badge/AxonOS%20Radar-open%20neurotech%20map-1f8fae?labelColor=0b1220)](https://axonos-bci.github.io/axonos-community-radar/)

</div>

This is the Swift binding for [AxonOS](https://axonos.org) — an open cognitive
operating system for brain-computer interfaces. It exposes the kernel's single
typed event stream through an idiomatic Swift API: `async`/`await`, an
`AsyncSequence`, value types, a throwing manifest builder, and an optional
Combine bridge.

It decodes the **same 32-byte `IntentObservation` wire record** as the reference
[Rust SDK](https://github.com/AxonOS-org/axonos-sdk), so an observation produced
by the kernel decodes byte-for-byte the same in Swift as in Rust. That
wire-format identity is the contract every AxonOS binding shares.

## Status — early preview (v0.1.0)

Read this before depending on the package:

- **Pure Swift, no system dependencies.** The whole package is Swift; it links
  no native library today. It builds on Apple platforms and on Linux.
- **What works now:** the full typed data model (capabilities, manifest,
  observations), byte-exact wire decode/encode against ABI v1, manifest
  validation, the error taxonomy, and an `AsyncSequence` stream driven by a
  pluggable transport — including a real in-memory `ReplayTransport` for
  development, tests, and offline analysis of captured sessions.
- **What is not wired yet:** the **live kernel transport**. It is delivered by
  the C-FFI binding (`axonos-sdk-ffi`), which is on the SDK roadmap. Until it
  lands, `IntentStream.connect(_:)` without an explicit transport throws
  `transportUnreachable` *by design* — use `connect(_:transport:)` with a
  transport you provide.
- **Verification:** the package ships a unit-test suite; CI runs `swift build`
  and `swift test` on macOS and Linux on every push (badge above reflects the
  live result). It has not been validated against a physical kernel.

Nothing here claims a maturity it does not have. Versions, the wire layout, and
behavior track the reference Rust SDK; where a layer is not built, it says so
and fails fast rather than pretending.

## Installation

Swift Package Manager. While the preview stabilizes, track `main`:

```swift
.package(url: "https://github.com/AxonOS-org/axonos-sdk-swift", branch: "main")
```

Tagged releases follow once CI is green on a cut:

```swift
.package(url: "https://github.com/AxonOS-org/axonos-sdk-swift", from: "0.1.0")
```

Then add `"AxonOS"` to your target's dependencies.

## Quick start

```swift
import AxonOS

// Declare what you need. Validation mirrors the kernel's manifest rules.
let manifest = try Manifest(appId: "com.example.aac")
    .capability(.navigation)
    .maxRateHz(50)

// Today: a transport you supply (here, replaying captured/sample observations).
let transport = ReplayTransport(observations: recorded)

// connect performs an ABI handshake + manifest validation before data flows.
let stream = try await IntentStream.connect(manifest, transport: transport)
for try await obs in stream {
    switch obs.kind {
    case .direction(let d):
        print("move \(d) @ \(obs.timestampMicros)µs, confidence \(obs.confidenceRaw)/65535")
    case .load(let l):   print("cognitive load: \(l)")
    case .quality(let q): print("signal quality: \(q)")
    case .unknown:        break   // forward-compatible
    }
}

// When the C-FFI binding ships, the live kernel transport is simply:
//   let stream = try await IntentStream.connect(manifest)
```

### Combine

On Apple platforms the stream bridges to Combine:

```swift
let cancellable = try await IntentStream.connect(manifest, transport: transport)
    .publisher()
    .receive(on: RunLoop.main)
    .sink(receiveCompletion: { _ in }, receiveValue: { obs in
        // update SwiftUI state
    })
```

## The wire record

`IntentObservation` is a fixed **32-byte, little-endian** record, identical to
the reference Rust SDK's `#[repr(C, align(8))]` struct:

| Offset | Size | Field             | Notes                                  |
|:-------|:-----|:------------------|:---------------------------------------|
| 0      | 8    | `timestampMicros` | `UInt64`, monotonic microseconds       |
| 8      | 2    | `kindTag`         | `UInt16` (`1` Direction, `2` Load, `3` Quality) |
| 10     | 2    | `confidenceRaw`   | `UInt16`, Q0.16 — `65535 == 1.0`       |
| 12     | 4    | `payload`         | byte 0 carries the typed enum value    |
| 16     | 8    | `sessionId`       | `UInt64`, opaque                       |
| 24     | 8    | `attestation`     | truncated HMAC-SHA256                  |

`confidenceRaw` is the deterministic value; `confidence` (a `Double` ratio) is
for display only — compare raw values for any decision logic, exactly as the
Rust SDK instructs.

```swift
let obs = IntentObservation(wire: bytes)          // nil unless exactly 32 bytes
let again = obs?.wireBytes                          // round-trips
```

## API overview

| Type | Purpose |
|:-----|:--------|
| `Capability`, `CapabilitySet` | Requestable intent classes and a compact set with full algebra. |
| `Manifest` | Chainable, validating declaration of capabilities and rate. |
| `IntentObservation` | Typed observation + byte-exact wire decode/encode. |
| `IntentKind`, `Direction`, `Load`, `Quality` | Decoded intent kinds. |
| `IntentStream` | `AsyncSequence` of observations, with ABI handshake at connect. |
| `ObservationTransport`, `ReplayTransport`, `LiveKernelTransport` | Pluggable delivery; in-memory replay today, live kernel via C-FFI later. |
| `AxonOSError`, `ErrorCode` | Error taxonomy with terminal-vs-retriable classification and stable codes. |

## Cross-language guarantees

Inherited from the shared ABI, and the parts this binding can uphold today:

- **Wire-format identity.** A record decodes to the same fields in Swift as in
  Rust; `confidenceRaw` maps to the same ratio everywhere.
- **Capability gating & rate limits.** Enforced kernel-side; the manifest
  declares intent and the SDK validates it before connecting.
- **ABI version handshake.** Every connection checks `kernelABIVersion`;
  a mismatch is refused with an actionable, terminal error before data flows.

The Rust SDK is the reference implementation. This binding is a second-class
consumer of the same ABI — it cannot weaken the safety, privacy, or real-time
guarantees the kernel enforces.

## Relationship to the Rust SDK

The types, values, validation rules, and error semantics here mirror
[`axonos-sdk`](https://github.com/AxonOS-org/axonos-sdk) one-for-one. When the
two ever disagree, the Rust SDK is authoritative and this binding is the bug.

## Contributing

Issues and pull requests welcome. Please keep the wire format and type semantics
in lock-step with the Rust SDK, and add tests for any wire-facing change. By
contributing you agree to license your work under Apache-2.0 OR MIT.

## Security

Report vulnerabilities privately to **security@axonos.org**. Please do not open
public issues for security reports.

## License

Licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT) at
your option.

---

<div align="center">

© 2026 The AxonOS Project / Denis Yermakou · [axonos.org](https://axonos.org) · connect@axonos.org · security@axonos.org

</div>
