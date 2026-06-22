// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

import Foundation

/// Stable machine-readable error code. Mirrors `axonos_sdk::ErrorCode`.
/// Values are deliberately sparse (layer-prefixed), not a dense index.
public enum ErrorCode: UInt16, Sendable, Hashable {
    case transportUnreachable = 0x0101
    case abiMismatch = 0x0102
    case capabilityNotDeclared = 0x0201
    case manifestRejected = 0x0202
    case rateLimitExceeded = 0x0203
    case consentSuspended = 0x0301
    case consentWithdrawn = 0x0302
    case protocolError = 0x0401
    case attestationFailed = 0x0402
    case streamOverflow = 0x0403
    case io = 0x0501
}

/// Transport fault reasons. Mirrors `axonos_sdk::TransportFault`.
public enum TransportFault: Sendable, Hashable {
    case endpointNotFound
    case permissionDenied
    case connectionRefused
    case disconnected
    case timeout
    /// Internal state corruption; the SDK refuses to proceed.
    case `internal`
}

/// Manifest rejection reasons. Mirrors `axonos_sdk::ManifestRejection`.
public enum ManifestRejection: Sendable, Hashable {
    case invalidSignature
    case prohibitedCapability
    case rateTooHigh
    case malformed
    case duplicateAppId
}

/// Wire-format protocol errors. Mirrors `axonos_sdk::ProtocolFault`.
public enum ProtocolFault: Sendable, Hashable {
    case truncatedHeader
    case truncatedBody
    case unknownFrameType(UInt16)
    case missingField(String)
    case invalidFieldType(String)
    case frameTooLarge(size: UInt32, max: UInt32)
}

/// Errors surfaced by the AxonOS SDK. Mirrors `axonos_sdk::Error`, including
/// the terminal-vs-retriable classification a subscription must honor.
public enum AxonOSError: Error, Sendable, Hashable {
    /// The kernel transport could not be reached.
    case transportUnreachable(TransportFault)
    /// SDK and kernel disagree on the ABI version.
    case abiMismatch(sdk: UInt32, kernel: UInt32)
    /// A capability was used that the manifest never declared.
    case capabilityNotDeclared(Capability)
    /// The kernel rejected the manifest.
    case manifestRejected(ManifestRejection)
    /// The requested rate exceeded the kernel's limit.
    case rateLimitExceeded(maxRateHz: UInt32)
    /// Consent is temporarily suspended (retriable).
    case consentSuspended
    /// Consent was withdrawn (terminal).
    case consentWithdrawn
    /// A wire-format protocol error.
    case protocolError(ProtocolFault)
    /// Attestation verification failed (terminal).
    case attestationFailed
    /// The stream overflowed and dropped observations.
    case streamOverflow(dropped: UInt32)
    /// An I/O error occurred.
    case io(String)

    /// `true` if terminal — the subscription must be torn down and not retried.
    ///
    /// Matches `Error::is_terminal` exactly: terminal for
    /// ``consentWithdrawn``, ``abiMismatch(sdk:kernel:)``,
    /// ``manifestRejected(_:)`` and ``attestationFailed``; every other case is
    /// retriable.
    public var isTerminal: Bool {
        switch self {
        case .consentWithdrawn, .abiMismatch, .manifestRejected, .attestationFailed:
            return true
        default:
            return false
        }
    }

    /// `true` if the condition may clear on retry. The complement of ``isTerminal``.
    public var isRetriable: Bool { !isTerminal }

    /// Stable machine-readable code. Mirrors `Error::code`.
    public var code: ErrorCode {
        switch self {
        case .transportUnreachable: return .transportUnreachable
        case .abiMismatch:          return .abiMismatch
        case .capabilityNotDeclared: return .capabilityNotDeclared
        case .manifestRejected:     return .manifestRejected
        case .rateLimitExceeded:    return .rateLimitExceeded
        case .consentSuspended:     return .consentSuspended
        case .consentWithdrawn:     return .consentWithdrawn
        case .protocolError:        return .protocolError
        case .attestationFailed:    return .attestationFailed
        case .streamOverflow:       return .streamOverflow
        case .io:                   return .io
        }
    }
}

extension AxonOSError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .transportUnreachable(let f): return "kernel transport unreachable: \(f)"
        case .abiMismatch(let sdk, let kernel): return "ABI mismatch: sdk=\(sdk) kernel=\(kernel)"
        case .capabilityNotDeclared(let c): return "capability \(c) not declared"
        case .manifestRejected(let r): return "manifest rejected: \(r)"
        case .rateLimitExceeded(let hz): return "rate limit exceeded: max \(hz) Hz"
        case .consentSuspended: return "consent suspended"
        case .consentWithdrawn: return "consent withdrawn"
        case .protocolError(let p): return "protocol error: \(p)"
        case .attestationFailed: return "attestation verification failed"
        case .streamOverflow(let dropped): return "stream overflow: \(dropped) dropped"
        case .io(let m): return "I/O error: \(m)"
        }
    }
}
