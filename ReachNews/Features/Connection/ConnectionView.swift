import SwiftUI

// MARK: - 连接页
//
// 首次启动无 token 时进入；更换凭证时复用同一页。
// Base URL 预填 reachapi.niuma.art 且可编辑。

struct ConnectionView: View {
    @Bindable var session: SessionStore
    var isReplacingCredential: Bool = false

    @Environment(\.appLocale) private var locale
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field {
        case baseURL
        case token
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header

                if case .failed(let error) = session.state {
                    InlineNotice(
                        text: L10n.string(error.messageKey, locale: locale),
                        detail: error.isOffline
                            ? L10n.string("error.offline.detail", locale: locale)
                            : error.detailText,
                        kind: .error
                    )
                    .accessibilityIdentifier("connection-error")
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(L10n.string("connection.baseURL.heading", locale: locale))
                        .font(TypeFace.label(11))
                        .tracking(1)
                        .foregroundStyle(Palette.inkTertiary)
                    TextField(
                        L10n.string("connection.baseURL.placeholder", locale: locale),
                        text: $session.baseURLString
                    )
                    .font(TypeFace.body(14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($focusedField, equals: .baseURL)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Palette.line, lineWidth: 1)
                    }
                    .accessibilityIdentifier("connection-baseurl")
                    .onSubmit { focusedField = .token }
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(L10n.string("connection.token.heading", locale: locale))
                        .font(TypeFace.label(11))
                        .tracking(1)
                        .foregroundStyle(Palette.inkTertiary)
                    SecureField(
                        L10n.string("connection.token.placeholder", locale: locale),
                        text: $session.tokenInput
                    )
                    .font(TypeFace.body(14))
                    .focused($focusedField, equals: .token)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Palette.line, lineWidth: 1)
                    }
                    .accessibilityIdentifier("connection-token")
                    Text(L10n.string("connection.token.hint", locale: locale))
                        .font(TypeFace.body(11))
                        .foregroundStyle(Palette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PrimaryButton(
                    title: session.isConnecting
                        ? L10n.string("connection.connecting", locale: locale)
                        : L10n.string("connection.submit", locale: locale)
                ) {
                    focusedField = nil
                    Task {
                        let ok = await session.connect()
                        if ok && isReplacingCredential {
                            dismiss()
                        }
                    }
                }
                .disabled(session.isConnecting)
                .accessibilityIdentifier("connection-submit")

                Text(L10n.string("connection.verificationNote", locale: locale))
                    .font(TypeFace.body(11))
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.xxl)
            .padding(.bottom, 44)
        }
        .background(Palette.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isReplacingCredential {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text(L10n.string("common.cancel", locale: locale))
                            .font(TypeFace.body(14))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("connection-view")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                BrandMark(assetName: "LogoMarkInk", size: 30)
                Text("Reach News")
                    .font(TypeFace.heading(19))
                    .foregroundStyle(Palette.ink)
            }
            Text(L10n.string("connection.title", locale: locale))
                .font(TypeFace.display(28))
                .foregroundStyle(Palette.ink)
            Text(L10n.string("connection.subtitle", locale: locale))
                .font(TypeFace.body(13.5))
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
