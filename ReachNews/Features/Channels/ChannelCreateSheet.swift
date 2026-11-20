import SwiftUI

// MARK: - 新建频道
//
// 后端提供 GET /api/v1/presets 与 POST /api/v1/presets/:id/instantiate。
// 预设在服务端只作模板、不参与调度，实例化后得到自己的 kind='channel' 频道。

struct ChannelCreateSheet: View {
    @Bindable var store: ChannelStore
    @Binding var isPresented: Bool
    var onCreated: (Channel) -> Void

    @Environment(\.appLocale) private var locale

    var body: some View {
        NavigationStack {
            Group {
                if let error = store.createError, store.presets.isEmpty {
                    MessageStateView(
                        title: L10n.string(error.messageKey, locale: locale),
                        message: error.isOffline ? L10n.string("error.offline.detail", locale: locale) : error.detailText,
                        kind: .error(error),
                        actionTitle: L10n.string("common.retry", locale: locale),
                        action: { Task { await store.loadCreationOptions() } }
                    )
                } else if store.presets.isEmpty {
                    MessageStateView(
                        title: L10n.string("channel.create.empty.title", locale: locale),
                        message: L10n.string("channel.create.empty.message", locale: locale),
                        kind: .empty
                    )
                } else {
                    list
                }
            }
            .background(Palette.canvas)
            .navigationTitle(L10n.string("channel.create.title", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Text(L10n.string("common.cancel", locale: locale))
                            .font(TypeFace.body(14))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }
        .task {
            await store.loadCreationOptions()
        }
        .accessibilityIdentifier("channel-create-sheet")
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text(L10n.string("channel.create.hint", locale: locale))
                    .font(TypeFace.body(12))
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.xxs)

                ForEach(store.presets) { preset in
                    presetCard(preset)
                }

                if let error = store.createError, !store.presets.isEmpty {
                    InlineNotice(
                        text: L10n.string(error.messageKey, locale: locale),
                        detail: error.detailText,
                        kind: .error
                    )
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .accessibilityIdentifier("channel-create-list")
    }

    private func presetCard(_ preset: ChannelPreset) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(preset.name)
                .font(TypeFace.heading(15))
                .foregroundStyle(Palette.ink)

            if !preset.prompt.isEmpty {
                Text(preset.prompt)
                    .font(TypeFace.body(12.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            HStack(spacing: Space.s) {
                if let schedule = ScheduleDisplay.summary(preset.schedule, locale: locale) {
                    Text(schedule)
                        .font(TypeFace.condensed(11, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer(minLength: 0)

                Button {
                    Task {
                        if let created = await store.instantiate(presetID: preset.id) {
                            onCreated(created)
                            isPresented = false
                        }
                    }
                } label: {
                    if store.isCreating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L10n.string("channel.create.action", locale: locale))
                            .font(TypeFace.heading(12.5))
                            .foregroundStyle(Palette.canvas)
                            .padding(.horizontal, Space.m)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Palette.ink))
                    }
                }
                .buttonStyle(.plain)
                .disabled(store.isCreating)
                .accessibilityIdentifier("channel-create-\(preset.id)")
            }
            .padding(.top, 11)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 1)
        }
    }
}
