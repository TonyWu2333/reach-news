import SwiftUI

// MARK: - 频道编辑
//
// 整页一次保存：只提交被改动的字段。运行中 409 busy 时顶部提示且保留全部输入。

struct ChannelEditView: View {
    let channel: Channel
    @Bindable var editor: ChannelEditor
    var onSaved: (Channel) -> Void

    @Environment(\.appLocale) private var locale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if editor.isBlockedByRunning {
                    // 运行中保存：提示原因，已填内容全部保留。
                    InlineNotice(
                        text: L10n.string("channelEdit.busy.title", locale: locale),
                        detail: L10n.string("channelEdit.busy.detail", locale: locale)
                    )
                    .accessibilityIdentifier("channel-edit-busy-notice")
                } else if let error = editor.saveError {
                    InlineNotice(
                        text: L10n.string(error.messageKey, locale: locale),
                        detail: error.detailText,
                        kind: .error
                    )
                }

                field(titleKey: "channelEdit.name") {
                    TextField("", text: $editor.draft.name)
                        .font(TypeFace.body(14))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("channel-edit-name")
                }

                field(titleKey: "channelEdit.prompt", hintKey: "channelEdit.prompt.hint") {
                    TextEditor(text: $editor.draft.prompt)
                        .font(TypeFace.body(13.5))
                        .frame(minHeight: 92)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("channel-edit-prompt")
                }

                field(titleKey: "channelEdit.tone") {
                    TextField("", text: $editor.draft.tone)
                        .font(TypeFace.body(14))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("channel-edit-tone")
                }

                field(titleKey: "channelEdit.schedule", hintKey: "channelEdit.schedule.hint") {
                    ScheduleEditor(schedule: $editor.draft.schedule)
                }

                field(titleKey: "channelEdit.connectors", hintKey: "channelEdit.connectors.hint") {
                    connectorList
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
                Text(L10n.string("channelEdit.title", locale: locale))
                    .font(TypeFace.heading(14))
                    .foregroundStyle(Palette.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        if let updated = await editor.save() {
                            onSaved(updated)
                            dismiss()
                        }
                    }
                } label: {
                    if editor.isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L10n.string("channelEdit.save", locale: locale))
                            .font(TypeFace.heading(14))
                            .foregroundStyle(editor.hasChanges ? Palette.ink : Palette.inkTertiary)
                    }
                }
                .disabled(!editor.hasChanges || editor.isSaving)
                .accessibilityIdentifier("channel-edit-save")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text(L10n.string("common.cancel", locale: locale))
                        .font(TypeFace.body(14))
                        .foregroundStyle(Palette.inkSecondary)
                }
                .accessibilityIdentifier("channel-edit-cancel")
            }
        }
        .accessibilityIdentifier("channel-edit-view")
    }

    private var fieldBackground: Color {
        Palette.surface
    }

    private var connectorList: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if channel.connectorIDs.isEmpty {
                Text(L10n.string("channelEdit.connectors.empty", locale: locale))
                    .font(TypeFace.body(12.5))
                    .foregroundStyle(Palette.inkTertiary)
            } else {
                ForEach(channel.connectorIDs, id: \.self) { connectorID in
                    HStack(spacing: Space.s) {
                        ChannelDot(channelID: connectorID, diameter: 7)
                        Text(ConnectorDisplay.name(for: connectorID, locale: locale))
                            .font(TypeFace.body(13))
                            .foregroundStyle(Palette.inkSecondary)
                        Spacer(minLength: 0)
                        Text(L10n.string("channelEdit.connectors.readOnly", locale: locale))
                            .font(TypeFace.label(10))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .padding(.vertical, Space.xs)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityIdentifier("channel-edit-connectors")
    }

    private func field<Content: View>(
        titleKey: String,
        hintKey: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(L10n.string(titleKey, locale: locale))
                .font(TypeFace.label(11))
                .tracking(1)
                .foregroundStyle(Palette.inkTertiary)
            content()
            if let hintKey {
                Text(L10n.string(hintKey, locale: locale))
                    .font(TypeFace.body(11))
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 采集时间表编辑

struct ScheduleEditor: View {
    @Binding var schedule: Schedule
    @Environment(\.appLocale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.xs) {
                ForEach(Schedule.weekdays) { weekday in
                    Button {
                        schedule.toggle(weekday)
                    } label: {
                        Text(L10n.string(weekday.symbolKey, locale: locale))
                            .font(TypeFace.label(12))
                            .foregroundStyle(schedule.isEnabled(weekday) ? Palette.canvas : Palette.inkSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.s)
                            .background(
                                schedule.isEnabled(weekday) ? Palette.ink : Palette.surface,
                                in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                    .strokeBorder(Palette.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("schedule-weekday-\(weekday.key)")
                }
            }

            if !schedule.activeWeekdays.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(schedule.allTimes, id: \.self) { time in
                            timePill(time)
                        }
                        addTimeControl
                    }
                }
            }
        }
    }

    private func timePill(_ time: String) -> some View {
        Button {
            // 点一下把该时刻应用到所有选中星期。
            schedule.applyTimeToAllEnabled(time)
        } label: {
            Text(time)
                .font(TypeFace.condensed(12.5, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(Palette.line, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var addTimeControl: some View {
        DatePicker(
            "",
            selection: Binding(
                get: {
                    let first = schedule.allTimes.first ?? "08:00"
                    return ScheduleDate.parse(first)
                },
                set: { newValue in
                    let formatted = ScheduleDate.format(newValue)
                    for weekday in schedule.activeWeekdays {
                        schedule.addTime(formatted, to: weekday)
                    }
                }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .accessibilityLabel(Text(String(localized: "schedule.addTime")))
        .accessibilityIdentifier("schedule-add-time")
    }
}

enum ScheduleDate {
    static func parse(_ value: String) -> Date {
        let calendar = Calendar.shanghai
        let parts = value.split(separator: ":").compactMap { Int($0) }
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = parts.first ?? 8
        components.minute = parts.count > 1 ? parts[1] : 0
        return calendar.date(from: components) ?? Date()
    }

    static func format(_ date: Date) -> String {
        let components = Calendar.shanghai.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 8
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - 连接器名称
//
// 手机端只拿到 connectorId，显示成可读短名；未知 id 原样呈现。

enum ConnectorDisplay {
    static func name(for connectorID: String, locale: Locale) -> String {
        switch connectorID {
        case "cnn_homepage":
            return L10n.string("connector.hn", locale: locale)
        case "cnn_github_trending":
            return L10n.string("connector.githubTrending", locale: locale)
        default:
            return connectorID
        }
    }
}
