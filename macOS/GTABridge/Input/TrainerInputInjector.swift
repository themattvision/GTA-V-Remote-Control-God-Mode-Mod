import ApplicationServices
import Carbon.HIToolbox
import Foundation
import GTAControlCore

enum TrainerInputError: Error, Equatable, LocalizedError {
    case accessibilityDenied
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            "Allow Accessibility for GTA Remote Control before sending commands."
        case .eventCreationFailed:
            "macOS non ha creato l'evento tastiera richiesto."
        }
    }
}

enum TrainerKeyMapping {
    static func keyCode(for command: TrainerCommand) -> CGKeyCode {
        switch command {
        case .toggleTrainer:
            CGKeyCode(kVK_F4)
        case .moveUp:
            CGKeyCode(kVK_ANSI_Keypad8)
        case .moveDown:
            CGKeyCode(kVK_ANSI_Keypad2)
        case .moveLeft:
            CGKeyCode(kVK_ANSI_Keypad4)
        case .moveRight:
            CGKeyCode(kVK_ANSI_Keypad6)
        case .select:
            CGKeyCode(kVK_ANSI_Keypad5)
        case .back:
            CGKeyCode(kVK_Delete)
        case .numpadBack:
            CGKeyCode(kVK_ANSI_Keypad0)
        case .vehicleBoostUp:
            CGKeyCode(kVK_ANSI_Keypad9)
        case .vehicleBoostDown:
            CGKeyCode(kVK_ANSI_Keypad3)
        case .vehicleRockets:
            CGKeyCode(kVK_ANSI_KeypadPlus)
        }
    }
}

@MainActor
protocol KeyboardEventPosting {
    func post(keyCode: CGKeyCode, keyDown: Bool) throws
}

@MainActor
struct CGKeyboardEventPoster: KeyboardEventPosting {
    func post(keyCode: CGKeyCode, keyDown: Bool) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let event = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: keyCode,
                  keyDown: keyDown
              ) else {
            throw TrainerInputError.eventCreationFailed
        }

        event.post(tap: .cghidEventTap)
    }
}

@MainActor
protocol TrainerInputInjecting {
    func inject(_ command: TrainerCommand) async throws
}

@MainActor
protocol AccessibilityPermissionChecking {
    func isAccessibilityGranted() -> Bool
}

@MainActor
struct SystemAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    private let trustedCheckOptionPromptKey = "AXTrustedCheckOptionPrompt"

    func isAccessibilityGranted() -> Bool {
        let options: CFDictionary = [trustedCheckOptionPromptKey: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

@MainActor
final class TrainerInputInjector<
    Guard: ForegroundGameChecking,
    Poster: KeyboardEventPosting,
    Permission: AccessibilityPermissionChecking
>: TrainerInputInjecting {
    private let foregroundGuard: Guard
    private let poster: Poster
    private let permission: Permission
    private let holdDuration: Duration

    init(
        foregroundGuard: Guard,
        poster: Poster,
        permission: Permission,
        holdDuration: Duration = .milliseconds(60)
    ) {
        self.foregroundGuard = foregroundGuard
        self.poster = poster
        self.permission = permission
        self.holdDuration = holdDuration
    }

    func inject(_ command: TrainerCommand) async throws {
        guard permission.isAccessibilityGranted() else {
            throw TrainerInputError.accessibilityDenied
        }

        try foregroundGuard.validateForegroundGame()
        let keyCode = TrainerKeyMapping.keyCode(for: command)
        try poster.post(keyCode: keyCode, keyDown: true)

        do {
            try await ContinuousClock().sleep(for: holdDuration)
        } catch {
            try? poster.post(keyCode: keyCode, keyDown: false)
            throw error
        }

        try poster.post(keyCode: keyCode, keyDown: false)
    }
}
