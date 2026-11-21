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
    @Environment(AppEnvironment.self) private var env

    @State private var name = ""
    @State private var prompt = ""
    @State private var tone = ""
    @State private var schedule = Schedule()
    @State private var selectedConnectorIDs: Set<String> = []
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
                        FieldBox {
                            TextField("", text: $name)
                                .accessibilityIdentifier("channel-create-name")
                        }
                    }

                    field(titleKey: "channelEdit.prompt") {
                        FieldBox(minHeight: 132) {
                            TextEditor(text: $prompt)
                                .scrollContentBackground(.hidden)
                                .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
                                .accessibilityIdentifier("channel-create-prompt")
                        }
                    }

                    field(titleKey: "channelEdit.tone") {
                        FieldBox(minHeight: 52) {
                            TextField("", text: $tone, axis: .vertical)
                                .lineLimit(2...4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("channel-create-tone")
                        }
                    }

                    field(titleKey: "channelEdit.connectors") {
                        connectorSummary
                    }

                    field(titleKey: "channelEdit.schedule") {
                        ScheduleEditor(schedule: $schedule)
                    }

                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.l)
                .padding(.bottom, Space.xxl)
            }
            .background(Palette.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavTitle(text: L10n.string("channel.create.title", locale: locale))
                }
            }
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
            // 新频道默认占一个还没用过的颜色，避免与已有频道撞色。
            if env.channelColors.colorIndex(for: created.id) == nil {
                env.channelColors.setColorIndex(env.channelColors.suggestedIndex(), for: created.id)
            }
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
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).fill(Palette.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 1)
            }
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
