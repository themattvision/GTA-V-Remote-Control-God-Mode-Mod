import SwiftUI

struct PairingSheet: View {
    let prompt: PairingPrompt
    let isWaitingForMacApproval: Bool
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(TrainerTheme.accent)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Conferma il Mac")
                    .font(.title2.bold())
                    .foregroundStyle(TrainerTheme.primaryText)
                Text("Verifica che su \(prompt.deviceName) compaia lo stesso codice.")
                    .font(.body)
                    .foregroundStyle(TrainerTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

            Text(formattedFingerprint)
                .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                .tracking(4)
                .foregroundStyle(TrainerTheme.primaryText)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.075))
                }
                .accessibilityLabel("Codice \(prompt.fingerprint.map(String.init).joined(separator: " "))")

            Text("Non confermare se i codici sono diversi.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(TrainerTheme.warning)

            Button(action: confirm) {
                HStack(spacing: 8) {
                    if isWaitingForMacApproval {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isWaitingForMacApproval ? "Conferma anche sul Mac" : "I codici coincidono")
                }
                .frame(maxWidth: .infinity, minHeight: 56)
            }
                .buttonStyle(TrainerPressStyle(role: .primary, radius: TrainerTheme.Radius.control))
                .frame(maxWidth: .infinity)
                .accessibilityHint("Conferma l’associazione sicura con questo Mac")
                .disabled(isWaitingForMacApproval)

            Button("Annulla", role: .cancel, action: cancel)
                .controlSize(.large)
                .foregroundStyle(TrainerTheme.secondaryText)
        }
        .padding(24)
        .background(TrainerTheme.background.opacity(0.35))
        .presentationBackground(.thinMaterial)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(32)
        .interactiveDismissDisabled()
    }

    private var formattedFingerprint: String {
        let digits = prompt.fingerprint.filter(\.isNumber).prefix(6)
        let midpoint = digits.index(digits.startIndex, offsetBy: min(3, digits.count))
        return "\(digits[..<midpoint]) \(digits[midpoint...])"
    }
}
