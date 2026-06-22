// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

import Foundation

/// A capability an application may request in its ``Manifest``.
///
/// Capabilities gate which intent classes the kernel will deliver. The kernel
/// enforces a per-capability maximum rate regardless of what the manifest
/// requests, so a capability is both a permission and a rate ceiling.
///
/// Raw values and rate limits mirror the reference Rust SDK
/// (`axonos_sdk::Capability`) exactly.
public enum Capability: UInt8, CaseIterable, Sendable, Hashable, Codable {
    /// Directional navigation intents (cursor, wheelchair, menu). Kernel limit: 50 Hz.
    case navigation = 0
    /// Cognitive-load advisories (workload high/low). Kernel limit: 1 Hz.
    case workloadAdvisory = 1
    /// Session signal-quality reports. Kernel limit: 2 Hz.
    case sessionQuality = 2
    /// Artifact / electrode events. Kernel limit: 10 Hz.
    case artifactEvents = 3

    /// The kernel-enforced maximum delivery rate for this capability, in Hz.
    ///
    /// The effective rate for a capability is
    /// `min(manifest.maxRateHz, capability.kernelRateLimitHz)`.
    public var kernelRateLimitHz: UInt32 {
        switch self {
        case .navigation:       return 50
        case .workloadAdvisory: return 1
        case .sessionQuality:   return 2
        case .artifactEvents:   return 10
        }
    }

    /// Stable lower-snake-case wire name, matching the Rust SDK and the
    /// `serde(rename_all = "snake_case")` serialization.
    public var wireName: String {
        switch self {
        case .navigation:       return "navigation"
        case .workloadAdvisory: return "workload_advisory"
        case .sessionQuality:   return "session_quality"
        case .artifactEvents:   return "artifact_events"
        }
    }

    /// All capabilities, in ABI order. Mirrors `Capability::all()`.
    public static let all: [Capability] = [
        .navigation, .workloadAdvisory, .sessionQuality, .artifactEvents,
    ]
}
