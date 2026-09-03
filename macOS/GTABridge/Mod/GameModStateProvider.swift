import Foundation
import GTAControlCore

enum GameModStateProviderError: Error, LocalizedError {
    case directControlUnavailable

    var errorDescription: String? {
        switch self {
        case .directControlUnavailable:
            "La modalita diretta non e ancora pronta in GTA. Attendi l'avvio della modalita Storia."
        }
    }
}

/// Scambio locale tra GTA (Wine) e il bridge. Il modulo .asi scrive lo stato del motore
/// ogni 250 ms, mentre il Mac pubblica soltanto un'azione già limitata dal protocollo.
struct GameModStateProvider {
    private struct StateFile: Equatable {
        let godModeEnabled: Bool
        let wreckPreservationEnabled: Bool?
        let preservedWreckCount: Int?

        init?(contents: String) {
            let values = Self.values(in: contents)
            guard values["version"] == "1",
                  let rawValue = values["godMode"],
                  let enabled = Self.bool(from: rawValue) else {
                return nil
            }
            godModeEnabled = enabled
            wreckPreservationEnabled = values["wreckPreservation"].flatMap(Self.bool(from:))
            preservedWreckCount = values["preservedWreckCount"].flatMap(Int.init)
        }

        private static func values(in contents: String) -> [String: String] {
            Dictionary(uniqueKeysWithValues: contents
                .split(whereSeparator: \.isNewline)
                .compactMap { line in
                    let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { return nil }
                    return (parts[0], parts[1])
                }
            )
        }

        private static func bool(from rawValue: String) -> Bool? {
            switch rawValue {
            case "1", "true": true
            case "0", "false": false
            default: nil
            }
        }
    }

    private let gameDirectory: URL
    private let now: @Sendable () -> Date

    init(
        gameDirectory: URL = URL(
            fileURLWithPath: "/Volumes/SSD GAMES/Grand Theft Auto V.app/Contents/SharedSupport/prefix/drive_c/KS Games/Grand Theft Auto V",
            isDirectory: true
        ),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.gameDirectory = gameDirectory
        self.now = now
    }

    func currentState() -> TrainerStateSnapshot {
        let stateURL = gameDirectory.appendingPathComponent("GTARemoteBridge.state")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: stateURL.path),
              let modifiedAt = attributes[.modificationDate] as? Date,
              now().timeIntervalSince(modifiedAt) < 2,
              let contents = try? String(contentsOf: stateURL, encoding: .utf8),
              let state = StateFile(contents: contents) else {
            return .unavailable
        }

        return TrainerStateSnapshot(
            isDirectControlReady: true,
            godModeEnabled: state.godModeEnabled,
            wreckPreservationEnabled: state.wreckPreservationEnabled,
            preservedWreckCount: state.preservedWreckCount
        )
    }

    func setGodMode(_ enabled: Bool) throws {
        try writeRequest(action: "setGodMode", enabled: enabled)
    }

    func setWreckPreservation(_ enabled: Bool) throws {
        try writeRequest(action: "setWreckPreservation", enabled: enabled)
    }

    private func writeRequest(action: String, enabled: Bool) throws {
        guard currentState().isDirectControlReady else {
            throw GameModStateProviderError.directControlUnavailable
        }

        let request = [
            "version=1",
            "requestID=\(UUID().uuidString)",
            "action=\(action)",
            "enabled=\(enabled ? "1" : "0")",
            "",
        ].joined(separator: "\n")
        let commandURL = gameDirectory.appendingPathComponent("GTARemoteBridge.command")
        try request.write(to: commandURL, atomically: true, encoding: .utf8)
    }
}
