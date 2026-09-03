import SwiftUI

@main
struct GTARemoteApp: App {
    @State private var model = RemoteAppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
