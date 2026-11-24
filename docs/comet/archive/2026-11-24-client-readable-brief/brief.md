# 目标

日报新增可读正文 `body`（段落 + 行内链接）与本期摘要 `summary`。客户端把日报详情从「只有分组条目」升级为「优先渲染 `body` 正文，缺失时降级到 `sections`」，并在列表与详情展示 `summary`；同时确认频道的 `title` / `description` / `displayTitle` 已作废、客户端一律用 `name`，不再实现这三个字段。

需求来源为两份服务端变更说明，以较新的一份取代较旧一份的冲突部分：

- `/var/lib/dsh/reach-news/docs/api-changes-readable-brief-and-channel-fields.md`（正文与可见性；其中「频道标题」第二部分已作废）
- `/var/lib/dsh/reach-news/docs/api-changes-brief-body-title-summary.md`（取代前者关于频道标题的部分）

权威契约是 `/var/lib/dsh/reach-news/API.md` 的日报对象一节。订阅模型那份说明（`api-changes-preset-subscriptions.md`）已在 change `client-preset-subscriptions` 中实现并通过验收，本次不重复其范围。

# 范围

## 目录结构

### 新建

- `ReachNews/Domain/BriefBody.swift`：`BriefBody` / `BriefParagraph` / `BriefSegment` 领域类型与渲染所需的派生判断（是否为空、链接片段过滤）。
- `ReachNews/Features/BriefDetail/MarkdownBodyView.swift`：把 `swift-markdown` 的 AST 映射为 SwiftUI（标题、段落、列表、引用、代码块、行内样式与链接），只用于正文。
- `ReachNewsTests/MarkdownBodyTests.swift`：覆盖各类语法的解析与「非 body 字段不解析」。
- `ReachNewsTests/BriefBodyTests.swift`：`body` 三种状态解码、segment 类型解析、缺失 `url` 的 link 降级、`summary` 为 null 的处理、正文降级到 `sections` 的判定。

### 修改

- `ReachNews/Domain/Models.swift`：`Brief` 增加 `summary: String?` 与 `body: BriefBody?`；保留 `memorySummary` 且明确它不参与展示。
- `project.yml`：引入 `swift-markdown` 的 Swift Package 依赖并锁定版本（本项目第一个第三方依赖）。
- `ReachNews/Data/DTO/DTOs.swift`：`BriefDTO` 解码 `summary` 与 `body`（`paragraphs[].segments[]`），`link` 缺 `url` 时降级为纯文字。
- `ReachNews/Features/BriefDetail/BriefDetailView.swift`：改为「标题 + 描述 + 正文」三段结构；`body == nil` 时正文区显示一句说明；**移除 `sections` 分组渲染**。
- `ReachNews/Features/Briefs/BriefFeedView.swift`：列表行在标题下显示 `summary`（非空时）。
- `ReachNews/Resources/zh-Hans.lproj/Localizable.strings`、`ReachNews/Resources/en.lproj/Localizable.strings`：新增正文相关键（如「暂无可读正文」），两侧保持对齐。
- `Fixtures/briefs.json`：补充 `summary`、`body`、`body: null`、`body` 缺字段四种样本。

### 明确不建

- 不实现频道 `title` / `description` / `displayTitle`（服务端已移除，客户端继续用 `name`）。
- 新增 Markdown 渲染：`body.paragraphs[].segments[].text` 按 CommonMark 渲染。
- 不把 `sections` 当正文脚注，也不用它反推正文内容；读者端不展示 `sections`。

# 非目标

- 不改 `android/**`。
- 不改订阅相关逻辑、鉴权与错误码（本次没有新增错误码）。
- 不改 `/cursor`、`/ask`、`/connectors`、`/settings` 的既有行为。
- 不为正文做富文本编辑器或编辑能力（正文只读）。

# 验收示例

