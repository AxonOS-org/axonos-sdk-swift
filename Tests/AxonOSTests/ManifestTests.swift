// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>

import XCTest
@testable import AxonOS

final class ManifestTests: XCTestCase {

    func testEmptyAppIdThrowsMalformed() {
        XCTAssertThrowsError(try Manifest(appId: "")) { error in
            XCTAssertEqual(error as? AxonOSError, .manifestRejected(.malformed))
        }
    }

    func testOverlongAppIdThrowsMalformed() {
        let tooLong = String(repeating: "a", count: 65)
        XCTAssertThrowsError(try Manifest(appId: tooLong)) { error in
            XCTAssertEqual(error as? AxonOSError, .manifestRejected(.malformed))
        }
    }

    func testMaxLengthAppIdAccepted() throws {
        let exact = String(repeating: "a", count: 64)
        let m = try Manifest(appId: exact)
        XCTAssertEqual(m.appId, exact)
    }

    func testNoCapabilityIsMalformed() throws {
        let m = try Manifest(appId: "com.test").maxRateHz(50)
        XCTAssertThrowsError(try m.validated()) { error in
            XCTAssertEqual(error as? AxonOSError, .manifestRejected(.malformed))
        }
    }

    func testZeroRateIsMalformed() throws {
        let m = try Manifest(appId: "com.test").capability(.navigation)
        XCTAssertThrowsError(try m.validated()) { error in
            XCTAssertEqual(error as? AxonOSError, .manifestRejected(.malformed))
        }
    }

    func testRateAboveCapabilityLimitIsRateTooHigh() throws {
        // Navigation kernel limit is 50 Hz.
        let m = try Manifest(appId: "com.test").capability(.navigation).maxRateHz(100)
        XCTAssertThrowsError(try m.validated()) { error in
            XCTAssertEqual(error as? AxonOSError, .manifestRejected(.rateTooHigh))
        }
    }

    func testRateTooHighUsesMinimumAcrossDeclaredSet() throws {
        // Navigation (50) + SessionQuality (2): the min limit is 2.
        let ok = try Manifest(appId: "com.test")
            .capability(.navigation).capability(.sessionQuality).maxRateHz(2)
        XCTAssertNoThrow(try ok.validated())

        let bad = try Manifest(appId: "com.test")
            .capability(.navigation).capability(.sessionQuality).maxRateHz(3)
        XCTAssertThrowsError(try bad.validated()) { error in
            XCTAssertEqual(error as? AxonOSError, .manifestRejected(.rateTooHigh))
        }
    }

    func testValidManifestPasses() throws {
        let m = try Manifest(appId: "com.example.aac")
            .capability(.navigation)
            .maxRateHz(50)
        XCTAssertNoThrow(try m.validated())
        XCTAssertTrue(m.allows(.navigation))
        XCTAssertFalse(m.allows(.artifactEvents))
    }

    func testEffectiveRateClamping() throws {
        let m = try Manifest(appId: "com.test")
            .capability(.navigation).capability(.sessionQuality).maxRateHz(50)
        XCTAssertEqual(m.effectiveRateHz(for: .navigation), 50)   // min(50, 50)
        XCTAssertEqual(m.effectiveRateHz(for: .sessionQuality), 2) // min(50, 2)
    }

    func testOverlongNameAndVendorThrow() throws {
        let base = try Manifest(appId: "com.test")
        let tooLong = String(repeating: "x", count: 65)
        XCTAssertThrowsError(try base.name(tooLong)) { error in
            XCTAssertEqual(error as? AxonOSError, .manifestRejected(.malformed))
        }
        XCTAssertThrowsError(try base.vendor(tooLong)) { error in
            XCTAssertEqual(error as? AxonOSError, .manifestRejected(.malformed))
        }
        let okNamed = try base.name("Cursor").vendor("Example Labs")
        XCTAssertEqual(okNamed.name, "Cursor")
        XCTAssertEqual(okNamed.vendor, "Example Labs")
    }
}
