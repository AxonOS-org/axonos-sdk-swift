// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

import Foundation

/// A compact set of ``Capability`` values, backed by a `UInt32` bitset.
///
/// Mirrors `axonos_sdk::CapabilitySet`. Each capability occupies one bit
/// (`1 << rawValue`); only the low ``Capability/allCases`` bits are valid.
public struct CapabilitySet: Equatable, Hashable, Sendable, Codable {
    /// Raw bitset. Bit `n` set means ``Capability`` with raw value `n` is present.
    public private(set) var rawValue: UInt32

    /// Mask of all valid capability bits.
    public static let validMask: UInt32 = (1 << UInt32(Capability.allCases.count)) - 1

    /// Empty set.
    public init() { self.rawValue = 0 }

    /// Construct from a raw bitset, keeping only valid bits.
    public init(rawValue: UInt32) { self.rawValue = rawValue & Self.validMask }

    /// Construct from a sequence of capabilities.
    public init<S: Sequence>(_ capabilities: S) where S.Element == Capability {
        var bits: UInt32 = 0
        for c in capabilities { bits |= (1 << UInt32(c.rawValue)) }
        self.rawValue = bits & Self.validMask
    }

    /// The full set of every capability. Mirrors `CapabilitySet::all()`.
    public static var all: CapabilitySet { CapabilitySet(rawValue: validMask) }

    /// `true` if no capabilities are present.
    public var isEmpty: Bool { rawValue == 0 }

    /// Number of capabilities in the set.
    public var count: Int { rawValue.nonzeroBitCount }

    /// `true` if `capability` is present.
    public func contains(_ capability: Capability) -> Bool {
        (rawValue & (1 << UInt32(capability.rawValue))) != 0
    }

    /// Insert `capability`.
    public mutating func insert(_ capability: Capability) {
        rawValue |= (1 << UInt32(capability.rawValue))
    }

    /// Remove `capability`.
    public mutating func remove(_ capability: Capability) {
        rawValue &= ~(1 << UInt32(capability.rawValue))
    }

    /// Set union.
    public func union(_ other: CapabilitySet) -> CapabilitySet {
        CapabilitySet(rawValue: rawValue | other.rawValue)
    }

    /// Set intersection.
    public func intersection(_ other: CapabilitySet) -> CapabilitySet {
        CapabilitySet(rawValue: rawValue & other.rawValue)
    }

    /// Elements in `self` not in `other`.
    public func subtracting(_ other: CapabilitySet) -> CapabilitySet {
        CapabilitySet(rawValue: rawValue & ~other.rawValue)
    }

    /// `true` if every element of `self` is also in `other`.
    public func isSubset(of other: CapabilitySet) -> Bool {
        (rawValue & other.rawValue) == rawValue
    }

    /// `true` if `self` and `other` share no elements.
    public func isDisjoint(with other: CapabilitySet) -> Bool {
        (rawValue & other.rawValue) == 0
    }

    /// The capabilities present, in ABI order.
    public var elements: [Capability] {
        Capability.allCases.filter { contains($0) }
    }
}
