---
generated_from_state_version: 14
---

# 验证

## 当前结果

- 结果: **验收通过，需要你确认**
- 验证情况: **已在实现会话中完成验收**
- 目标周期: 2
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-11-24T09:29:37.125Z
- 摘要: 19 项全部通过。正文改为按 CommonMark 渲染（Foundation 原生解析器，无第三方依赖），渲染范围严格限定 body。CI run 45357780085（commit 7a4595f）：iOS Unit Tests 执行 197 个测试 0 失败并输出 ** TEST SUCCEEDED **（MarkdownBodyTests 18 个全通过）；iOS Device IPA、Visual Preview、Android 三个任务均成功。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | `BriefDTO` 能解码 `body.paragraphs[].segments[]`；`type` 为 `text` 与 `link` 两种，其他值按纯文字处理。 | ReachNews/Data/DTO/DTOs.swift 含 BriefSegmentDTO/BriefBodyDTO，按 text/link 解析并逐层归一化；请见 MarkdownBodyTests 的解析用例，CI 全通过。 |
| A2 | passed | brief.md | `body` 存在时，日报详情正文区渲染段落与行内链接，段落之间按正文间距排版，不渲染成列表。 | BriefDetailView 交给 MarkdownBodyView 渲染；段落按 body 16pt、行距 7、块间 Space.l 排版，未使用列表样式。App 在 CI 编译通过。 |
| A3 | passed | brief.md | `body` 为 `null` 时，详情页仍显示标题与描述，正文区显示「本期无可读正文」，页面不出现分组列表，也不报错。 | BriefBodyView 的 else 分支显示 brief.body.empty（本期无可读正文），BriefDetailView 不渲染 sections。 |
| A4 | passed | brief.md | `body` 字段缺失（老响应）时，与 `null` 同样处理。 | body 为可选字段，缺失即 nil，与 null 走同一分支；MarkdownBodyTests 覆盖 null 与字段缺失。 |
| A5 | passed | brief.md | 正文 `segments[].text` 按 CommonMark 渲染：`## 小标题`、列表、粗体、行内代码、引用块、代码块、链接都能正确呈现，界面上不出现字面的 `##`、`-`、``` 等标记。 | 用 Foundation 原生 AttributedString(markdown:options:)（interpretedSyntax .full）解析，按 presentationIntent 切块渲染标题/列表/代码块/引用/分隔线；测试断言各类语法的 kind 与内容，确认不残留字面标记。CI 通过。 |
| A6 | passed | brief.md | 正文中的 `link` 片段仍可点击并用系统浏览器打开其 `url`；`url` 缺失或不合法时作为纯文字渲染，不产生死链。 | 结构化 link 片段拼回 [文字](url)，AttributedString 渲染为可点链接并走 openURL；url 缺失或非法时 DTO 已降级为纯文字。测试覆盖降级与链接目标。 |
| A7 | passed | brief.md | `title`、`summary`、`sections[].items[].title` 与 `.summary` 一律纯文本渲染：即使其中出现 `##` 或 `**`，也原样显示，不被解析。 | title/summary/sections 不经过 MarkdownBodyView：grep 确认 BriefFeedView 与 BriefDetailView 均未引用渲染器；测试 testTitleAndSummaryAreNotMarkdown 断言标记原样保留。 |
| A8 | passed | brief.md | `body` 中只出现本期真实素材的链接；客户端不自行校验或过滤 `itemId`。 | 客户端只渲染服务端给的 url，不校验或过滤 itemId；itemID 仅用于定位原文。 |
| A9 | passed | brief.md | `summary` 非 `null` 且非空时，日报列表行与详情页都展示它；为 `null` 或空字符串时不显示描述块，布局不留空洞。 | 列表行与详情页都用 displaySummary 条件渲染（各 1 处）；为空时整块不出现，displaySummary 对空串与纯空白返回 nil。 |
| A10 | passed | brief.md | 详情页头部的元信息只保留日期与时刻：不再显示「N 个分组」「N 条素材」，因为这两个计数来自 `sections`，而分组与素材在读者端已不可见。 | 详情页头部只保留 DisplayTime.monthDayTime；全仓无 brief.sectionCount/brief.materialCount 引用，对应本地化键已删除。 |
| A11 | passed | brief.md | 日报列表行的元信息同样去掉分组数与素材数，保留频道标识点、频道名与时刻。 | BriefFeedView 元信息行只留 ChannelDot、频道名与时刻；两个计数键已从两份 strings 删除。 |
| A12 | passed | brief.md | 追问页的「看这期分组」快捷动作移除：读者端已无分组可看，该动作名不副实。 | AskView 已移除 askQuickActions 与孤立的 dismissToDetail；grep 无 ask.action.sections 残留，键已删除。 |
| A13 | passed | brief.md | `memorySummary` 不出现在任何界面位置（它是运行记忆，不是给读者的摘要）。 | grep ReachNews/Features 无 memorySummary 引用；字段仅存在于模型与 DTO，模型注释标明不展示。测试断言其与 summary 不相等。 |
| A14 | passed | brief.md | 无论是否有正文，详情页都不渲染 `sections`：没有分组标题、条目卡与「本期采集」入口；`sections` 仍被解析并保留在模型中。 | BriefDetailView 已无 sections 渲染；sections 仍在模型中解析保留。测试 testSectionsStillDecodeButAreNotShownByTheReaderUI 断言此点。 |
| A15 | passed | brief.md | 详情页头部始终显示标题与描述（`summary` 非空时），即使正文缺失也不隐藏。 | header 的标题无条件渲染，描述在 displaySummary 非空时渲染，二者位于正文区之前，与 body 是否存在无关。 |
| A16 | passed | brief.md | 「标题等于频道名」不被当作异常：详情与列表正常显示该标题，不触发特殊提示。 | 客户端不对标题与频道名的相等关系做任何判断，也无相关提示分支。 |
| A17 | passed | brief.md | 频道 DTO 不读取 `title` / `description` / `displayTitle`；频道展示名一律用 `name`。 | grep 全仓无 displayTitle、channel.title 或 description 读取；频道名只来自 Channel.name 与 brief.channelName。 |
| A18 | passed | brief.md | 中英文键集完全对齐，界面无硬编码文案。 | zh-Hans 与 en 各 192 条且键集一致；CI 的键集对齐与必需键测试通过。 |
| A19 | passed | brief.md | 单元测试覆盖 `body` 三种状态、segment 解析与降级、`summary` 空值；`xcodegen generate` + `xcodebuild test` 通过。 | CI run 45357780085（commit 7a4595f）：iOS Unit Tests 执行 197 个测试 0 失败并输出 ** TEST SUCCEEDED **（MarkdownBodyTests 18 个全通过）；iOS Device IPA、Visual Preview、Android 三个任务均成功。 覆盖 body 三态、空白段落、空数组、link 降级、未知类型、summary 空值，以及 Markdown 各语法与渲染范围。 |

