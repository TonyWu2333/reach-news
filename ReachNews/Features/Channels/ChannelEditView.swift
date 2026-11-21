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
    @State private var showsConnectorPicker = false

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
                } else if let error = deleteError {
                    // 删除被拒（如运行中 409）：在顶部提示，保留当前页面。
                    InlineNotice(
                        text: L10n.string(error.messageKey, locale: locale),
                        detail: error.isBusy
                            ? L10n.string("channelEdit.delete.busy", locale: locale)
                            : error.detailText,
                        kind: .error
                    )
                    .accessibilityIdentifier("channel-edit-delete-error")
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

                field(titleKey: "channelEdit.prompt") {
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

                field(titleKey: "channelEdit.schedule") {
                    ScheduleEditor(schedule: $editor.draft.schedule)
                }

                field(titleKey: "channelEdit.connectors") {
                    connectorSummary
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
                Menu {
                    Button(role: .destructive) {
                        showsDeleteConfirm = true
                    } label: {
                        Label(L10n.string("channelEdit.delete", locale: locale), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.ink)
                }
                .accessibilityIdentifier("channel-edit-menu")
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
        .sheet(isPresented: $showsConnectorPicker) {
            ConnectorPicker(
                connectors: env.channels.connectors,
                selection: $editor.draft.connectorIDs,
                isPresented: $showsConnectorPicker
            )
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

    private var fieldBackground: Color {
        Palette.surface
    }

    /// 连接器：不在页面平铺，点开弹出多选。
    private var connectorSummary: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Button {
                showsConnectorPicker = true
            } label: {
                HStack(spacing: Space.s) {
                    Text(connectorSummaryText)
                        .font(TypeFace.body(14))
                        .foregroundStyle(selectedConnectorNames.isEmpty ? Palette.inkTertiary : Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.field)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("channel-edit-connectors")

            if editor.draft.connectorIDs.isEmpty {
                Text(L10n.string("channelEdit.connectors.emptyWarning", locale: locale))
                    .font(TypeFace.footnote)
                    .foregroundStyle(Palette.failedForeground)
            }
        }
    }

    private var selectedConnectorNames: [String] {
        env.channels.connectors
            .filter { editor.draft.connectorIDs.contains($0.id) }
            .map(\.name)
    }

    private var connectorSummaryText: String {
        let names = selectedConnectorNames
        if names.isEmpty { return L10n.string("channelEdit.connectors.none", locale: locale) }
        if names.count <= 2 { return names.joined(separator: "、") }
        return L10n.format("channelEdit.connectors.someSelected", locale: locale, names.count)
    }

    /// 苹果风格：标题 + 控件，不加解释性小字。
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
        HStack(spacing: Space.s) {
            Text(L10n.string(weekday.shortKey, locale: locale))
                .font(TypeFace.label(12))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 26, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(schedule.times(for: weekday), id: \.self) { time in
                        timePill(time, weekday: weekday)
                    }
                }
            }

            // 达到上限就不再显示添加按钮，避免无效点击。
            if schedule.canAddTime(to: weekday) {
                addTimeButton(for: weekday)
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("schedule-row-\(weekday.key)")
    }

    /// 可点掉的时刻胶囊。
    private func timePill(_ time: String, weekday: Schedule.Weekday) -> some View {
        Button {
            schedule.removeTime(time, from: weekday)
        } label: {
            Text(time)
                .font(TypeFace.condensed(12.5, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Palette.surface)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(Palette.line, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.format("schedule.removeTime", locale: locale, time)))
    }

    /// 加号按钮：点开时间选择器，选定后追加一个时刻。
    private func addTimeButton(for weekday: Schedule.Weekday) -> some View {
        Menu {
            ForEach(Self.presetTimes, id: \.self) { time in
                Button(time) {
                    schedule.addTime(time, to: weekday)
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Palette.surface))
                .overlay { Circle().strokeBorder(Palette.line, lineWidth: 1) }
        }
        .accessibilityLabel(Text(L10n.string("schedule.addTime", locale: locale)))
        .accessibilityIdentifier("schedule-add-time-\(weekday.key)")
    }

    /// 常用时刻，避免弹出键盘输入。
    private static let presetTimes: [String] = [
        "06:00", "07:00", "07:30", "08:00", "08:30", "09:00", "09:30",
        "12:00", "12:30", "17:00", "18:00", "18:30", "19:00", "20:00", "21:00", "22:00"
    ]
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
