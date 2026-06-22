// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>

import XCTest
@testable import AxonOS

final class ErrorTests: XCTestCase {

    func testTerminalClassificationMatchesSpec() {
        // Terminal.
        XCTAssertTrue(AxonOSError.consentWithdrawn.isTerminal)
        XCTAssertTrue(AxonOSError.abiMismatch(sdk: 1, kernel: 2).isTerminal)
        XCTAssertTrue(AxonOSError.manifestRejected(.malformed).isTerminal)
        XCTAssertTrue(AxonOSError.attestationFailed.isTerminal)
        // Retriable.
        XCTAssertFalse(AxonOSError.consentSuspended.isTerminal)
        XCTAssertFalse(AxonOSError.streamOverflow(dropped: 5).isTerminal)
        XCTAssertFalse(AxonOSError.capabilityNotDeclared(.navigation).isTerminal)
        XCTAssertFalse(AxonOSError.transportUnreachable(.disconnected).isTerminal)
        XCTAssertFalse(AxonOSError.rateLimitExceeded(maxRateHz: 50).isTerminal)
        // isRetriable is the complement.
        XCTAssertTrue(AxonOSError.consentSuspended.isRetriable)
        XCTAssertFalse(AxonOSError.consentWithdrawn.isRetriable)
    }

    func testStableErrorCodes() {
        XCTAssertEqual(AxonOSError.transportUnreachable(.timeout).code, .transportUnreachable)
        XCTAssertEqual(AxonOSError.transportUnreachable(.timeout).code.rawValue, 0x0101)
        XCTAssertEqual(AxonOSError.abiMismatch(sdk: 1, kernel: 2).code.rawValue, 0x0102)
        XCTAssertEqual(AxonOSError.capabilityNotDeclared(.navigation).code.rawValue, 0x0201)
        XCTAssertEqual(AxonOSError.manifestRejected(.malformed).code.rawValue, 0x0202)
        XCTAssertEqual(AxonOSError.rateLimitExceeded(maxRateHz: 50).code.rawValue, 0x0203)
        XCTAssertEqual(AxonOSError.consentSuspended.code.rawValue, 0x0301)
        XCTAssertEqual(AxonOSError.consentWithdrawn.code.rawValue, 0x0302)
        XCTAssertEqual(AxonOSError.protocolError(.truncatedHeader).code.rawValue, 0x0401)
        XCTAssertEqual(AxonOSError.attestationFailed.code.rawValue, 0x0402)
        XCTAssertEqual(AxonOSError.streamOverflow(dropped: 1).code.rawValue, 0x0403)
        XCTAssertEqual(AxonOSError.io("disk").code.rawValue, 0x0501)
    }
}
