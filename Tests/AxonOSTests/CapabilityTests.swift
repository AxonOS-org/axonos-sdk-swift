// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>

import XCTest
@testable import AxonOS

final class CapabilityTests: XCTestCase {

    func testRawValuesMatchABI() {
        XCTAssertEqual(Capability.navigation.rawValue, 0)
        XCTAssertEqual(Capability.workloadAdvisory.rawValue, 1)
        XCTAssertEqual(Capability.sessionQuality.rawValue, 2)
        XCTAssertEqual(Capability.artifactEvents.rawValue, 3)
    }

    func testKernelRateLimits() {
        XCTAssertEqual(Capability.navigation.kernelRateLimitHz, 50)
        XCTAssertEqual(Capability.workloadAdvisory.kernelRateLimitHz, 1)
        XCTAssertEqual(Capability.sessionQuality.kernelRateLimitHz, 2)
        XCTAssertEqual(Capability.artifactEvents.kernelRateLimitHz, 10)
    }

    func testWireNames() {
        XCTAssertEqual(Capability.navigation.wireName, "navigation")
        XCTAssertEqual(Capability.workloadAdvisory.wireName, "workload_advisory")
        XCTAssertEqual(Capability.sessionQuality.wireName, "session_quality")
        XCTAssertEqual(Capability.artifactEvents.wireName, "artifact_events")
    }

    func testAllInABIOrder() {
        XCTAssertEqual(Capability.all, [.navigation, .workloadAdvisory, .sessionQuality, .artifactEvents])
        XCTAssertEqual(Capability.allCases.count, 4)
    }

    func testSetInsertContainsCount() {
        var set = CapabilitySet()
        XCTAssertTrue(set.isEmpty)
        set.insert(.navigation)
        set.insert(.artifactEvents)
        XCTAssertTrue(set.contains(.navigation))
        XCTAssertTrue(set.contains(.artifactEvents))
        XCTAssertFalse(set.contains(.sessionQuality))
        XCTAssertEqual(set.count, 2)
        set.remove(.navigation)
        XCTAssertFalse(set.contains(.navigation))
        XCTAssertEqual(set.count, 1)
    }

    func testSetAlgebra() {
        let a = CapabilitySet([.navigation, .sessionQuality])
        let b = CapabilitySet([.sessionQuality, .artifactEvents])
        XCTAssertEqual(a.union(b), CapabilitySet([.navigation, .sessionQuality, .artifactEvents]))
        XCTAssertEqual(a.intersection(b), CapabilitySet([.sessionQuality]))
        XCTAssertEqual(a.subtracting(b), CapabilitySet([.navigation]))
        XCTAssertTrue(CapabilitySet([.navigation]).isSubset(of: a))
        XCTAssertFalse(a.isSubset(of: b))
        XCTAssertTrue(CapabilitySet([.navigation]).isDisjoint(with: b))
        XCTAssertFalse(a.isDisjoint(with: b))
    }

    func testAllAndValidMask() {
        let all = CapabilitySet.all
        XCTAssertEqual(all.count, 4)
        for c in Capability.allCases { XCTAssertTrue(all.contains(c)) }
        XCTAssertEqual(CapabilitySet.validMask, 0b1111)
        // Out-of-range bits are masked away.
        XCTAssertEqual(CapabilitySet(rawValue: 0xFFFF_FFFF), all)
    }

    func testElementsOrder() {
        let set = CapabilitySet([.artifactEvents, .navigation])
        XCTAssertEqual(set.elements, [.navigation, .artifactEvents])
    }
}
