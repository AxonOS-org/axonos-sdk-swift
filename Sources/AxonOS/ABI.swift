// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

import Foundation

/// ABI-level constants shared by every AxonOS SDK binding.
///
/// These values mirror the reference Rust SDK (`axonos-sdk`) one-for-one.
/// Any binding that decodes the AxonOS intent stream must agree on them, which
/// is what makes the wire format identical across Rust, Python, JavaScript,
/// Java, and Swift.
public enum AxonOS {
    /// Kernel ABI version this binding speaks. Mirrors
    /// `axonos_sdk::KERNEL_ABI_VERSION`.
    ///
    /// A stream connection performs an ABI handshake at connect time; a kernel
    /// reporting a different version is refused with ``AxonOSError/abiMismatch(sdk:kernel:)``.
    public static let kernelABIVersion: UInt32 = 1

    /// Denominator for the unsigned Q0.16 fixed-point confidence field.
    /// Mirrors `axonos_sdk::CONFIDENCE_DENOM` (`u16::MAX`).
    ///
    /// `confidence = confidenceRaw / 65535.0`. The raw `UInt16` is the
    /// deterministic value; the floating-point ratio is for display only.
    public static let confidenceDenominator: UInt16 = 65535

    /// Consent protocol version negotiated with the kernel mesh layer.
    /// Mirrors `axonos_sdk::CONSENT_PROTOCOL_VERSION`.
    public static let consentProtocolVersion = "0.2.0"

    /// Version of this Swift binding.
    ///
    /// This is the binding's own version and is independent of the kernel ABI
    /// version, which is pinned at ``kernelABIVersion``.
    public static let sdkVersion = "0.1.0"
}
