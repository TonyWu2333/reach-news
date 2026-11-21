import SwiftUI

// MARK: - 新建频道
//
// 后端已提供 POST /api/v1/channels，不再需要预设才能建。
// 连接器必选：空连接器的频道启用后每次运行都会 missed。
// 预设仍可作为「填入模板」的快捷方式。

struct ChannelCreateSheet: View {
    @Bindable var store: ChannelStore
    @Binding var isPresented: Bool
    var onCreated: (Channel) -> Void

    @Environment(\.appLocale) private var locale

    @State private var name = ""
    @State private var prompt = ""
    @State private var tone = ""
    @State private var schedule = Schedule()
    @State private var selectedConnectorIDs: Set<String> = []
    @State private var showsPresets = false
    @State private var showsConnectorPicker = false

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !prompt.trimmingCharacters(in: .whitespaces).isEmpty
            && !selectedConnectorIDs.isEmpty
            && !store.isCreating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = store.createError {
                        InlineNotice(
                            text: L10n.string(error.messageKey, locale: locale),
                            detail: error.detailText,
                            kind: .error
                        )
                    }

                    field(titleKey: "channelEdit.name") {
                        TextField("", text: $name)
                            .font(TypeFace.body(14))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 11)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityIdentifier("channel-create-name")
                    }

                    field(titleKey: "channelEdit.prompt") {
                        TextEditor(text: $prompt)
                            .font(TypeFace.body(13.5))
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityIdentifier("channel-create-prompt")
                    }

                    field(titleKey: "channelEdit.tone") {
                        TextField("", text: $tone)
                            .font(TypeFace.body(14))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 11)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityIdentifier("channel-create-tone")
                    }

                    field(titleKey: "channelEdit.connectors") {
                        connectorSummary
                    }

                    field(titleKey: "channelEdit.schedule") {
                        ScheduleEditor(schedule: $schedule)
                    }

                    if !store.presets.isEmpty {
                        presetShortcuts
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.l)
                .padding(.bottom, Space.xxl)
            }
            .background(Palette.canvas)
            .navigationTitle(L10n.string("channel.create.title", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if store.isCreating {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(L10n.string("channel.create.submit", locale: locale))
                                .font(TypeFace.heading(14))
                                .foregroundStyle(canSubmit ? Palette.ink : Palette.inkTertiary)
                        }
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("channel-create-submit")
                }
            }
        }
        .sheet(isPresented: $showsConnectorPicker) {
            ConnectorPicker(
                connectors: store.connectors,
                selection: Binding(
                    get: { Array(selectedConnectorIDs) },
                    set: { selectedConnectorIDs = Set($0) }
                ),
                isPresented: $showsConnectorPicker
            )
        }
        .task {
            await store.loadCreationOptions()
        }
        .accessibilityIdentifier("channel-create-sheet")
    }

    private func submit() async {
        guard canSubmit else { return }
        if let created = await store.create(
            name: name.trimmingCharacters(in: .whitespaces),
            prompt: prompt.trimmingCharacters(in: .whitespaces),
            tone: tone,
            schedule: schedule,
            connectorIDs: Array(selectedConnectorIDs)
        ) {
            onCreated(created)
            isPresented = false
        }
    }

    /// 连接器：一行摘要，点开弹出多选。
    private var connectorSummary: some View {
        Button {
            showsConnectorPicker = true
        } label: {
            HStack(spacing: Space.s) {
                Text(summaryText)
                    .font(TypeFace.body(14))
                    .foregroundStyle(selectedConnectorIDs.isEmpty ? Palette.inkTertiary : Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.field))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("channel-create-connectors")
    }

    private var summaryText: String {
        let names = store.connectors
            .filter { selectedConnectorIDs.contains($0.id) }
            .map(\.name)
        if names.isEmpty { return L10n.string("channelEdit.connectors.none", locale: locale) }
        if names.count <= 2 { return names.joined(separator: "、") }
        return L10n.format("channelEdit.connectors.someSelected", locale: locale, names.count)
    }

    /// 预设作为「填入模板」的快捷方式，不再是唯一入口。
    private var presetShortcuts: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Button {
                showsPresets.toggle()
            } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: showsPresets ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text(L10n.string("channel.create.fromPreset", locale: locale))
                        .font(TypeFace.heading(12.5))
                }
                .foregroundStyle(Palette.inkSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("channel-create-presets-toggle")

            if showsPresets {
                ForEach(store.presets) { preset in
                    Button {
                        name = preset.name
                        prompt = preset.prompt
                        tone = preset.tone
                        schedule = preset.schedule
                        selectedConnectorIDs = Set(preset.connectorIDs.filter { id in
                            store.connectors.contains { $0.id == id }
                        })
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(TypeFace.label(13))
                                .foregroundStyle(Palette.ink)
                            if !preset.prompt.isEmpty {
                                Text(preset.prompt)
                                    .font(TypeFace.body(11.5))
                                    .foregroundStyle(Palette.inkTertiary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Space.m)
                        .padding(.vertical, Space.s)
                        .background(Palette.chip, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("channel-create-preset-\(preset.id)")
                }
            }
        }
    }

    private func field<Content: View>(
        titleKey: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(L10n.string(titleKey, locale: locale))
                .font(TypeFace.label(11))
                .tracking(1)
                .foregroundStyle(Palette.inkTertiary)
            content()
        }
    }
}
