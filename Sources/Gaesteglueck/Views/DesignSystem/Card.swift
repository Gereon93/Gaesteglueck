#if canImport(SwiftUI)
import SwiftUI

/// Generischer Card-Container mit weißem Hintergrund, dezentem Border und
/// weicher Schatten-Schicht. Padding kann per `padding` überschrieben werden;
/// `padding: 0` für Cards mit eigener internen Sektionierung (z.B. mit
/// horizontaler Trennlinie zwischen Header und Body).
struct GGCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Tokens.Colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(Tokens.Colors.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .cardShadow()
    }
}

/// Inspector-Sektion mit Caption-Label oben + optionaler Action rechts.
/// Trennlinien zwischen Sektionen werden automatisch über die Sektion selbst gezeichnet.
struct InspectorSection<Content: View, Action: View>: View {
    let title: String
    @ViewBuilder var action: () -> Action
    @ViewBuilder var content: () -> Content

    init(_ title: String,
         @ViewBuilder action: @escaping () -> Action,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.action = action
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.6)
                Spacer()
                action()
            }
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Tokens.Colors.line)
                .frame(height: 1)
        }
    }
}

extension InspectorSection where Action == EmptyView {
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title, action: { EmptyView() }, content: content)
    }
}
#endif
