// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

import Foundation

/// An asynchronous stream of typed ``IntentObservation`` records.
///
/// `IntentStream` is an `AsyncSequence`, so it is consumed with `for try await`:
///
/// ```swift
/// let manifest = try Manifest(appId: "com.example.aac")
///     .capability(.navigation)
///     .maxRateHz(50)
///
/// let stream = try await IntentStream.connect(manifest, transport: transport)
/// for try await obs in stream {
///     print("\(obs.kind) @ \(obs.timestampMicros)µs")
/// }
/// ```
///
/// Connecting performs an ABI-version handshake and validates the manifest
/// before any observation flows, mirroring the kernel-side guarantees of the
/// reference Rust SDK.
public struct IntentStream: AsyncSequence, Sendable {
    public typealias Element = IntentObservation

    /// The manifest this stream was opened with.
    public let manifest: Manifest
    private let transport: ObservationTransport

    init(manifest: Manifest, transport: ObservationTransport) {
        self.manifest = manifest
        self.transport = transport
    }

    /// Connect over an explicit transport.
    ///
    /// Performs, in order: an ABI-version check (``AxonOSError/abiMismatch(sdk:kernel:)``
    /// on mismatch), manifest validation (``Manifest/validated()``), and the
    /// transport handshake. Only then is the stream returned.
    public static func connect(
        _ manifest: Manifest,
        transport: ObservationTransport
    ) async throws -> IntentStream {
        guard transport.kernelABIVersion == AxonOS.kernelABIVersion else {
            throw AxonOSError.abiMismatch(
                sdk: AxonOS.kernelABIVersion, kernel: transport.kernelABIVersion)
        }
        _ = try manifest.validated()
        try await transport.handshake(manifest: manifest)
        return IntentStream(manifest: manifest, transport: transport)
    }

    /// Connect to the live kernel.
    ///
    /// The live kernel transport is delivered by the C-FFI binding
    /// (`axonos-sdk-ffi`, on the SDK roadmap). Until it lands this throws
    /// ``AxonOSError/transportUnreachable(_:)``. Use
    /// ``connect(_:transport:)`` with a custom transport (for example
    /// ``ReplayTransport``) today.
    public static func connect(_ manifest: Manifest) async throws -> IntentStream {
        try await connect(manifest, transport: LiveKernelTransport())
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(transport: transport)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        let transport: ObservationTransport

        public mutating func next() async throws -> IntentObservation? {
            try await transport.next()
        }
    }
}
