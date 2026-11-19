import Foundation
import SwiftUI

// MARK: - Interaction

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension View {
    func plainTap(_ action: @escaping () -> Void) -> some View {
        Button(action: action) { self }.buttonStyle(PressableStyle())
    }
}

// MARK: - Surfaces

struct DCard<Content: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = G.cardPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let p = Palette(theme, scheme)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: G.cardRadius, style: .continuous)
                    .fill(p.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: G.cardRadius, style: .continuous)
                    .strokeBorder(p.line, lineWidth: 1)
            )
    }
}

/// Inner block used inside a card to separate rows without extra borders.
struct DHairline: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Palette(theme, scheme).line.frame(height: 1)
    }
}

// MARK: - Buttons

enum DButtonKind { case primary, secondary, quiet, danger }

struct DButton: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let title: String
    var icon: String? = nil
    var kind: DButtonKind = .primary
    var compact: Bool = false
    var loading: Bool = false
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        let p = Palette(theme, scheme)
        Button(action: action) {
            HStack(spacing: compact ? 5 : 7) {
                if loading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.mini)
                        .tint(kind == .primary ? Color.white : p.text)
                } else if let symbol = icon {
                    Image(systemName: symbol)
                        .font(.system(size: compact ? 11 : 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(foreground(p))
            .padding(.horizontal, compact ? 11 : 16)
            .frame(height: compact ? 30 : 44)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(background(p))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : G.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 10 : G.controlRadius, style: .continuous)
                    .strokeBorder(stroke(p), lineWidth: kind == .secondary ? 1 : 0)
            )
        }
        .buttonStyle(PressableStyle())
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled || loading)
    }

    private func foreground(_ p: Palette) -> Color {
        switch kind {
        case .primary: return .white
        case .danger: return p.danger
        case .quiet: return p.accent
        case .secondary: return p.text
        }
    }

    private func background(_ p: Palette) -> Color {
        switch kind {
        case .primary: return p.accent
        case .danger: return p.danger.opacity(0.12)
        case .quiet: return .clear
        case .secondary: return p.fill
        }
    }

    private func stroke(_ p: Palette) -> Color {
        kind == .secondary ? p.line : .clear
    }
}

/// Round icon-only button used in headers.
struct DIconButton: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let symbol: String
    var tint: Color? = nil
    var size: CGFloat = 38
    var action: () -> Void

    var body: some View {
        let p = Palette(theme, scheme)
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint ?? p.text)
                .frame(width: size, height: size)
                .background {
                    if !theme.liquidGlassEnabled {
                        Circle()
                            .fill(p.card)
                            .overlay(Circle().strokeBorder(p.line, lineWidth: 1))
                    }
                }
                .glassCircle(enabled: theme.liquidGlassEnabled)
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Imagery

struct DTile: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let symbol: String
    var tint: Color? = nil
    var size: CGFloat = 34

    var body: some View {
        let p = Palette(theme, scheme)
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(tint ?? p.accent)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill((tint ?? p.accent).opacity(p.isDark ? 0.14 : 0.10))
            )
    }
}

struct DArtwork: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let url: String?
    var size: CGFloat = 56
    var radius: CGFloat = 14

    var body: some View {
        let p = Palette(theme, scheme)
        Group {
            if let raw = url, let link = URL(string: raw) {
                AsyncImage(url: link, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback(p)
                    }
                }
            } else {
                fallback(p)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(p.line, lineWidth: 1)
        )
    }

    private func fallback(_ p: Palette) -> some View {
        ZStack {
            p.fill
            Image(systemName: "app.dashed")
                .font(.system(size: size * 0.32, weight: .regular))
                .foregroundStyle(p.muted)
        }
    }
}

// MARK: - Progress

struct DBar: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let value: Double
    var height: CGFloat = 4
    var tint: Color? = nil

    var body: some View {
        let p = Palette(theme, scheme)
        let progress = min(max(value, 0), 1)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(p.fill)
                Capsule()
                    .fill(tint ?? p.accent)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: height)
    }
}

/// Animated stand-in for indeterminate work (searching, loading purchased list).
struct DSweepBar: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme
    @State private var phase: CGFloat = -0.4

    var body: some View {
        let p = Palette(theme, scheme)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(p.fill)
                Capsule()
                    .fill(p.accent.opacity(0.7))
                    .frame(width: geo.size.width * 0.32)
                    .offset(x: geo.size.width * phase)
            }
            .clipped()
        }
        .frame(height: 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1.1
            }
        }
    }
}

// MARK: - Labels

struct DChip: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let text: String
    var tint: Color? = nil
    var solid: Bool = false

    var body: some View {
        let p = Palette(theme, scheme)
        let color = tint ?? p.subtext
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(solid ? Color.white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(solid ? color : color.opacity(p.isDark ? 0.16 : 0.12))
            )
    }
}

struct DSection<Content: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    private let title: String?
    private let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let p = Palette(theme, scheme)
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(p.subtext)
                    .padding(.leading, 4)
            }
            content
        }
    }
}

struct DEmpty: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let symbol: String
    let title: String
    var message: String? = nil

    var body: some View {
        let p = Palette(theme, scheme)
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(p.muted)
            Text(title)
                .font(T.headline(15))
                .foregroundStyle(p.text)
            if let message {
                Text(message)
                    .font(T.body(13))
                    .foregroundStyle(p.subtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
    }
}

// MARK: - Title bars

struct DTitle: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let text: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil

    var body: some View {
        let p = Palette(theme, scheme)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(p.text)
                            .frame(width: 30, height: 30)
                            .background {
                                if !theme.liquidGlassEnabled {
                                    Circle()
                                        .fill(p.card)
                                        .overlay(Circle().strokeBorder(p.line, lineWidth: 1))
                                }
                            }
                            .glassCircle(enabled: theme.liquidGlassEnabled)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.trailing, 2)
                }
                Text(text)
                    .font(onBack == nil ? T.display() : T.headline(20))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            if let subtitle {
                Text(subtitle)
                    .font(T.body(13))
                    .foregroundStyle(p.subtext)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Inputs

struct DSearchField: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    @Binding var text: String
    let placeholder: String
    var onSubmit: () -> Void

    var body: some View {
        let p = Palette(theme, scheme)
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(p.muted)
            TextField(placeholder, text: $text)
                .font(T.body(15))
                .foregroundStyle(p.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(p.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: G.fieldRadius, style: .continuous).fill(p.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: G.fieldRadius, style: .continuous)
                .strokeBorder(p.line, lineWidth: 1)
        )
    }
}

struct DField: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var secure: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        let p = Palette(theme, scheme)
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(T.caption(11))
                .foregroundStyle(p.muted)
                .padding(.leading, 2)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(T.body(15))
            .foregroundStyle(p.text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(keyboard)
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: G.fieldRadius, style: .continuous).fill(p.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: G.fieldRadius, style: .continuous)
                    .strokeBorder(p.line, lineWidth: 1)
            )
        }
    }
}

// MARK: - Inline notes

struct DNote: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let text: String
    var isError: Bool = false

    var body: some View {
        let p = Palette(theme, scheme)
        HStack(spacing: 7) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 11))
            Text(text)
                .font(T.body(12))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(isError ? p.danger : p.subtext)
    }
}

struct DSwitch: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    @Binding var isOn: Bool

    var body: some View {
        let p = Palette(theme, scheme)
        Button {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.18)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? p.accent : p.fill)
                    .frame(width: 46, height: 28)
                    .overlay(Capsule().strokeBorder(p.line, lineWidth: isOn ? 0 : 1))
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .padding(.horizontal, 3)
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
