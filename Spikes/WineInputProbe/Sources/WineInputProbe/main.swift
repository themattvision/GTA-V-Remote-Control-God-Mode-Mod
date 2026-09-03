import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum ProbeError: Error, CustomStringConvertible {
    case accessibilityDenied
    case invalidArguments
    case unknownCommand(String)
    case eventCreationFailed(String)

    var description: String {
        switch self {
        case .accessibilityDenied:
            "Accessibilita non concessa al processo che esegue il probe."
        case .invalidArguments:
            "Uso: WineInputProbe [--delay secondi] [--gap millisecondi] <f4|escape|up|down|left|right|select|back|num0|boost-up|boost-down|rockets|wanted-up|wanted-down> [...]"
        case let .unknownCommand(command):
            "Comando sconosciuto: \(command)"
        case let .eventCreationFailed(command):
            "Impossibile creare gli eventi per: \(command)"
        }
    }
}

enum ProbeAction: String, CaseIterable {
    case f4
    case escape
    case up
    case down
    case left
    case right
    case select
    case back
    case num0
    case boostUp = "boost-up"
    case boostDown = "boost-down"
    case rockets
    case wantedUp = "wanted-up"
    case wantedDown = "wanted-down"

    var keyCodes: [CGKeyCode] {
        switch self {
        case .f4: [CGKeyCode(kVK_F4)]
        case .escape: [CGKeyCode(kVK_Escape)]
        case .up: [CGKeyCode(kVK_ANSI_Keypad8)]
        case .down: [CGKeyCode(kVK_ANSI_Keypad2)]
        case .left: [CGKeyCode(kVK_ANSI_Keypad4)]
        case .right: [CGKeyCode(kVK_ANSI_Keypad6)]
        case .select: [CGKeyCode(kVK_ANSI_Keypad5)]
        case .back: [CGKeyCode(kVK_Delete)]
        case .num0: [CGKeyCode(kVK_ANSI_Keypad0)]
        case .boostUp: [CGKeyCode(kVK_ANSI_Keypad9)]
        case .boostDown: [CGKeyCode(kVK_ANSI_Keypad3)]
        case .rockets: [CGKeyCode(kVK_ANSI_KeypadPlus)]
        case .wantedUp:
            // FUGITIVE, fixed local diagnostic macro. No arbitrary text input.
            [CGKeyCode(kVK_ANSI_F), CGKeyCode(kVK_ANSI_U), CGKeyCode(kVK_ANSI_G),
             CGKeyCode(kVK_ANSI_I), CGKeyCode(kVK_ANSI_T), CGKeyCode(kVK_ANSI_I),
             CGKeyCode(kVK_ANSI_V), CGKeyCode(kVK_ANSI_E)]
        case .wantedDown:
            // LAWYERUP, fixed local diagnostic macro. No arbitrary text input.
            [CGKeyCode(kVK_ANSI_L), CGKeyCode(kVK_ANSI_A), CGKeyCode(kVK_ANSI_W),
             CGKeyCode(kVK_ANSI_Y), CGKeyCode(kVK_ANSI_E), CGKeyCode(kVK_ANSI_R),
             CGKeyCode(kVK_ANSI_U), CGKeyCode(kVK_ANSI_P)]
        }
    }
}

struct Arguments {
    let delay: TimeInterval
    let gap: TimeInterval
    let commands: [ProbeAction]

    init(_ rawArguments: [String]) throws {
        var delay: TimeInterval = 5
        var gap: TimeInterval = 0.25
        var commands: [ProbeAction] = []
        var index = 0

        while index < rawArguments.count {
            let argument = rawArguments[index]
            switch argument {
            case "--delay":
                index += 1
                guard index < rawArguments.count,
                      let value = TimeInterval(rawArguments[index]),
                      (0...60).contains(value) else {
                    throw ProbeError.invalidArguments
                }
                delay = value
            case "--gap":
                index += 1
                guard index < rawArguments.count,
                      let milliseconds = TimeInterval(rawArguments[index]),
                      (40...5_000).contains(milliseconds) else {
                    throw ProbeError.invalidArguments
                }
                gap = milliseconds / 1_000
            default:
                guard let command = ProbeAction(rawValue: argument) else {
                    throw ProbeError.unknownCommand(argument)
                }
                commands.append(command)
            }
            index += 1
        }

        guard !commands.isEmpty else {
            throw ProbeError.invalidArguments
        }

        self.delay = delay
        self.gap = gap
        self.commands = commands
    }
}

func post(_ command: ProbeAction) throws {
    for keyCode in command.keyCodes {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw ProbeError.eventCreationFailed(command.rawValue)
        }

        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.06)
        keyUp.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.08)
    }
}

do {
    let arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
    guard AXIsProcessTrusted() else {
        throw ProbeError.accessibilityDenied
    }

    if arguments.delay > 0 {
        print("Porta GTA in primo piano. Invio tra \(arguments.delay.formatted()) secondi...")
        Thread.sleep(forTimeInterval: arguments.delay)
    }

    for (index, command) in arguments.commands.enumerated() {
        try post(command)
        print("Inviato \(command.rawValue): down + up")
        if index < arguments.commands.count - 1 {
            Thread.sleep(forTimeInterval: arguments.gap)
        }
    }
} catch {
    FileHandle.standardError.write(Data("ERRORE: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