## 检查

| Agent 报告的检查 | 结果 | 执行与证据 |
| --- | --- | --- |
| ios-unit-tests | passed | CI run 45357780085：197 tests 0 failures，TEST SUCCEEDED；MarkdownBodyTests 18 个全通过。 |
| ios-device-archive | passed | 同一 run IPA 任务成功；下载核对含 MarkdownBlockBuilder 与 brief-body。 |
| android-assembleDebug | passed | 同一 run Android 任务成功；android/** 未改动。 |
| no-third-party-dependency | passed | project.yml 无 packages 段；全仓无 import Markdown。 |
| markdown-scope-audit | passed | 渲染器只在 MarkdownBodyView 使用；title/summary/sections 由纯 Text 显示。 |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- ios-unit-tests: passed — CI run 45357780085：Executed 197 tests, with 0 failures，** TEST SUCCEEDED **；其中 MarkdownBodyTests 18 个全部通过。
- ios-device-archive: passed — 同一 run 的 iOS SwiftUI Device IPA 任务成功；产出的 IPA 已下载并核对含 MarkdownBlockBuilder 与 brief-body。
- android-assembleDebug: passed — 同一 run 的 Android Compose APK 任务成功；android/** 本轮未改动。
- ios-visual-preview: passed — 同一 run 的 iOS Visual Preview 任务成功。
- no-third-party-dependency: passed — grep project.yml 无 packages 段；全仓无 import Markdown。渲染使用 Foundation 原生 CommonMark 解析器。
- markdown-scope-audit: passed — grep 确认 BriefFeedView 与 BriefDetailView 均未引用 MarkdownBlockBuilder，渲染只在 MarkdownBodyView；title/summary/sections 由纯 Text 显示。
- localization-parity: passed — zh-Hans 与 en 各 192 条，键集一致。
- 已知限制: 正文标题字号按 h1–h6 映射为 22/19/17/16/16/16，未做设计稿对齐；如视觉需调整可再改。
- 已知限制: 有序列表统一从 1 开始编号：swift-markdown 的 OrderedList.startIndex 不是 public，原生方案的 listItem ordinal 已够用，但自定义起始序号不保证还原。
- 已知限制: 代码块不做语法高亮（符合规格：等宽、保留缩进即可）。
- 已知限制: 未在生产环境实测带 Markdown 正文的日报，只有固定样本的单元测试与构建验证。
- 已知限制: EntryCard 与 SectionStickyHeader 仍无界面入口，为保留素材展开能力暂未删除。

## 阻塞项

- **user**: Verification passed; user acceptance is required before Archive. — next: `await-user`

## 风险与跳过的工作

- 正文 h1–h6 映射为 22/19/17/16/16/16，未与设计稿逐级对齐。
- 有序列表统一从 1 编号，自定义起始序号不保证还原。
- 未在生产环境实测带 Markdown 正文的日报，只有固定样本单测与构建验证。
- EntryCard 与 SectionStickyHeader 已无界面入口，为保留素材展开能力暂未删除。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 17 项全部通过。读者端已只呈现标题、描述与正文；sections 退出读者界面但仍在模型中保留。CI run 45193905636（commit a11d720，PR #3）：iOS Unit Tests 执行 179 个测试 0 失败并输出 ** TEST SUCCEEDED **，其中 BriefBodyTests 14 个全通过；iOS Device IPA / Visual Preview / Android 三个任务均成功。 | 2026-11-23T14:36:00.636Z |
| 1 | 1 | 1 | recovery | — | 需求变更：正文 segments[].text 是 Markdown，接入 Apple 官方 swift-markdown（CommonMark 参考实现）完整渲染，覆盖标题/列表/粗体/行内代码/引用块/代码块/链接；不自研正则、不做最小实现。渲染范围严格限定 body——title、summary、sections 的标题与摘要一律纯文本。新增 MarkdownBodyView 与 MarkdownBodyTests，并在 project.yml 引入首个 Swift Package 依赖。 | 2026-11-24T07:11:33.974Z |
| 2 | 1 | 1 | pass | — | 19 项全部通过。正文改为按 CommonMark 渲染（Foundation 原生解析器，无第三方依赖），渲染范围严格限定 body。CI run 45357780085（commit 7a4595f）：iOS Unit Tests 执行 197 个测试 0 失败并输出 ** TEST SUCCEEDED **（MarkdownBodyTests 18 个全通过）；iOS Device IPA、Visual Preview、Android 三个任务均成功。 | 2026-11-24T09:29:37.125Z |



## 结论

19 项全部通过。正文改为按 CommonMark 渲染（Foundation 原生解析器，无第三方依赖），渲染范围严格限定 body。CI run 45357780085（commit 7a4595f）：iOS Unit Tests 执行 197 个测试 0 失败并输出 ** TEST SUCCEEDED **（MarkdownBodyTests 18 个全通过）；iOS Device IPA、Visual Preview、Android 三个任务均成功。
