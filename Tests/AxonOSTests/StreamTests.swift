// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>

import XCTest
@testable import AxonOS

final class StreamTests: XCTestCase {

    private func validManifest() throws -> Manifest {
        try Manifest(appId: "com.test.stream").capability(.navigation).maxRateHz(50)
    }

    private func sampleObservations() -> [IntentObservation] {
        [
            .direction(.up, confidenceRaw: 60000, timestampMicros: 1_000, sessionId: 7),
            .direction(.right, confidenceRaw: 45000, timestampMicros: 2_000, sessionId: 7),
            .quality(.high, timestampMicros: 3_000, sessionId: 7),
        ]
    }

    func testReplayIteration() async throws {
        let transport = ReplayTransport(observations: sampleObservations())
        let stream = try await IntentStream.connect(try validManifest(), transport: transport)

        var collected: [IntentKind] = []
        for try await obs in stream { collected.append(obs.kind) }

        XCTAssertEqual(collected, [.direction(.up), .direction(.right), .quality(.high)])
    }

    func testWireFrameReplayMatchesDecodedObservations() async throws {
        let frames = sampleObservations().map(\.wireBytes)
        let transport = try ReplayTransport(wireFrames: frames)
        let stream = try await IntentStream.connect(try validManifest(), transport: transport)

        var count = 0
        for try await obs in stream {
            XCTAssertEqual(obs.timestampMicros % 1_000, 0)
            count += 1
        }
        XCTAssertEqual(count, 3)
    }

    func testBadWireFrameRejected() {
        XCTAssertThrowsError(try ReplayTransport(wireFrames: [[UInt8](repeating: 0, count: 16)])) { error in
            XCTAssertEqual(error as? AxonOSError, .protocolError(.truncatedBody))
        }
    }

    func testABIMismatchRefusesConnection() async throws {
        let transport = ReplayTransport(observations: [], kernelABIVersion: 2)
        do {
            _ = try await IntentStream.connect(try validManifest(), transport: transport)
            XCTFail("expected abiMismatch")
        } catch let error as AxonOSError {
            XCTAssertEqual(error, .abiMismatch(sdk: 1, kernel: 2))
            XCTAssertTrue(error.isTerminal)
        }
    }

    func testInvalidManifestRefusedAtConnect() async throws {
        // Missing capability -> malformed, surfaced by connect's validation.
        let manifest = try Manifest(appId: "com.test").maxRateHz(50)
        let transport = ReplayTransport(observations: [])
        do {
            _ = try await IntentStream.connect(manifest, transport: transport)
            XCTFail("expected manifestRejected(.malformed)")
        } catch let error as AxonOSError {
            XCTAssertEqual(error, .manifestRejected(.malformed))
        }
    }

    func testLiveTransportNotYetAvailable() async throws {
        // The default live transport is not wired until the C-FFI binding ships.
        do {
            _ = try await IntentStream.connect(try validManifest())
            XCTFail("expected transportUnreachable")
        } catch let error as AxonOSError {
            XCTAssertEqual(error, .transportUnreachable(.endpointNotFound))
            XCTAssertTrue(error.isRetriable)
        }
    }
}
