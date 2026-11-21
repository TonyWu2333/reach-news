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

                    field(titleKey: "channelEdit.prompt", hintKey: "channelEdit.prompt.hint") {
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

                    field(titleKey: "channelEdit.connectors", hintKey: "channel.create.connectors.hint") {
                        connectorPicker
                    }

                    field(
                        titleKey: "channelEdit.schedule",
                        hintKey: "channelEdit.schedule.hint",
                        hintArguments: [DisplayTime.timeZoneIdentifier]
                    ) {
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

    /// 连接器多选。空连接器会被拦在提交前，避免建出来跑不起来的频道。
    private var connectorPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.connectors.isEmpty {
                Text(L10n.string("channel.create.connectors.empty", locale: locale))
                    .font(TypeFace.body(12.5))
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.vertical, Space.s)
            } else {
                ForEach(store.connectors) { connector in
                    let isOn = selectedConnectorIDs.contains(connector.id)
                    Button {
                        if isOn {
                            selectedConnectorIDs.remove(connector.id)
                        } else {
                            selectedConnectorIDs.insert(connector.id)
                        }
                    } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15))
                                .foregroundStyle(isOn ? Palette.ink : Palette.inkTertiary)
                            Text(connector.name)
                                .font(TypeFace.body(13))
                                .foregroundStyle(Palette.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Space.s)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("channel-create-connector-\(connector.id)")
                }
            }

            if selectedConnectorIDs.isEmpty && !store.connectors.isEmpty {
                Text(L10n.string("channel.create.connectors.required", locale: locale))
                    .font(TypeFace.body(11))
                    .foregroundStyle(Palette.failedForeground)
                    .padding(.top, Space.xs)
            }
        }
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
        hintKey: String? = nil,
        hintArguments: [String] = [],
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(L10n.string(titleKey, locale: locale))
                .font(TypeFace.label(11))
                .tracking(1)
                .foregroundStyle(Palette.inkTertiary)
            content()
            if let hintKey {
                Text(hintArguments.isEmpty
                     ? L10n.string(hintKey, locale: locale)
                     : String(format: L10n.string(hintKey, locale: locale), locale: locale, arguments: hintArguments))
                    .font(TypeFace.body(11))
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
