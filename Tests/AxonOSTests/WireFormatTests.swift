// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>

import XCTest
@testable import AxonOS

final class WireFormatTests: XCTestCase {

    /// A hand-built 32-byte little-endian record with known values at each
    /// documented offset. Built by hand (not via the encoder) so the decoder is
    /// tested independently.
    private func knownRecord() -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 32)
        // offset 0: timestamp_us = 0x0102030405060708 (LE)
        b[0] = 0x08; b[1] = 0x07; b[2] = 0x06; b[3] = 0x05
        b[4] = 0x04; b[5] = 0x03; b[6] = 0x02; b[7] = 0x01
        // offset 8: kind_tag = 0x0001 (Direction)
        b[8] = 0x01; b[9] = 0x00
        // offset 10: quality_raw = 0x8000 = 32768
        b[10] = 0x00; b[11] = 0x80
        // offset 12: payload[0] = 0x01 (Right)
        b[12] = 0x01
        // offset 16: session_id = 0x1122334455667788 (LE)
        b[16] = 0x88; b[17] = 0x77; b[18] = 0x66; b[19] = 0x55
        b[20] = 0x44; b[21] = 0x33; b[22] = 0x22; b[23] = 0x11
        // offset 24: attestation
        let att: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x11, 0x22, 0x33]
        for i in 0..<8 { b[24 + i] = att[i] }
        return b
    }

    func testDecodesAllFieldsAtCorrectOffsets() throws {
        let obs = try XCTUnwrap(IntentObservation(wire: knownRecord()))
        XCTAssertEqual(obs.timestampMicros, 0x0102_0304_0506_0708)
        XCTAssertEqual(obs.kindTag, KindTag.direction)
        XCTAssertEqual(obs.confidenceRaw, 32768)
        XCTAssertEqual(obs.sessionId, 0x1122_3344_5566_7788)
        XCTAssertEqual(obs.attestation, [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x11, 0x22, 0x33])
        XCTAssertEqual(obs.kind, .direction(.right))
    }

    func testConfidenceRatioIsDisplayValue() throws {
        let half = try XCTUnwrap(IntentObservation(wire: knownRecord()))
        XCTAssertEqual(half.confidence, 0.5, accuracy: 0.001)

        let full = IntentObservation.quality(.high, timestampMicros: 1, sessionId: 2)
        XCTAssertEqual(full.confidenceRaw, 65535)
        XCTAssertEqual(full.confidence, 1.0, accuracy: 1e-9)

        let zero = IntentObservation.direction(.up, confidenceRaw: 0, timestampMicros: 1, sessionId: 2)
        XCTAssertEqual(zero.confidence, 0.0)
    }

    func testWireRoundTrip() throws {
        let bytes = knownRecord()
        let obs = try XCTUnwrap(IntentObservation(wire: bytes))
        XCTAssertEqual(obs.wireBytes, bytes, "re-encoding must reproduce the original record")
        XCTAssertEqual(obs.wireBytes.count, IntentObservation.wireSize)
    }

    func testWrongLengthIsRejected() {
        XCTAssertNil(IntentObservation(wire: [UInt8](repeating: 0, count: 31)))
        XCTAssertNil(IntentObservation(wire: [UInt8](repeating: 0, count: 33)))
        XCTAssertNil(IntentObservation(wire: []))
    }

    func testUnknownKindAndPayloadDecodeAsUnknown() {
        // Unrecognized kind_tag.
        var b = knownRecord()
        b[8] = 0xFF; b[9] = 0x00
        XCTAssertEqual(IntentObservation(wire: b)?.kind, .unknown)

        // Known tag (Direction) but out-of-range payload value.
        var c = knownRecord()
        c[12] = 99
        XCTAssertEqual(IntentObservation(wire: c)?.kind, .unknown)
    }

    func testTypedFactoriesProduceCorrectKinds() {
        XCTAssertEqual(
            IntentObservation.direction(.left, confidenceRaw: 100, timestampMicros: 1, sessionId: 1).kind,
            .direction(.left))
        XCTAssertEqual(
            IntentObservation.load(.high, confidenceRaw: 100, timestampMicros: 1, sessionId: 1).kind,
            .load(.high))
        XCTAssertEqual(
            IntentObservation.quality(.noSignal, timestampMicros: 1, sessionId: 1).kind,
            .quality(.noSignal))
    }
}
