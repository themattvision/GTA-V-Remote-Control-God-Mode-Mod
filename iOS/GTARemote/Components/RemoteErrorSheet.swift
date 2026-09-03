import SwiftUI

struct RemoteErrorSheet: View {
    let error: RemoteAppError
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(TrainerTheme.warning)
                Text(error.title)
                    .font(.title2.bold())
                    .foregroundStyle(TrainerTheme.primaryText)
            }

            ErrorExplanationRow(label: "Cosa", text: error.what)
            ErrorExplanationRow(label: "Perché", text: error.why)
            ErrorExplanationRow(label: "Adesso", text: error.how)

            if error.canRetry {
                Button("Riprova", action: retry)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .buttonStyle(TrainerPressStyle(role: .primary, radius: TrainerTheme.Radius.control))
                    .frame(maxWidth: .infinity)
            }

            Button("Chiudi", action: close)
                .controlSize(.large)
                .foregroundStyle(TrainerTheme.secondaryText)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(TrainerTheme.background.opacity(0.35))
        .presentationBackground(.thinMaterial)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(32)
    }
}

private struct ErrorExplanationRow: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(TrainerTheme.tertiaryText)
            Text(text)
                .font(.body)
                .foregroundStyle(TrainerTheme.primaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
