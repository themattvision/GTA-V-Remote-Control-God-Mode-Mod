import SwiftUI

struct BridgeGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            content
                .padding(16)
                .glassEffect()
        } else {
            content
                .padding(16)
                .background(.thinMaterial, in: .rect(cornerRadius: 18))
        }
    }
}
