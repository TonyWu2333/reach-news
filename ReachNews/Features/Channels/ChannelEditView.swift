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
    @Environment(AppEnvironment.self) private var env
    @State private var showsDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: APIError?

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

                field(
                    titleKey: "channelEdit.schedule",
                    hintKey: "channelEdit.schedule.hint",
                    hintArguments: [env.settings.displayTimeZone]
                ) {
                    ScheduleEditor(schedule: $editor.draft.schedule)
                }

                field(titleKey: "channelEdit.connectors", hintKey: "channelEdit.connectors.hint") {
                    connectorList
                }

                deleteSection
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
        }
        .confirmationDialog(
            L10n.string("channelEdit.delete.confirm.title", locale: locale),
            isPresented: $showsDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.string("channelEdit.delete.confirm.action", locale: locale), role: .destructive) {
                Task { await performDelete() }
            }
            Button(L10n.string("common.cancel", locale: locale), role: .cancel) {}
        } message: {
            Text(L10n.string("channelEdit.delete.confirm.message", locale: locale))
        }
        .task {
            if env.channels.connectors.isEmpty {
                await env.channels.loadCreationOptions()
            }
        }
        .accessibilityIdentifier("channel-edit-view")
    }

    private func performDelete() async {
        guard !isDeleting else { return }
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }

        if await env.channels.delete(channel.id) {
            dismiss()
        } else {
            // 409 表示有运行未结束：提示并保留当前页面。
            deleteError = env.channels.createError
        }
    }

    private func hintText(_ key: String, arguments: [CVarArg]) -> String {
        guard !arguments.isEmpty else { return L10n.string(key, locale: locale) }
        return String(format: L10n.string(key, locale: locale), locale: locale, arguments: arguments)
    }

    private var fieldBackground: Color {
        Palette.surface
    }

    /// 删除入口：二次确认后才执行。日报与素材由服务端保留，只是频道不再出现。
    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Button {
                showsDeleteConfirm = true
            } label: {
                HStack(spacing: Space.xs) {
                    if isDeleting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(L10n.string("channelEdit.delete", locale: locale))
                        .font(TypeFace.heading(13.5))
                }
                .foregroundStyle(Palette.failedForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.failedBackground)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .accessibilityIdentifier("channel-edit-delete")

            if let error = deleteError {
                InlineNotice(
                    text: L10n.string(error.messageKey, locale: locale),
                    detail: error.isBusy
                        ? L10n.string("channelEdit.delete.busy", locale: locale)
                        : error.detailText,
                    kind: .error
                )
                .accessibilityIdentifier("channel-edit-delete-error")
            }

            Text(L10n.string("channelEdit.delete.hint", locale: locale))
                .font(TypeFace.body(11))
                .foregroundStyle(Palette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Space.s)
    }

    /// 连接器可编辑：整体替换语义，提交时传 connectorIds。
    private var connectorList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if env.channels.connectors.isEmpty {
                Text(L10n.string("channelEdit.connectors.empty", locale: locale))
                    .font(TypeFace.body(12.5))
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.vertical, Space.s)
            } else {
                ForEach(env.channels.connectors) { connector in
                    let isOn = editor.draft.connectorIDs.contains(connector.id)
                    Button {
                        if isOn {
                            editor.draft.connectorIDs.removeAll { $0 == connector.id }
                        } else {
                            editor.draft.connectorIDs.append(connector.id)
                        }
                    } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15))
                                .foregroundStyle(isOn ? Palette.ink : Palette.inkTertiary)
                            Text(connector.name)
                                .font(TypeFace.body(13))
                                .foregroundStyle(Palette.inkSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Space.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("channel-edit-connector-\(connector.id)")
                }
            }

            if editor.draft.connectorIDs.isEmpty {
                Text(L10n.string("channelEdit.connectors.emptyWarning", locale: locale))
                    .font(TypeFace.body(11))
                    .foregroundStyle(Palette.failedForeground)
                    .padding(.top, Space.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.field))
        .accessibilityIdentifier("channel-edit-connectors")
    }

    private func field<Content: View>(
        titleKey: String,
        hintKey: String? = nil,
        hintArguments: [CVarArg] = [],
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
        VStack(alignment: .leading, spacing: Space.m) {
            // 星期选择：短名，避免长名换行断字。
            HStack(spacing: Space.xs) {
                ForEach(Schedule.weekdays) { weekday in
                    Button {
                        schedule.toggle(weekday)
                    } label: {
                        Text(L10n.string(weekday.shortKey, locale: locale))
                            .font(TypeFace.label(12))
                            .foregroundStyle(schedule.isEnabled(weekday) ? Palette.canvas : Palette.inkSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.s)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                    .fill(schedule.isEnabled(weekday) ? Palette.ink : Palette.surface)
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

            // 每个选中的星期各自维护时刻，支持一天多时刻。
            ForEach(schedule.activeWeekdays) { weekday in
                weekdayRow(weekday)
            }
        }
    }

    /// 「周一  [01:25] ✕  [08:00] ✕  [+ 添加]」
    private func weekdayRow(_ weekday: Schedule.Weekday) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(L10n.string(weekday.symbolKey, locale: locale))
                .font(TypeFace.label(11))
                .foregroundStyle(Palette.inkTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(schedule.times(for: weekday), id: \.self) { time in
                        timePill(time, weekday: weekday)
                    }
                    addTimeControl(for: weekday)
                }
            }
        }
        .padding(.vertical, Space.xs)
        .accessibilityIdentifier("schedule-row-\(weekday.key)")
    }

    private func timePill(_ time: String, weekday: Schedule.Weekday) -> some View {
        HStack(spacing: 4) {
            Text(time)
                .font(TypeFace.condensed(12.5, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
            Button {
                schedule.removeTime(time, from: weekday)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L10n.string("schedule.removeTime", locale: locale)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Palette.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 1)
        }
    }

    /// 为该星期添加一个时刻。
    private func addTimeControl(for weekday: Schedule.Weekday) -> some View {
        DatePicker(
            "",
            selection: Binding(
                get: {
                    ScheduleDate.parse(schedule.times(for: weekday).first ?? "08:00")
                },
                set: { newValue in
                    schedule.addTime(ScheduleDate.format(newValue), to: weekday)
                }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .accessibilityLabel(Text(L10n.string("schedule.addTime", locale: locale)))
        .accessibilityIdentifier("schedule-add-time-\(weekday.key)")
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
