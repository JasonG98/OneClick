import SwiftUI

/// Compact pill that states why a target cannot be used yet.
///
/// Warning tone is reserved for conditions the user can fix, so a target that is
/// not installed is visible at a glance instead of fading into the supporting
/// text.
struct StatusChip: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(.quaternary))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
