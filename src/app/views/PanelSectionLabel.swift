import SwiftUI

/// Quiet header above a settings list: a title on the left, a metric on the right.
struct PanelSectionLabel: View {
    let title: String
    var metric: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let metric {
                Text(metric)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Explanatory line in the pane footer. Always tertiary: it teaches the
/// interaction without competing with the rows above it.
struct PanelFooterHint: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.tertiary)
    }
}
