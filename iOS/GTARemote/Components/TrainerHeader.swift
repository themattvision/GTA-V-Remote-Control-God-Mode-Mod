import SwiftUI

struct TrainerHeader: View {
    var body: some View {
        HStack(spacing: TrainerTheme.Spacing.compact) {
            Image(systemName: "gamecontroller.fill")
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(TrainerTheme.accent)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Plancia GTA")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(TrainerTheme.primaryText)
                Text("Controlli rapidi dal telefono")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TrainerTheme.secondaryText)
            }

            Spacer()

            Label("Wi-Fi", systemImage: "wifi")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TrainerTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, TrainerTheme.Spacing.roomy)
        .padding(.top, TrainerTheme.Spacing.regular)
        .padding(.bottom, TrainerTheme.Spacing.compact)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
