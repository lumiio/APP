import SwiftUI
import UIKit

@main
struct AppMain: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var language = LanguageManager.shared
    @State private var ready = false

    init() {
        CrashLogger.install()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootShell()
                    .environmentObject(theme)
                    .environmentObject(language)
                    .environmentObject(AppStore.this)
                    .environmentObject(UnifiedDownloadManager.shared)
                    .environmentObject(DecryptStore.shared)
                    .environmentObject(SearchModel.shared)
                    .environmentObject(PurchasedModel.shared)
                    .tint(theme.accentColor)
                    .environment(\.layoutDirection, language.layoutDirection)
                    .id(language.currentLanguage.rawValue)
                    .preferredColorScheme(preferredScheme)
                    .opacity(ready ? 1 : 0)

                if !ready {
                    LaunchVeil()
                        .environmentObject(theme)
                        .transition(.opacity)
                }
            }
            .task { await boot() }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch theme.selectedTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    @MainActor
    private func boot() async {
        theme.updateUserInterfaceStyle()
        AppPrewarmer.warm()
        try? await Task.sleep(nanoseconds: 260_000_000)
        withAnimation(.easeOut(duration: 0.35)) { ready = true }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    var backgroundSessionCompletionHandler: (() -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppCache.configure()
        Task { @MainActor in
            AnalyticsManager.shared.addProvider(ConsoleAnalyticsProvider())
        }
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        backgroundSessionCompletionHandler = completionHandler
        _ = AppStoreDownloadManager.shared
    }
}

private struct LaunchVeil: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette(theme, scheme)
        ZStack {
            p.canvas.ignoresSafeArea()
            VStack(spacing: 14) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                ProgressView()
                    .tint(p.accent)
            }
        }
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
