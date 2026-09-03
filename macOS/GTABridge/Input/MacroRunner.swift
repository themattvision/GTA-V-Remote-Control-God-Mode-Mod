import Foundation
import GTAControlCore

enum TrainerMacro: String, CaseIterable, Identifiable, Sendable {
    case openTrainer
    case closeCurrentMenu

    var id: Self { self }

    var title: String {
        switch self {
        case .openTrainer:
            "Apri trainer"
        case .closeCurrentMenu:
            "Indietro"
        }
    }

    var commands: [TrainerCommand] {
        switch self {
        case .openTrainer:
            [.toggleTrainer]
        case .closeCurrentMenu:
            [.back]
        }
    }
}

@MainActor
final class MacroRunner<Injector: TrainerInputInjecting> {
    private let injector: Injector
    private let commandGap: Duration

    init(injector: Injector, commandGap: Duration = .milliseconds(180)) {
        self.injector = injector
        self.commandGap = commandGap
    }

    func run(_ macro: TrainerMacro) async throws {
        for (index, command) in macro.commands.enumerated() {
            try Task.checkCancellation()
            try await injector.inject(command)

            if index < macro.commands.count - 1 {
                try await ContinuousClock().sleep(for: commandGap)
            }
        }
    }
}

