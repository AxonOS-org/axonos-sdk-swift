// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

import Foundation

/// Direction of a navigation intent. Mirrors `axonos_sdk::Direction`.
public enum Direction: UInt8, CaseIterable, Sendable, Hashable, Codable {
    case up = 0, right = 1, down = 2, left = 3, neutral = 4
}

/// Cognitive-load level. Mirrors `axonos_sdk::Load`.
public enum Load: UInt8, CaseIterable, Sendable, Hashable, Codable {
    case low = 0, moderate = 1, high = 2
}

/// Signal-quality level. Mirrors `axonos_sdk::Quality`.
public enum Quality: UInt8, CaseIterable, Sendable, Hashable, Codable {
    case high = 0, moderate = 1, low = 2, noSignal = 3
}

/// Decoded intent kind. Mirrors `axonos_sdk::IntentKind`.
///
/// `unknown` is produced for a `kind_tag` or payload value this binding does
/// not recognize. Unknown observations are forward-compatible: the raw bytes
/// still decode, the typed meaning is simply withheld.
public enum IntentKind: Sendable, Hashable {
    case direction(Direction)
    case load(Load)
    case quality(Quality)
    case unknown
}

/// Stable 16-bit kind tags carried in the wire record. Mirror
/// `axonos_sdk::intent::KindTag`.
public enum KindTag {
    public static let direction: UInt16 = 0x0001
    public static let load: UInt16 = 0x0002
    public static let quality: UInt16 = 0x0003
}

/// A single intent observation — the application-facing data model.
///
/// # Wire format (stable for `kernelABIVersion == 1`)
///
/// `IntentObservation` is a fixed **32-byte, little-endian** record. The layout
/// is identical to the reference Rust SDK's `#[repr(C, align(8))]` struct, so a
/// record produced by the kernel decodes byte-for-byte the same in every
/// language binding:
///
/// | Offset | Size | Field          |
/// |:------ |:---- |:-------------- |
/// | 0      | 8    | `timestampMicros` (`UInt64`) |
/// | 8      | 2    | `kindTag` (`UInt16`)         |
/// | 10     | 2    | `confidenceRaw` — Q0.16 (`UInt16`) |
/// | 12     | 4    | `payload` (`[UInt8]`)        |
/// | 16     | 8    | `sessionId` (`UInt64`)       |
/// | 24     | 8    | `attestation` — truncated HMAC-SHA256 (`[UInt8]`) |
public struct IntentObservation: Equatable, Hashable, Sendable {
    /// Total wire size in bytes.
    public static let wireSize = 32

    /// Monotonic timestamp in microseconds.
    public let timestampMicros: UInt64
    /// Raw 16-bit kind tag (see ``KindTag``).
    public let kindTag: UInt16
    /// Raw Q0.16 confidence. `65535 == 1.0`. This is the deterministic value.
    public let confidenceRaw: UInt16
    /// Opaque 4-byte payload; byte 0 carries the typed enum value.
    public let payload: [UInt8]
    /// Opaque session identifier.
    public let sessionId: UInt64
    /// Attestation tag (8-byte truncated HMAC-SHA256).
    public let attestation: [UInt8]

    /// Designated initializer from already-decoded fields. `payload` is padded
    /// or truncated to 4 bytes and `attestation` to 8 bytes.
    public init(
        timestampMicros: UInt64,
        kindTag: UInt16,
        confidenceRaw: UInt16,
        payload: [UInt8],
        sessionId: UInt64,
        attestation: [UInt8]
    ) {
        self.timestampMicros = timestampMicros
        self.kindTag = kindTag
        self.confidenceRaw = confidenceRaw
        self.payload = Self.fit(payload, to: 4)
        self.sessionId = sessionId
        self.attestation = Self.fit(attestation, to: 8)
    }

    /// Confidence as a `Double` ratio in `0...1`, for **display only**.
    ///
    /// Computed as `confidenceRaw / 65535.0`. Floating-point division may
    /// differ slightly across architectures — compare ``confidenceRaw`` for
    /// any correctness logic, exactly as the Rust SDK instructs.
    public var confidence: Double {
        Double(confidenceRaw) / Double(AxonOS.confidenceDenominator)
    }

    /// The decoded typed kind, or ``IntentKind/unknown`` for unrecognized tags.
    public var kind: IntentKind {
        let value = payload.first ?? 0
        switch kindTag {
        case KindTag.direction:
            return Direction(rawValue: value).map(IntentKind.direction) ?? .unknown
        case KindTag.load:
            return Load(rawValue: value).map(IntentKind.load) ?? .unknown
        case KindTag.quality:
            return Quality(rawValue: value).map(IntentKind.quality) ?? .unknown
        default:
            return .unknown
        }
    }

