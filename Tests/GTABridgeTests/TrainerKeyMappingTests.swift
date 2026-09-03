import Carbon.HIToolbox
import GTAControlCore
import Testing
@testable import GTABridge

struct TrainerKeyMappingTests {
    @Test(
        arguments: [
            (TrainerCommand.toggleTrainer, CGKeyCode(kVK_F4)),
            (.moveUp, CGKeyCode(kVK_ANSI_Keypad8)),
            (.moveDown, CGKeyCode(kVK_ANSI_Keypad2)),
            (.moveLeft, CGKeyCode(kVK_ANSI_Keypad4)),
            (.moveRight, CGKeyCode(kVK_ANSI_Keypad6)),
            (.select, CGKeyCode(kVK_ANSI_Keypad5)),
            (.back, CGKeyCode(kVK_Delete)),
            (.numpadBack, CGKeyCode(kVK_ANSI_Keypad0)),
            (.vehicleBoostUp, CGKeyCode(kVK_ANSI_Keypad9)),
            (.vehicleBoostDown, CGKeyCode(kVK_ANSI_Keypad3)),
            (.vehicleRockets, CGKeyCode(kVK_ANSI_KeypadPlus)),
        ]
    )
    func mapsVerifiedWineInput(_ command: TrainerCommand, _ expectedKeyCode: CGKeyCode) {
        #expect(TrainerKeyMapping.keyCode(for: command) == expectedKeyCode)
    }
}
