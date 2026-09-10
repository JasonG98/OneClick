import AppKit
import SwiftUI

/// Rounded well holding a target icon.
///
/// Real application icons keep their own artwork and are drawn bare, the way
/// Finder shows them. Targets without artwork fall back to a hairline well, so
/// a target whose bundle could not be resolved reads as "no icon yet" instead
/// of a broken app.
struct IconTile: View {
    let image: NSImage?
    let fallbackSymbol: String
    var isDimmed = false

    /// One size everywhere; the row metrics were tuned against it.
    private static let tileSize: CGFloat = 34

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .panelSurface(cornerRadius: 8, fill: AnyShapeStyle(.quaternary))
            }
        }
        .frame(width: Self.tileSize, height: Self.tileSize)
        .saturation(isDimmed ? 0 : 1)
        .opacity(isDimmed ? 0.5 : 1)
        .accessibilityHidden(true)
    }
}
