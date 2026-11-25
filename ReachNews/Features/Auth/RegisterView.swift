import SwiftUI

// MARK: - 注册页
//
// 邀请码注册（POST /api/v1/register）。字段顺序按服务端要求：
// 昵称、邮箱、密码、确认密码、邀请码。
//
// 两个要点：
// 1. 注册成功直接进入 App：响应已带 token，不需要再调一次登录。
// 2. 失败提示优先用服务端返回的中文 message（实测服务端已本地化），
//    本地文案只作为 message 缺失时的兜底，避免两份文案漂移。

struct RegisterView: View {
    @Bindable var session: SessionStore
    @Environment(\.appLocale) private var locale
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var inviteCode = ""
    @State private var error: RegistrationError?
    @FocusState private var focused: Field?

    private enum Field {
        case nickname, email, password, passwordConfirm, inviteCode
    }

    private var canSubmit: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !passwordConfirm.isEmpty
            && !inviteCode.trimmingCharacters(in: .whitespaces).isEmpty
            && !session.isRegistering
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let error {
                    InlineNotice(text: message(for: error), kind: .error)
                        .accessibilityIdentifier("register-error")
                }

                field(labelKey: "register.nickname") {
                    TextField("", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .nickname)
                        .accessibilityIdentifier("register-nickname")
                }

                field(labelKey: "register.email", hintKey: "register.email.hint") {
                    TextField("", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .focused($focused, equals: .email)
                        .accessibilityIdentifier("register-email")
                }

                field(labelKey: "register.password") {
                    SecureField("", text: $password)
                        .focused($focused, equals: .password)
                        .accessibilityIdentifier("register-password")
                }

                field(labelKey: "register.passwordConfirm") {
                    SecureField("", text: $passwordConfirm)
                        .focused($focused, equals: .passwordConfirm)
                        .accessibilityIdentifier("register-password-confirm")
                }

                field(labelKey: "register.inviteCode") {
                    TextField("", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .inviteCode)
                        .accessibilityIdentifier("register-invite")
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 44)
        }
        .background(Palette.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavTitle(text: L10n.string("register.title", locale: locale))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    submit()
                } label: {
                    if session.isRegistering {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L10n.string("register.submit", locale: locale))
                            .font(TypeFace.heading(15))
                            .foregroundStyle(canSubmit ? Palette.ink : Palette.inkTertiary)
                    }
                }
                .disabled(!canSubmit)
                .accessibilityIdentifier("register-submit")
            }
        }
        .accessibilityIdentifier("register-view")
    }

    /// 服务端 message 优先；没有时用 code 对应的本地兜底。
    private func message(for error: RegistrationError) -> String {
        let serverMessage = error.message.trimmingCharacters(in: .whitespacesAndNewlines)
        if !serverMessage.isEmpty { return serverMessage }
        let key = error.fallbackKey
        let fallback = L10n.string(key, locale: locale)
        // L10n 找不到键时会把键原样返回，此时退回通用文案。
        return fallback == key ? L10n.string("register.error.unknown", locale: locale) : fallback
    }

    private func submit() {
        guard canSubmit else { return }
        focused = nil
        error = nil
        Task {
            let failure = await session.register(
                nickname: nickname,
                email: email,
                password: password,
                passwordConfirm: passwordConfirm,
                inviteCode: inviteCode
            )
            if let failure {
                error = failure
            } else {
                // 注册成功：会话已建立，直接回退让根视图切换到主界面。
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(
        labelKey: String,
        hintKey: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(L10n.string(labelKey, locale: locale))
                .font(TypeFace.label(11))
                .tracking(1)
                .foregroundStyle(Palette.inkTertiary)
            content()
                .font(TypeFace.body(14))
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Palette.line, lineWidth: 1)
                }
            if let hintKey {
                Text(L10n.string(hintKey, locale: locale))
                    .font(TypeFace.footnote)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}
