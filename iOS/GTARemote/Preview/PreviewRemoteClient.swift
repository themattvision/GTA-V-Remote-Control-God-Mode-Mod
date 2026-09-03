import Foundation
import GTAControlCore
import SwiftUI

@MainActor
final class PreviewRemoteClient: RemoteSessionClient {
    private let continuation: AsyncStream<RemoteClientEvent>.Continuation
    let events: AsyncStream<RemoteClientEvent>
    private let initialEvent: RemoteClientEvent

    init(initialEvent: RemoteClientEvent = .connected(deviceName: "Mac di Matteo")) {
        self.initialEvent = initialEvent
        let stream = AsyncStream.makeStream(of: RemoteClientEvent.self)
        events = stream.stream
        continuation = stream.continuation
    }

    func start() {
        continuation.yield(initialEvent)
    }

    func stop() {}

    func confirmPairing(_ prompt: PairingPrompt) {
        continuation.yield(.connected(deviceName: prompt.deviceName))
    }

    func rejectPairing(_ prompt: PairingPrompt) {
        continuation.yield(.searching)
    }

    func send(_ command: TrainerCommand) async throws -> CommandAcknowledgement {
        CommandAcknowledgement(requestID: UUID(), sequence: 1)
    }

    func setGodMode(_ enabled: Bool) async throws -> CommandAcknowledgement {
        CommandAcknowledgement(requestID: UUID(), sequence: 1)
    }

    func setWreckPreservation(_ enabled: Bool) async throws -> CommandAcknowledgement {
        CommandAcknowledgement(requestID: UUID(), sequence: 1)
    }
}

@MainActor
final class PreviewFeedback: SuccessFeedbackProviding {
    func commandWasAcknowledged() {}
}

#Preview("Collegato") {
    RootView(
        model: RemoteAppModel(
            client: PreviewRemoteClient(),
            feedback: PreviewFeedback()
        )
    )
}

#Preview("Disconnesso") {
    RootView(
        model: RemoteAppModel(
            client: PreviewRemoteClient(initialEvent: .disconnected(reason: "GTA Bridge non trovato")),
            feedback: PreviewFeedback()
        )
    )
}

#Preview("Pairing") {
    RootView(
        model: RemoteAppModel(
            client: PreviewRemoteClient(
                initialEvent: .pairingRequired(
                    PairingPrompt(deviceName: "Mac di Matteo", fingerprint: "482731")
                )
            ),
            feedback: PreviewFeedback()
        )
    )
}
