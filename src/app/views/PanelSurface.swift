import SwiftUI

/// Elevated surface for a settings card.
///
/// An inset `List` paints the same colour as the pane behind it, so a card is
/// drawn explicitly: a translucent lift plus a hairline. Working from the
/// colour scheme instead of two hard-coded palettes keeps it correct in both
/// appearances and under Increase Contrast.
struct PanelSurface: ViewModifier {
    var cornerRadius: CGFloat = 11
    /// Optional fill override; the default adapts to the colour scheme.
    var fill: AnyShapeStyle?

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(fill ?? schemeFill))
            .overlay(shape.strokeBorder(.separator, lineWidth: 1))
    }

    private var schemeFill: AnyShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color.white.opacity(0.055))
            : AnyShapeStyle(Color.black.opacity(0.035))
    }
}

extension View {
    func panelSurface(cornerRadius: CGFloat = 11, fill: AnyShapeStyle? = nil) -> some View {
        modifier(PanelSurface(cornerRadius: cornerRadius, fill: fill))
    }
}
