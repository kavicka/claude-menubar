import SwiftUI

/// Small chat-bubble mark shown at the left of the menu bar status text.
/// Original shape (not Anthropic's logo) — this repo is public, so we avoid
/// shipping a trademarked mark. Deliberately unstyled: no explicit color, so
/// it inherits the standard menu bar monochrome rendering and adapts to
/// light/dark automatically, same as system icons.
struct ClaudeGlyph: View {
    var body: some View {
        GlyphShape()
            .frame(width: 13, height: 13)
    }
}

private struct GlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h * 0.78),
                     cornerRadius: w * 0.32)
        p.move(to: CGPoint(x: w * 0.22, y: h * 0.72))
        p.addLine(to: CGPoint(x: w * 0.13, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.72))
        p.closeSubpath()
        return p
    }
}
