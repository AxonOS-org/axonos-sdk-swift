// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

import Foundation

/// A source of decoded ``IntentObservation`` records for an ``IntentStream``.
///
/// Abstracting the transport keeps the typed stream API stable while the
/// underlying delivery mechanism evolves. The live kernel transport will be
/// delivered by the C-FFI binding (`axonos-sdk-ffi`); today the package ships
/// ``ReplayTransport`` for development, tests, and offline analysis of recorded
/// sessions.
public protocol ObservationTransport: Sendable {
    /// Kernel ABI version this transport speaks. Checked at connect time.
    var kernelABIVersion: UInt32 { get }

    /// Negotiate the connection for `manifest`. Throws to refuse the connection.
    func handshake(manifest: Manifest) async throws

    /// The next observation, or `nil` at end of stream.
    func next() async throws -> IntentObservation?
}

/// An in-memory transport that replays a fixed sequence of observations.
///
/// Useful for unit tests, golden-vector checks, and replaying captured sessions
/// offline. It is a real, fully functional transport — it simply sources its
/// observations from memory rather than a live kernel.
public actor ReplayTransport: ObservationTransport {
    public nonisolated let kernelABIVersion: UInt32
    private let observations: [IntentObservation]
    private var index = 0

    /// Replay already-decoded observations.
    public init(
        observations: [IntentObservation],
        kernelABIVersion: UInt32 = AxonOS.kernelABIVersion
    ) {
        self.observations = observations
        self.kernelABIVersion = kernelABIVersion
    }

    /// Replay raw wire frames; each must be exactly ``IntentObservation/wireSize`` bytes.
    ///
    /// - Throws: ``AxonOSError/protocolError(_:)`` (``ProtocolFault/truncatedBody``)
    ///   if any frame is not a valid 32-byte record.
    public init(
        wireFrames: [[UInt8]],
        kernelABIVersion: UInt32 = AxonOS.kernelABIVersion
    ) throws {
        var decoded: [IntentObservation] = []
        decoded.reserveCapacity(wireFrames.count)
        for frame in wireFrames {
            guard let obs = IntentObservation(wire: frame) else {
                throw AxonOSError.protocolError(.truncatedBody)
            }
            decoded.append(obs)
        }
        self.observations = decoded
        self.kernelABIVersion = kernelABIVersion
    }

    /// Number of observations remaining.
    public var remaining: Int { observations.count - index }

    public func handshake(manifest: Manifest) async throws {
        _ = try manifest.validated()
    }

    public func next() async throws -> IntentObservation? {
        guard index < observations.count else { return nil }
        defer { index += 1 }
        return observations[index]
    }
}

/// Placeholder for the live kernel transport over the C-FFI binding.
///
/// The live transport is delivered by `axonos-sdk-ffi` (on the SDK roadmap).
/// Until it lands, every operation throws
/// ``AxonOSError/transportUnreachable(_:)`` so callers fail fast and explicitly.
/// Use ``IntentStream/connect(_:transport:)`` with a custom transport such as
/// ``ReplayTransport`` today.
public struct LiveKernelTransport: ObservationTransport {
    public let kernelABIVersion: UInt32

    public init() { self.kernelABIVersion = AxonOS.kernelABIVersion }

    public func handshake(manifest: Manifest) async throws {
        throw AxonOSError.transportUnreachable(.endpointNotFound)
    }

    public func next() async throws -> IntentObservation? {
        throw AxonOSError.transportUnreachable(.endpointNotFound)
    }
}
