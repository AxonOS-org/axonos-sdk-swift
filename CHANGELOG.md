# Changelog

All notable changes to `axonos-sdk-swift` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — early preview

First public preview of the Swift binding for the AxonOS typed intent stream.

### Added
- `AxonOS` ABI constants: `kernelABIVersion = 1`, `confidenceDenominator = 65535`,
  `consentProtocolVersion`, `sdkVersion`.
- `Capability` enum with kernel rate limits (50 / 1 / 2 / 10 Hz) and snake_case
  wire names; `CapabilitySet` bitset with union / intersection / subtracting /
  subset / disjoint algebra.
- `IntentObservation`: byte-faithful decode and encode of the 32-byte
  little-endian wire record (`timestampMicros`, `kindTag`, `confidenceRaw`,
  `payload`, `sessionId`, `attestation`), typed `kind`, and a display-only
  confidence ratio. `Direction` / `Load` / `Quality` / `IntentKind` enums.
- `Manifest` with a chainable builder, `app_id` and display-string length
  validation, and `validated()` enforcing the malformed / rate-too-high rules.
- `AxonOSError` taxonomy with terminal-vs-retriable classification and stable
  numeric `ErrorCode`s, mirroring the reference Rust SDK.
- `IntentStream` as an `AsyncSequence`, with an ABI handshake and manifest
  validation at `connect`. `ObservationTransport` protocol, an in-memory
  `ReplayTransport`, and a `LiveKernelTransport` placeholder.
- Optional Combine bridge (`IntentStream.publisher()`) on Apple platforms.
- Unit tests for the wire format, capabilities, manifest validation, the error
  taxonomy, and stream iteration.

### Notes
- This is a **pure-Swift** binding. The live kernel transport over the C-FFI
  layer (`axonos-sdk-ffi`) is not yet wired; `IntentStream.connect(_:)` without
  a transport throws `transportUnreachable` by design until it lands.

[Unreleased]: https://github.com/AxonOS-org/axonos-sdk-swift/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/AxonOS-org/axonos-sdk-swift/releases/tag/v0.1.0