    // MARK: - Typed factories (mirror new_direction / new_load / new_quality)

    /// Build a Direction observation. `confidenceRaw` is Q0.16 (`65535 == 1.0`).
    public static func direction(
        _ dir: Direction,
        confidenceRaw: UInt16,
        timestampMicros: UInt64,
        sessionId: UInt64,
        attestation: [UInt8] = []
    ) -> IntentObservation {
        IntentObservation(
            timestampMicros: timestampMicros, kindTag: KindTag.direction,
            confidenceRaw: confidenceRaw, payload: [dir.rawValue, 0, 0, 0],
            sessionId: sessionId, attestation: attestation)
    }

    /// Build a Load observation.
    public static func load(
        _ load: Load,
        confidenceRaw: UInt16,
        timestampMicros: UInt64,
        sessionId: UInt64,
        attestation: [UInt8] = []
    ) -> IntentObservation {
        IntentObservation(
            timestampMicros: timestampMicros, kindTag: KindTag.load,
            confidenceRaw: confidenceRaw, payload: [load.rawValue, 0, 0, 0],
            sessionId: sessionId, attestation: attestation)
    }

    /// Build a Quality observation. Confidence is always full (`65535`),
    /// matching the Rust SDK's `new_quality`.
    public static func quality(
        _ quality: Quality,
        timestampMicros: UInt64,
        sessionId: UInt64,
        attestation: [UInt8] = []
    ) -> IntentObservation {
        IntentObservation(
            timestampMicros: timestampMicros, kindTag: KindTag.quality,
            confidenceRaw: AxonOS.confidenceDenominator, payload: [quality.rawValue, 0, 0, 0],
            sessionId: sessionId, attestation: attestation)
    }

    // MARK: - Wire decode / encode

    /// Decode a 32-byte little-endian wire record. Returns `nil` unless exactly
    /// ``wireSize`` bytes are provided.
    public init?(wire bytes: [UInt8]) {
        guard bytes.count == Self.wireSize else { return nil }
        self.init(
            timestampMicros: Self.readU64LE(bytes, 0),
            kindTag: Self.readU16LE(bytes, 8),
            confidenceRaw: Self.readU16LE(bytes, 10),
            payload: Array(bytes[12..<16]),
            sessionId: Self.readU64LE(bytes, 16),
            attestation: Array(bytes[24..<32]))
    }

    /// Decode a 32-byte little-endian wire record from `Data`.
    public init?(wire data: Data) {
        self.init(wire: [UInt8](data))
    }

    /// Serialize back to the 32-byte little-endian wire record. Round-trips
    /// with ``init(wire:)-(_:)``.
    public var wireBytes: [UInt8] {
        var out = [UInt8](repeating: 0, count: Self.wireSize)
        Self.writeU64LE(&out, 0, timestampMicros)
        Self.writeU16LE(&out, 8, kindTag)
        Self.writeU16LE(&out, 10, confidenceRaw)
        for i in 0..<4 { out[12 + i] = payload[i] }
        Self.writeU64LE(&out, 16, sessionId)
        for i in 0..<8 { out[24 + i] = attestation[i] }
        return out
    }

    // MARK: - Little-endian helpers

    private static func fit(_ a: [UInt8], to n: Int) -> [UInt8] {
        if a.count == n { return a }
        if a.count > n { return Array(a.prefix(n)) }
        return a + [UInt8](repeating: 0, count: n - a.count)
    }

    private static func readU16LE(_ b: [UInt8], _ o: Int) -> UInt16 {
        UInt16(b[o]) | (UInt16(b[o + 1]) << 8)
    }

    private static func readU64LE(_ b: [UInt8], _ o: Int) -> UInt64 {
        var v: UInt64 = 0
        for i in 0..<8 { v |= UInt64(b[o + i]) << (8 * UInt64(i)) }
        return v
    }

    private static func writeU16LE(_ b: inout [UInt8], _ o: Int, _ v: UInt16) {
        b[o] = UInt8(v & 0xFF)
        b[o + 1] = UInt8((v >> 8) & 0xFF)
    }

    private static func writeU64LE(_ b: inout [UInt8], _ o: Int, _ v: UInt64) {
        for i in 0..<8 { b[o + i] = UInt8((v >> (8 * UInt64(i))) & 0xFF) }
    }
}

extension IntentObservation: CustomStringConvertible {
    public var description: String {
        "IntentObservation(kind: \(kind), @\(timestampMicros)µs, confidence: \(confidenceRaw)/65535, session: 0x\(String(sessionId, radix: 16)))"
    }
}
