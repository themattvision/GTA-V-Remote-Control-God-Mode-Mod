import Foundation
import GTAControlCore
import Testing
@testable import GTARemote

@MainActor
struct RemoteAppModelTests {
    @Test(arguments: [
        (CGSize(width: 0, height: -48), TrainerCommand.moveUp),
        (CGSize(width: 0, height: 48), TrainerCommand.moveDown),
        (CGSize(width: -48, height: 0), TrainerCommand.moveLeft),
        (CGSize(width: 48, height: 0), TrainerCommand.moveRight),
        (CGSize(width: 54, height: -24), TrainerCommand.moveRight),
        (CGSize(width: -18, height: 56), TrainerCommand.moveDown),
    ])
    func swipeResolverUsesDominantDirection(translation: CGSize, command: TrainerCommand) {
        #expect(DirectionPadSwipeResolver.command(for: translation) == command)
    }

    @Test
    func swipeResolverIgnoresShortAndAmbiguousGestures() {
        #expect(DirectionPadSwipeResolver.command(for: CGSize(width: 16, height: 0)) == nil)
        #expect(DirectionPadSwipeResolver.command(for: CGSize(width: 34, height: 34)) == nil)
    }

    @Test
    func disconnectedStateNeverEnablesControls() async {
        let client = TestRemoteClient(initialEvent: .disconnected(reason: "Non trovato"))
        let feedback = TestFeedback()
        let model = RemoteAppModel(client: client, feedback: feedback)

        model.start()
        defer { model.stop() }
        await waitUntil { model.connectionState == .disconnected(reason: "Non trovato") }

        #expect(model.controlsAreEnabled == false)
        await model.send(.select)
        #expect(client.sentCommands.isEmpty)
        #expect(feedback.acknowledgementCount == 0)
    }

    @Test
    func confirmedConnectionEnablesControls() async {
        let client = TestRemoteClient(initialEvent: .connected(deviceName: "Mac Test"))
        let model = RemoteAppModel(client: client, feedback: TestFeedback())

        model.start()
        defer { model.stop() }
        await waitUntil { model.connectionState == .connected(deviceName: "Mac Test") }

        #expect(model.connectionState == .connected(deviceName: "Mac Test"))
        #expect(model.controlsAreEnabled)
    }

    @Test
    func hapticIsProducedOnlyAfterAcknowledgement() async {
        let client = TestRemoteClient(initialEvent: .connected(deviceName: "Mac Test"))
        let feedback = TestFeedback()
        let model = RemoteAppModel(client: client, feedback: feedback)

        model.start()
        defer { model.stop() }
        await waitUntil { model.connectionState == .connected(deviceName: "Mac Test") }
        await model.send(.toggleTrainer)

        #expect(client.sentCommands == [.toggleTrainer])
        #expect(feedback.acknowledgementCount == 1)
        #expect(model.presentedError == nil)
    }

    @Test
    func rejectedCommandShowsItalianErrorWithoutHaptic() async {
        let client = TestRemoteClient(initialEvent: .connected(deviceName: "Mac Test"))
        client.sendError = .commandRejected(reason: "GTA V non è in primo piano.")
        let feedback = TestFeedback()
        let model = RemoteAppModel(client: client, feedback: feedback)

        model.start()
        defer { model.stop() }
        await waitUntil { model.connectionState == .connected(deviceName: "Mac Test") }
        await model.send(.vehicleRockets)

        #expect(feedback.acknowledgementCount == 0)
        #expect(model.presentedError?.title == "Comando non eseguito")
        #expect(model.presentedError?.why == "GTA V non è in primo piano.")
    }

    @Test
    func pairingMustBeConfirmedBeforeConnectedState() async {
        let prompt = PairingPrompt(deviceName: "Mac Test", fingerprint: "123456")
        let client = TestRemoteClient(initialEvent: .pairingRequired(prompt))
        let model = RemoteAppModel(client: client, feedback: TestFeedback())

        model.start()
        defer { model.stop() }
        await waitUntil { model.pairingPrompt == prompt }
        #expect(model.pairingPrompt == prompt)
        #expect(model.controlsAreEnabled == false)

        model.confirmPairing()
        await waitUntil { model.connectionState == .connected(deviceName: "Mac Test") }
        #expect(client.confirmedPrompt == prompt)
        #expect(model.controlsAreEnabled)
    }

    @Test
    func wreckPreservationAcknowledgesOnlyAfterGTAStateChanges() async {
        let client = TestRemoteClient(initialEvent: .connected(deviceName: "Mac Test"))
        let feedback = TestFeedback()
        let model = RemoteAppModel(client: client, feedback: feedback)

        model.start()
        defer { model.stop() }
        await waitUntil { model.connectionState == .connected(deviceName: "Mac Test") }
        client.publish(.trainerState(TrainerStateSnapshot(
            isDirectControlReady: true,
            godModeEnabled: false,
            wreckPreservationEnabled: false,
            preservedWreckCount: 0
        )))
        await waitUntil { model.canControlWreckPreservation }

        model.setWreckPreservation(true)
        await waitUntil { client.wreckPreservationRequests == [true] }
        #expect(feedback.acknowledgementCount == 0)

        client.publish(.trainerState(TrainerStateSnapshot(
            isDirectControlReady: true,
            godModeEnabled: false,
            wreckPreservationEnabled: true,
            preservedWreckCount: 0
        )))
        await waitUntil { model.pendingWreckPreservationValue == nil }

        #expect(feedback.acknowledgementCount == 1)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await ContinuousClock().sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class TestRemoteClient: RemoteSessionClient {
    private let continuation: AsyncStream<RemoteClientEvent>.Continuation
    let events: AsyncStream<RemoteClientEvent>
    private let initialEvent: RemoteClientEvent

    var sentCommands: [TrainerCommand] = []
    var wreckPreservationRequests: [Bool] = []
    var sendError: RemoteClientError?
    var confirmedPrompt: PairingPrompt?
    private var sequence: UInt64 = 0

    init(initialEvent: RemoteClientEvent) {
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
        confirmedPrompt = prompt
        continuation.yield(.connected(deviceName: prompt.deviceName))
    }

    func rejectPairing(_ prompt: PairingPrompt) {
        continuation.yield(.searching)
    }

    func send(_ command: TrainerCommand) async throws -> CommandAcknowledgement {
        sentCommands.append(command)
        if let sendError { throw sendError }
        sequence += 1
        return CommandAcknowledgement(requestID: UUID(), sequence: sequence)
    }

    func setGodMode(_ enabled: Bool) async throws -> CommandAcknowledgement {
        if let sendError { throw sendError }
        sequence += 1
        return CommandAcknowledgement(requestID: UUID(), sequence: sequence)
    }

    func setWreckPreservation(_ enabled: Bool) async throws -> CommandAcknowledgement {
        if let sendError { throw sendError }
        wreckPreservationRequests.append(enabled)
        sequence += 1
        return CommandAcknowledgement(requestID: UUID(), sequence: sequence)
    }

    func publish(_ event: RemoteClientEvent) {
        continuation.yield(event)
    }
}

@MainActor
private final class TestFeedback: SuccessFeedbackProviding {
    private(set) var acknowledgementCount = 0

    func commandWasAcknowledged() {
        acknowledgementCount += 1
    }
}
