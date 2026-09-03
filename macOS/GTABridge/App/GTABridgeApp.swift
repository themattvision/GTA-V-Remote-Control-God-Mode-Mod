import SwiftUI

@main
struct GTABridgeApp: App {
    @State private var model: BridgeModel

    init() {
        let model = BridgeModel()
        _model = State(initialValue: model)
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            BridgeMenuView(model: model)
        } label: {
            Label("GodMode Mod Remote Control", systemImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        switch model.connectionState {
        case .connected:
            "iphone.and.arrow.forward"
        case .awaitingPairing, .authenticating:
            "person.badge.key"
        case .disconnected:
            "gamecontroller"
        }
    }
}
