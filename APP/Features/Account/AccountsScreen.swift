import Foundation
import SwiftUI

struct AccountsScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var showAdd = false
    @State private var pendingDelete: Account?

    var body: some View {
        let p = Palette(theme, scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: G.blockGap) {
                if store.savedAccounts.isEmpty {
                    DEmpty(
                        symbol: "person.crop.circle",
                        title: "no_account".localized,
                        message: L("accounts_empty_hint", "Add an Apple ID to get started.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("group_accounts", "Apple ID"))
                            .font(T.caption(12))
                            .foregroundStyle(p.muted)
                            .padding(.leading, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(store.savedAccounts.enumerated()), id: \.element.id) { index, account in
                                accountRow(account, p)
                                if index < store.savedAccounts.count - 1 {
                                    Rectangle().fill(p.line).frame(height: 0.5).padding(.leading, 58)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                }

                DButton(title: "add_account".localized, icon: "plus") {
                    showAdd = true
                }

                if store.savedAccounts.count == 1 {
                    DNote(text: L("switch_account_hint", "再加一个 Apple ID 就能在这里切换。"))
                } else if store.savedAccounts.count > 1 {
                    DNote(text: L("switch_account_hint2", "点任意账号即可切换为当前账号，下载和购买都使用它。"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .appCanvas(p)
        .navigationTitle(L("account_management", "Accounts"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAdd) {
            AddAccountScreen()
        }
        .alert(
            L("delete_account", "Remove this account?"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("cancel".localized, role: .cancel) { pendingDelete = nil }
            Button("delete".localized, role: .destructive) {
                if let account = pendingDelete {
                    store.deleteAccount(account)
                }
                pendingDelete = nil
            }
        }
    }

    private func accountRow(_ account: Account, _ p: Palette) -> some View {
        let selected = store.selectedAccount?.email == account.email
        return Button {
            guard !selected else { return }
            Haptics.tap()
            store.switchToAccount(account)
            store.persistSelectedIndex()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(selected ? p.accentSoft(0.16) : p.fill)
                    Text(String(account.email.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? p.accent : p.subtext)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(account.email)
                        .font(T.medium(14))
                        .foregroundStyle(p.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 6) {
                        if !account.countryCode.isEmpty {
                            Text(account.countryCode.uppercased())
                                .font(T.caption(11))
                                .foregroundStyle(p.subtext)
                        }
                        if selected {
                            Text(L("selected", "当前"))
                                .font(T.caption(11))
                                .foregroundStyle(p.accent)
                        }
                    }
                }
                Spacer(minLength: 8)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(p.accent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(p.muted)
                }

                Button {
                    Haptics.tap()
                    pendingDelete = account
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(p.muted)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AddAccountScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: G.blockGap) {
                    DTitle(
                        text: "add_account".localized,
                        subtitle: L("add_account_subtitle", "Used to reach the App Store purchase endpoint"),
                        onBack: nil
                    )

                    DField(label: L("email", "Apple ID"), text: $email, placeholder: "name@example.com", keyboard: .emailAddress)
                    DField(label: L("password", "Password"), text: $password, placeholder: "••••••••", secure: true)
                    DField(label: L("two_factor_code", "2FA code (if asked)"), text: $code, placeholder: "123456", keyboard: .numberPad)

                    if let errorText {
                        DNote(text: errorText, isError: true)
                    } else {
                        DNote(text: L("add_account_note", "The password is kept in the Keychain so downloads can renew the session later."))
                    }

                    DButton(title: L("sign_in", "Sign in"), icon: "person.badge.key", loading: busy, enabled: canSubmit) {
                        signIn()
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("cancel".localized)
                            .font(T.caption(13))
                            .foregroundStyle(p.subtext)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, G.gutter)
                .padding(.top, G.headerTop)
                .padding(.bottom, 30)
            }
            .appCanvas(p)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    DIconButton(symbol: "xmark") { dismiss() }
                }
                .padding(.horizontal, G.gutter)
                .padding(.vertical, 8)
                .background(p.canvas)
            }
        }
    }

    private var canSubmit: Bool {
        !busy
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    private func signIn() {
        guard canSubmit else { return }
        busy = true
        errorText = nil
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = password
        let twoFactor = code.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                try await store.loginAccount(
                    email: mail,
                    password: secret,
                    code: twoFactor.isEmpty ? nil : twoFactor
                )
                await MainActor.run {
                    busy = false
                    Haptics.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    busy = false
                    errorText = error.localizedDescription
                    Haptics.warning()
                }
            }
        }
    }
}
