import Foundation
import UIKit
import SwiftUI

struct AboutScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let p = Palette(theme, scheme)
        VStack(alignment: .leading, spacing: G.sectionGap) {
            if !AppChrome.usesSystemBars {
                DTitle(
                    text: "about".localized,
                    subtitle: L("about_subtitle", "App Store client for downloading your own purchases"),
                    onBack: { dismiss() }
                )
            }

            DCard {
                VStack(spacing: 0) {
                    infoRow(L("version", "Version"), shortVersion, p)
                    DHairline().padding(.vertical, 10)
                    infoRow("Build", buildVersion, p)
                    DHairline().padding(.vertical, 10)
                    infoRow(L("bundle", "Bundle ID"), Bundle.main.bundleIdentifier ?? "-", p)
                    DHairline().padding(.vertical, 10)
                    infoRow("iOS", UIDevice.current.systemVersion, p)
                }
            }

            DCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("about_scope_title", "What it does"))
                        .font(T.medium(14))
                        .foregroundStyle(p.text)
                    Text(L("about_scope_body", "Signs in to the Apple ID you add, lists the apps that account already bought, downloads the packages from Apple's servers and can strip FairPlay encryption from those packages on device."))
                        .font(T.body(12))
                        .foregroundStyle(p.subtext)
                        .lineSpacing(3)
                    Text(L("about_scope_note", "Nothing is uploaded. Packages and decrypted copies stay in the app container."))
                        .font(T.body(11))
                        .foregroundStyle(p.muted)
                        .lineSpacing(3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, G.gutter)
        .padding(.top, G.headerTop)
        .padding(.bottom, 24)
        .appCanvas(p)
        .adaptiveNavChrome()
        .navigationTitle("about".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(_ label: String, _ value: String, _ p: Palette) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(T.body(13))
                .foregroundStyle(p.subtext)
            Spacer(minLength: 16)
            Text(value)
                .font(T.medium(12))
                .foregroundStyle(p.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }
}
