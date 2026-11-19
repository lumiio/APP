import Foundation
import SwiftUI

struct LanguageScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var language: LanguageManager
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let p = Palette(theme, scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: G.blockGap) {

                DCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, item in
                            Button {
                                Haptics.tap()
                                language.setLanguage(item)
                            } label: {
                                HStack(spacing: 10) {
                                    Text(item.displayName)
                                        .font(T.medium(14))
                                        .foregroundStyle(item == language.currentLanguage ? p.accent : p.text)
                                    Spacer(minLength: 8)
                                    if item == language.currentLanguage {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(p.accent)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if index < AppLanguage.allCases.count - 1 {
                                DHairline().padding(.leading, 14)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, G.gutter)
            .padding(.top, G.headerTop)
            .padding(.bottom, 30)
        }
        .appCanvas(p)
        .navigationTitle(L("language", "Language"))
        .navigationBarTitleDisplayMode(.large)
    }
}