- `BriefDTO` 能解码 `body.paragraphs[].segments[]`；`type` 为 `text` 与 `link` 两种，其他值按纯文字处理。
- `body` 存在时，日报详情正文区渲染段落与行内链接，段落之间按正文间距排版，不渲染成列表。
- `body` 为 `null` 时，详情页仍显示标题与描述，正文区显示「本期无可读正文」，页面不出现分组列表，也不报错。
- `body` 字段缺失（老响应）时，与 `null` 同样处理。
- 正文 `segments[].text` 按 CommonMark 渲染：`## 小标题`、列表、粗体、行内代码、引用块、代码块、链接都能正确呈现，界面上不出现字面的 `##`、`-`、``` 等标记。
- 正文中的 `link` 片段仍可点击并用系统浏览器打开其 `url`；`url` 缺失或不合法时作为纯文字渲染，不产生死链。
- `title`、`summary`、`sections[].items[].title` 与 `.summary` 一律纯文本渲染：即使其中出现 `##` 或 `**`，也原样显示，不被解析。
- `body` 中只出现本期真实素材的链接；客户端不自行校验或过滤 `itemId`。
- `summary` 非 `null` 且非空时，日报列表行与详情页都展示它；为 `null` 或空字符串时不显示描述块，布局不留空洞。
- 详情页头部的元信息只保留日期与时刻：不再显示「N 个分组」「N 条素材」，因为这两个计数来自 `sections`，而分组与素材在读者端已不可见。
- 日报列表行的元信息同样去掉分组数与素材数，保留频道标识点、频道名与时刻。
- 追问页的「看这期分组」快捷动作移除：读者端已无分组可看，该动作名不副实。
- `memorySummary` 不出现在任何界面位置（它是运行记忆，不是给读者的摘要）。
- 无论是否有正文，详情页都不渲染 `sections`：没有分组标题、条目卡与「本期采集」入口；`sections` 仍被解析并保留在模型中。
- 详情页头部始终显示标题与描述（`summary` 非空时），即使正文缺失也不隐藏。
- 「标题等于频道名」不被当作异常：详情与列表正常显示该标题，不触发特殊提示。
- 频道 DTO 不读取 `title` / `description` / `displayTitle`；频道展示名一律用 `name`。
- 中英文键集完全对齐，界面无硬编码文案。
- 单元测试覆盖 `body` 三种状态、segment 解析与降级、`summary` 空值；`xcodegen generate` + `xcodebuild test` 通过。

# 约束与不变量

- 服务端契约以 `API.md` 为准；两份变更说明冲突时，以较新的 `api-changes-brief-title-summary` 为准。
- `body` 与 `sections` 不是同一份内容的两种格式：正文可只引用部分素材，`sections` 始终是本期全量条目。两者都要读，不能相互替代。
- 正文的 `segments[].text` 是 Markdown（AI 按技能模板生成，语法不受逐字控制），客户端接入成熟 CommonMark 渲染器，不用正则自研。
- 渲染范围只有 `body`：`title`、`summary`、`sections[].items[].title` 与 `.summary` 一律纯文本，不解析 Markdown。
- 不降级为「只处理 ## 和 **」的最小实现：模型输出列表、代码块时用户会看到字面的 `-` 与 ```。
- `summary` 为 `null` 是正常状态，不是错误。
- 既有视觉与交互规则继续生效：两组视觉 token、频道标识色、以及 `AGENTS.md` 中「文案克制」与「不使用底部大按钮」两条界面约定。
- 不缓存日报正文；正文来自接口，按需渲染。

# 决策

- D1 读者侧只有「标题 + 描述 + 正文」。`sections` 在任何情况下都**不渲染**：读者端不再出现分组区块、条目卡或「本期采集」入口。`sections` 仍照常解析并保留在模型中，供后台核对与将来需要时使用，但不进入这个界面。
- D2 正文缺失的呈现：`body == nil` 时标题与描述照常显示，正文区显示一句「本期无可读正文」的说明；**不回退到 `sections`**，页面不出现分组列表。
- D3 元信息与计数：详情页头部只留日期与时刻；列表行只留频道标识点、频道名与时刻。分组数与素材数随 `sections` 一起退出读者界面，`entryCount` / `materialCount` 仍保留在模型中（供后台与将来使用）。
- D4 追问页的「看这期分组」动作一并移除：它原本只是返回详情页看分组，分组不再展示后该入口没有意义；追问页保留其余快捷动作与引用卡片处理。
- D5 Markdown 渲染：用 Apple 官方的 `swift-markdown`（CommonMark 参考实现的 Swift 版本）解析，自建轻量渲染视图把 AST 映射为 SwiftUI；不自研正则解析，也不只处理 `##` 与 `**` 两种语法。渲染范围严格限定 `body`。
- D6 渲染器依赖：以 Swift Package 形式引入，锁定版本；这是本项目第一个第三方依赖，需确认 CI 能正常解析与构建。
- D7 `summary` 的位置：列表行显示在标题下、元信息上；详情页显示在标题下、正文之前。为空时整块不渲染。
- D8 `memorySummary` 处理：保留在模型中（`/ask` 语义相关），但不在任何界面展示，并加注释说明原因。
- D9 链接渲染：`link` 片段渲染为可点文本，点击用系统浏览器打开；缺 `url` 的片段降级为纯文字，不生成不可用链接。
- D10 排版：段落之间用正文间距，行高与行宽按长文阅读设置；不套用列表或等宽样式。
# 待解决问题

无。

# 验证预期

- `xcodegen generate` 后在 CI 的 iOS 任务里 `xcodebuild test` 通过；`android/**` 字节不变且 `assembleDebug` 通过。
- 单元测试覆盖 `body` 三种状态、segment 解析与降级、`summary` 空值。
- 以固定响应替身驱动 UI 断言：有正文时渲染段落与链接，无正文时回退到分组。
- 生产环境实测（凭据可得时）：拉一期带正文的日报，确认段落与链接可读、旧日报仍可降级显示。
