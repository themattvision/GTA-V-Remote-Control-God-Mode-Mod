import Carbon.HIToolbox
import GTAControlCore
import Testing
@testable import GTABridge

@MainActor
struct TrainerInputInjectorTests {
    @Test
    func blocksInputWhenGTAIsNotFrontmost() async {
        let guardUnderTest = StubGameGuard(result: .failure(.unexpectedBundle(nil)))
        let poster = RecordingKeyboardEventPoster()
        let injector = TrainerInputInjector(
            foregroundGuard: guardUnderTest,
            poster: poster,
            permission: StubAccessibilityPermission(granted: true),
            holdDuration: .zero
        )

        await #expect(throws: ForegroundGameGuardError.self) {
            try await injector.inject(.toggleTrainer)
        }
        #expect(poster.events.isEmpty)
    }

    @Test
    func postsDownThenUpForAcceptedCommand() async throws {
        let poster = RecordingKeyboardEventPoster()
        let injector = TrainerInputInjector(
            foregroundGuard: StubGameGuard(result: .success(())),
            poster: poster,
            permission: StubAccessibilityPermission(granted: true),
            holdDuration: .zero
        )

        try await injector.inject(.select)

        #expect(
            poster.events == [
                .init(keyCode: CGKeyCode(kVK_ANSI_Keypad5), keyDown: true),
                .init(keyCode: CGKeyCode(kVK_ANSI_Keypad5), keyDown: false),
            ]
        )
    }

    @Test
    func blocksInputWithoutAccessibility() async {
        let poster = RecordingKeyboardEventPoster()
        let injector = TrainerInputInjector(
            foregroundGuard: StubGameGuard(result: .success(())),
            poster: poster,
            permission: StubAccessibilityPermission(granted: false),
            holdDuration: .zero
        )

        await #expect(throws: TrainerInputError.accessibilityDenied) {
            try await injector.inject(.toggleTrainer)
        }
        #expect(poster.events.isEmpty)
    }

    @Test
    func cancellationStillReleasesPressedKey() async {
        let poster = RecordingKeyboardEventPoster()
        let injector = TrainerInputInjector(
            foregroundGuard: StubGameGuard(result: .success(())),
            poster: poster,
            permission: StubAccessibilityPermission(granted: true),
            holdDuration: .seconds(5)
        )
        let task = Task {
            try await injector.inject(.moveDown)
        }

        try? await ContinuousClock().sleep(for: .milliseconds(20))
        task.cancel()
        _ = try? await task.value

        #expect(
            poster.events == [
                .init(keyCode: CGKeyCode(kVK_ANSI_Keypad2), keyDown: true),
                .init(keyCode: CGKeyCode(kVK_ANSI_Keypad2), keyDown: false),
            ]
        )
    }
}

@MainActor
private struct StubGameGuard: ForegroundGameChecking {
    let result: Result<Void, ForegroundGameGuardError>

    func validateForegroundGame() throws {
        try result.get()
    }
}

@MainActor
private struct StubAccessibilityPermission: AccessibilityPermissionChecking {
    let granted: Bool

    func isAccessibilityGranted() -> Bool {
        granted
    }
}

@MainActor
private final class RecordingKeyboardEventPoster: KeyboardEventPosting {
    struct Event: Equatable {
        let keyCode: CGKeyCode
        let keyDown: Bool
    }

    private(set) var events: [Event] = []

    func post(keyCode: CGKeyCode, keyDown: Bool) throws {
        events.append(Event(keyCode: keyCode, keyDown: keyDown))
    }
}
