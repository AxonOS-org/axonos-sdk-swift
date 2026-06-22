// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

#if canImport(Combine)
import Combine
import Foundation

extension IntentStream {
    /// Bridge this asynchronous stream to a Combine publisher.
    ///
    /// A backing `Task` pulls observations from the stream and forwards them to
    /// subscribers; cancelling the subscription cancels the task. The publisher
    /// completes with `.finished` when the stream ends, or `.failure` if it
    /// throws — for example ``AxonOSError/consentWithdrawn`` (terminal).
    ///
    /// This makes the stream a first-class citizen in SwiftUI and Combine
    /// pipelines (`.sink`, `.receive(on:)`, `.assign(to:)`, …).
    public func publisher() -> AnyPublisher<IntentObservation, Error> {
        let subject = PassthroughSubject<IntentObservation, Error>()
        let stream = self
        let task = Task {
            do {
                for try await observation in stream {
                    subject.send(observation)
                }
                subject.send(completion: .finished)
            } catch is CancellationError {
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(error))
            }
        }
        return subject
            .handleEvents(receiveCancel: { task.cancel() })
            .eraseToAnyPublisher()
    }
}
#endif
