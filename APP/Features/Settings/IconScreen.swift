import Foundation
import SwiftUI

struct IconScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var busy = false
    @State private var errorText: String?
    @State private var current = AppIconManager.shared.currentAlternateIconName

    private let options: [(key: String, title: String, asset: String)] = [
        ("app", "Default", "AppLogo"),
        ("kana_love", "Kana Love", "kana_love"),
        ("kana_peek", "Kana Peek", "kana_peek")
    ]

    var body: some View {
        let p = Palette(theme, scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: G.blockGap) {
                if !AppChrome.usesSystemBars {
                    DTitle(
                        text: L("icon", "App Icon"),
                        subtitle: L("icon_subtitle", "Pick the icon shown on your home screen"),
                        onBack: { dismiss() }
                    )
                }

                let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(options, id: \.key) { option in
                        optionCard(option, p)
                    }
                }

                if let errorText {
                    DNote(text: errorText, isError: true)
                }

                Text(L("icon_trollstore_hint", "On TrollStore installs the icon is swapped on disk; elsewhere iOS shows its own confirmation dialog."))
                    .font(T.body(11))
                    .foregroundStyle(p.subtext)
                    .lineSpacing(3)
            }
            .padding(.horizontal, G.gutter)
            .padding(.top, G.headerTop)
            .padding(.bottom, 30)
        }
        .appCanvas(p)
        .adaptiveNavChrome()
        .navigationTitle(L("icon", "App Icon"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionCard(_ option: (key: String, title: String, asset: String), _ p: Palette) -> some View {
        let selected = option.key == "app" ? (current == nil) : (current == option.key)
        return Button {
            apply(option.key)
        } label: {
            VStack(spacing: 10) {
                Image(option.asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(option.title)
                    .font(T.caption(12))
                    .foregroundStyle(selected ? p.accent : p.text)
                Text(selected ? L("icon_current", "Current") : " ")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(p.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: G.cardRadius, style: .continuous).fill(p.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: G.cardRadius, style: .continuous)
                    .strokeBorder(selected ? p.accent.opacity(0.5) : p.line, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(PressableStyle())
        .disabled(busy)
    }

    private func apply(_ key: String) {
        guard !busy else { return }
        let targetName = key == "app" ? nil : key
        guard targetName != current else { return }
        busy = true
        errorText = nil
        Haptics.tap()

        AppIconManager.shared.setAlternateIconName(targetName) { success, error in
            DispatchQueue.main.async {
                busy = false
                if success {
                    current = AppIconManager.shared.currentAlternateIconName
                    Haptics.success()
                } else {
                    errorText = error?.localizedDescription ?? L("icon_set_failed_desc", "The system refused to change the icon.")
                    Haptics.warning()
                }
            }
        }
    }
}
