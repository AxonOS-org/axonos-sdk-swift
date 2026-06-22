// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

import Foundation

/// An application's declaration of which intent classes it wants and at what
/// rate. The kernel rejects manifests that are malformed, request prohibited
/// capabilities, or ask for a rate above the per-capability limit.
///
/// The chainable surface mirrors the published Swift API and carries the same
/// validation semantics as the reference Rust `ManifestBuilder`:
///
/// ```swift
/// let manifest = try Manifest(appId: "com.example.aac")
///     .capability(.navigation)
///     .maxRateHz(50)
/// ```
///
/// Validation runs at ``validated()`` (and automatically inside
/// ``IntentStream/connect(_:transport:)``).
public struct Manifest: Equatable, Sendable {
    /// Maximum `appId` length in UTF-8 bytes. Mirrors `MAX_APP_ID_LEN`.
    public static let maxAppIdLength = 64
    /// Maximum display-string length in UTF-8 bytes. Mirrors `MAX_DISPLAY_STRING_LEN`.
    public static let maxDisplayStringLength = 64

    /// Reverse-DNS application identifier.
    public let appId: String
    /// Declared capabilities.
    public private(set) var capabilities: CapabilitySet
    /// Requested maximum delivery rate, in Hz (before per-capability clamping).
    public private(set) var maxRateHz: UInt32
    /// Optional display name.
    public private(set) var name: String?
    /// Optional vendor string.
    public private(set) var vendor: String?

    /// Create a manifest for `appId`.
    ///
    /// - Throws: ``AxonOSError/manifestRejected(_:)`` with ``ManifestRejection/malformed``
    ///   if `appId` is empty or longer than ``maxAppIdLength`` UTF-8 bytes.
    public init(appId: String) throws {
        guard !appId.isEmpty, appId.utf8.count <= Self.maxAppIdLength else {
            throw AxonOSError.manifestRejected(.malformed)
        }
        self.appId = appId
        self.capabilities = CapabilitySet()
        self.maxRateHz = 0
        self.name = nil
        self.vendor = nil
    }

    /// Declare a capability. Infallible; returns a new manifest.
    public func capability(_ capability: Capability) -> Manifest {
        var m = self
        m.capabilities.insert(capability)
        return m
    }

    /// Request a maximum delivery rate, in Hz. The effective rate per capability
    /// is `min(maxRateHz, capability.kernelRateLimitHz)`.
    public func maxRateHz(_ hz: UInt32) -> Manifest {
        var m = self
        m.maxRateHz = hz
        return m
    }

    /// Set a display name.
    /// - Throws: ``ManifestRejection/malformed`` if longer than ``maxDisplayStringLength``.
    public func name(_ name: String) throws -> Manifest {
        guard name.utf8.count <= Self.maxDisplayStringLength else {
            throw AxonOSError.manifestRejected(.malformed)
        }
        var m = self
        m.name = name
        return m
    }

    /// Set a vendor string.
    /// - Throws: ``ManifestRejection/malformed`` if longer than ``maxDisplayStringLength``.
    public func vendor(_ vendor: String) throws -> Manifest {
        guard vendor.utf8.count <= Self.maxDisplayStringLength else {
            throw AxonOSError.manifestRejected(.malformed)
        }
        var m = self
        m.vendor = vendor
        return m
    }

    /// `true` if `capability` is declared.
    public func allows(_ capability: Capability) -> Bool {
        capabilities.contains(capability)
    }

    /// Effective delivery rate for `capability`: `min(maxRateHz, kernel limit)`.
    public func effectiveRateHz(for capability: Capability) -> UInt32 {
        min(maxRateHz, capability.kernelRateLimitHz)
    }

    /// Validate against the kernel's manifest rules. Mirrors the Rust
    /// `ManifestBuilder::build` checks.
    ///
    /// - Throws: ``ManifestRejection/malformed`` if no capabilities are declared
    ///   or `maxRateHz` is zero; ``ManifestRejection/rateTooHigh`` if `maxRateHz`
    ///   exceeds the minimum per-capability kernel limit across the declared set.
    /// - Returns: the validated manifest (unchanged), for chaining.
    @discardableResult
    public func validated() throws -> Manifest {
        if capabilities.isEmpty || maxRateHz == 0 {
            throw AxonOSError.manifestRejected(.malformed)
        }
        let minLimit = capabilities.elements.map(\.kernelRateLimitHz).min() ?? 0
        if maxRateHz > minLimit {
            throw AxonOSError.manifestRejected(.rateTooHigh)
        }
        return self
    }
}
