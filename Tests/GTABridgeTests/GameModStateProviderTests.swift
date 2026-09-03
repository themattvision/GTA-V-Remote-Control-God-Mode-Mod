import Foundation
import GTAControlCore
import Testing
@testable import GTABridge

@Suite("Game mod state provider")
struct GameModStateProviderTests {
    @Test("Reads fresh GTA state and writes only explicit direct requests")
    func readsStateAndWritesCommand() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let stateURL = directory.appendingPathComponent("GTARemoteBridge.state")
        try "version=1\ngodMode=1\nwreckPreservation=1\npreservedWreckCount=3\n".write(
            to: stateURL,
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: stateURL.path)

        let provider = GameModStateProvider(gameDirectory: directory, now: { now })

        #expect(provider.currentState() == TrainerStateSnapshot(
            isDirectControlReady: true,
            godModeEnabled: true,
            wreckPreservationEnabled: true,
            preservedWreckCount: 3
        ))

        try provider.setGodMode(false)

        let command = try String(
            contentsOf: directory.appendingPathComponent("GTARemoteBridge.command"),
            encoding: .utf8
        )
        #expect(command.contains("version=1"))
        #expect(command.contains("action=setGodMode"))
        #expect(command.contains("enabled=0"))
        #expect(!command.contains("nativeHash"))

        try provider.setWreckPreservation(true)

        let wreckCommand = try String(
            contentsOf: directory.appendingPathComponent("GTARemoteBridge.command"),
            encoding: .utf8
        )
        #expect(wreckCommand.contains("action=setWreckPreservation"))
        #expect(wreckCommand.contains("enabled=1"))
    }

    @Test("Refuses a direct command without a fresh GTA state")
    func refusesUnavailableState() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = GameModStateProvider(gameDirectory: directory)

        #expect(throws: GameModStateProviderError.self) {
            try provider.setGodMode(true)
        }
    }
}
