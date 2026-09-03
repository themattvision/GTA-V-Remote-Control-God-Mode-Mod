import SwiftUI

struct RootView: View {
    @Bindable var model: RemoteAppModel

    var body: some View {
        VStack(spacing: 0) {
            TrainerHeader()

            RemoteControlView(model: model)
        }
        .background {
            TrainerBackdrop()
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .task { model.start() }
        .onDisappear { model.stop() }
        .sheet(item: pairingBinding) { prompt in
            PairingSheet(
                prompt: prompt,
                isWaitingForMacApproval: model.isWaitingForMacPairingApproval,
                confirm: model.confirmPairing,
                cancel: model.rejectPairing
            )
        }
        .sheet(item: $model.presentedError) { error in
            RemoteErrorSheet(
                error: error,
                retry: model.retry,
                close: { model.presentedError = nil }
            )
        }
    }

    private var pairingBinding: Binding<PairingPrompt?> {
        Binding(
            get: { model.pairingPrompt },
            set: { newValue in
                if newValue == nil, model.pairingPrompt != nil {
                    model.rejectPairing()
                }
            }
        )
    }
}
