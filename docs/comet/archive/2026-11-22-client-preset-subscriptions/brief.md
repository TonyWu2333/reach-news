# 目标

服务端已把「预设模板 + 实例化」整体改为「频道公开 + 订阅 + fork」。本轮把 iOS 客户端从旧的预设模型迁到订阅模型：删除预设相关调用与分支，按 `owner` 区分「我的 / 订阅的 / 可订阅的」，让订阅频道以只读形态出现在列表、日报与筛选中，并提供订阅、取消订阅、改订阅颜色与 fork 四条动作。

需求来源为 `/var/lib/dsh/reach-news/docs/api-changes-preset-subscriptions.md`（手机端 API 变更说明），权威契约是其引用的 `/var/lib/dsh/reach-news/API.md`。客户端内部术语遵循 `GLOSSARY.md`：频道、日报、分组、条目、素材、运行、采集时间表、口吻、连接器、错过、失败、追问、收藏、偏好。

# 范围

## 目录结构

### 新建

- `ReachNews/Features/Channels/SubscribedChannelDetail.swift`：订阅频道只读详情（名称、方向、口吻、时间表、连接器、订阅色），底部提供改颜色 / fork / 取消订阅。
- `ReachNewsTests/ChannelSubscriptionTests.swift`：订阅相关 DTO 解码、可写性判定、订阅/取消/fork 请求与方法路径、错误码映射。

### 修改

- `ReachNews/Domain/Enums.swift`：`ChannelKind` 去掉 `preset`（未知值降级为 `channel`）；新增 `ChannelOwner`（`creator` / `subscriber`）；`APIErrorCode` 增加 `presets_removed` / `not_published` / `own_channel` / `subscriber_read_only`。
- `ReachNews/Domain/Models.swift`：`Channel` 增加 `published`、`owner`、`subscribed`、`subscriptionColor`、`subscriptionID`，并派生 `canEdit` / `canSubscribe` / `canUnsubscribe`；删除 `ChannelPreset`。
- `ReachNews/Data/DTO/DTOs.swift`：`ChannelDTO` 解码五个新字段；新增订阅响应与 fork 请求体；删除 `PresetDTO`。
- `ReachNews/Data/APIClient.swift`：`Endpoint` 删除 `presets` / `instantiatePreset`，新增 discover 列表、订阅、改订阅色、取消订阅、fork；`APIError` 归一化四个新 code。
- `ReachNews/State/ChannelStore.swift`：列表按 `owner` 拆成「我的 / 订阅的 / 可订阅的」三段；新增订阅、取消订阅、改订阅颜色、fork 动作与各自的错误呈现；创建流程不再拉预设。
- `ReachNews/Features/Channels/ChannelListView.swift`：三段式列表、订阅角标与只读卡、可订阅行的「订阅」按钮、订阅频道点击进入只读详情。
- `ReachNews/Features/Channels/ChannelEditView.swift`：只对 `owner == creator` 的频道开放编辑、保存与删除。
- `ReachNews/Features/Channels/ChannelCreateSheet.swift`：新建说明与颜色入口保持；不再引用预设。
- `ReachNews/Resources/zh-Hans.lproj/Localizable.strings`、`ReachNews/Resources/en.lproj/Localizable.strings`：新增订阅、发现、只读、错误文案键，删除预设模板相关键，两侧键集保持完全对齐。
- `ReachNewsTests/APIClientTests.swift`、`ReachNewsTests/NormalizationTests.swift`、`ReachNewsTests/DTODecodingTests.swift`、`Fixtures/channels.json`：替换预设断言为订阅断言，样本覆盖 `owner`/`subscribed`/空字符串 `subscriptionColor`。

### 删除

- `ReachNews/Features/Channels/PresetPicker.swift`：预设选择页整体下线。

### 明确不建

- 不做频道公开 / 取消公开入口（`published` 只有管理员能改，客户端无写接口）。
- 不做订阅者编辑频道、触发运行、删除频道（服务端拒绝，界面不提供入口）。
- 不引入 SSE / WebSocket / 推送；订阅变化靠下拉刷新与现有轮询。

# 非目标

- 不修改 `android/**`。
- 不新增服务端能力、不代理管理员操作（`/admin/api/*` 不访问）。
- 不改日报、追问、收藏、登录等与订阅无关的既有行为。
- 不实现「用户公开自己的频道」——本期明确在服务端范围外。

# 验收示例

- 频道 DTO 解码后带有 `published`、`owner`、`subscribed`、`subscriptionColor`、`subscriptionId` 五个字段；缺少时分别回退为 `false`、`creator`、`false`、`null`、`null`，不崩溃。
- `owner == "subscriber"` 的频道 `canEdit` 为 false；`published` 且非自己创建且未订阅时 `canSubscribe` 为 true；`subscribed` 为 true 时 `canUnsubscribe` 为 true。
- 客户端不再请求 `/api/v1/presets` 与 `/api/v1/presets/:id/instantiate`；`Endpoint` 中不存在这两个路径。
- `ChannelKind` 只有 `channel` 与 `follow`；解析 `"preset"` 与未知字符串都得到 `.channel`，列表不再按 `preset` 过滤。
- 频道列表调用 `GET /api/v1/channels`（默认列表），并按 `owner` 分出「我的频道」与「订阅的频道」两段。
- 列表另有「发现更多」段，数据来自 `GET /api/v1/channels?discover=1`，只列出 `subscribed == false` 且 `owner != "creator"` 的项。
- 点「订阅」调用 `POST /api/v1/channels/:id/subscribe`，请求体带当前选择颜色；成功后该频道出现在「订阅的频道」，并从「发现更多」移除。
- 重复订阅按幂等处理：`200` 与 `201` 都视为成功，不出现重复卡片。
- 订阅频道卡片显示订阅色点与只读标记，不显示 `enabled` 开关、编辑与删除入口。
- 点击订阅频道进入只读详情；该页只提供改颜色、fork、取消订阅三项动作。
- 改订阅颜色调用 `PATCH /api/v1/channels/:id/subscribe`，只提交 `color`；成功后列表与详情立即使用新颜色。
- 取消订阅调用 `DELETE /api/v1/channels/:id/subscribe`；成功后该频道从「订阅的频道」消失，其日报也不再出现在日报流与筛选中。
- fork 调用 `POST /api/v1/channels/:id/fork`；成功后新频道以 `owner == "creator"`、`published == false` 出现在「我的频道」，原订阅消失。
- 订阅自己创建的频道返回 `409 own_channel`；订阅未公开频道返回 `403 not_published`。两者都以归一化文案提示，不崩溃、不产生幽灵条目。
- 订阅者对频道调用 `PATCH` / 触发运行返回的 `403 subscriber_read_only` 被归一化为「订阅频道只读，可 fork 后修改」，界面不会先提供必然失败的按钮。
- 遗留调用命中已下线端点时的 `404 presets_removed` 归一化为「旧接口已停用」，与普通 `not_found` 区分。
- 订阅色为空字符串时按「未设置」处理：显示本地色板颜色（或按 `channelId` 稳定回退色），不显示空色点。
- 「我的频道」内 `published == false` 的频道正常显示并可以编辑；界面不提供公开开关。
- 新建频道成功后进入「我的频道」；创建流程不再出现「从模板新建」入口。
- 订阅频道的日报与创建者读到同一份：日报流、日报详情、频道筛选里都按原 `channelId` 呈现。
- 中英文键集完全对齐，界面无硬编码文案；`PresetPicker` 删除后无残留引用与未使用键。
- 单元测试覆盖：五个新字段解码、可写性三判定、订阅/改色/取消/fork 的路径与请求方法、四个新错误码归一化、空字符串订阅色回退；`xcodegen generate` + `xcodebuild test` 通过。

# 约束与不变量

- 服务端契约以 `API.md` 为准；文档与 `API.md` 冲突时按 `API.md` 实现，并在 brief 记录差异。
- 可写性判定只使用 `owner`，不得用 `kind` 判断（`kind` 与订阅无关）。
- 订阅是「用户 × 频道」的关系，不产生独立的频道条目；订阅频道的 `id` 就是原频道的 `id`。
- 颜色只校验长度（≤32 字符），服务端不维护色值枚举；客户端解释方式见决策 D3。
- 取消订阅 / 取消公开后内容立即不可见，客户端不在本地缓存频道或日报内容（ADR 0003 不变）。
- 所有请求继续带 `Authorization: Bearer <会话凭证>`；不访问 `/admin/*` 与 `/admin/api/*`。
- 既有 token 不变：两套视觉语言、频道标识色、圆角与间距、压缩数字体继续使用 `Palette` / `ChannelTint` / `Space` / `Radius`。

# 决策

- D1 列表结构：三段式单页。「我的频道」→「订阅的频道」→「发现更多」，发现更多默认折叠、可展开。要求三段在同一滚动列表按此顺序呈现。
- D2 订阅色语义：复用现有 12 色调色板。订阅时提交色板色值字符串；读取时与色板比对，命中用该色，未命中或空字符串回退本地色板，再回退按 `channelId` 的稳定色。
- D3 订阅频道详情：新建独立只读详情页；改颜色是页面内的普通行，fork 与取消订阅放导航栏菜单；不复用编辑页，避免出现必然失败的保存与删除。页面不使用底部通栏按钮。
- D4 fork 交互：二次确认说明「复制成我的频道，并取消当前订阅」，确认后按原名 fork，成功后进入编辑页改名。
- D5 发现更多加载：进入频道页时与默认列表并行加载 `discover=1`，随刷新与下拉刷新重取；单段失败只影响该段。
- D6 `kind` 收敛：`.channel` / `.follow` 两值，`preset` 与未知值一律降级 `.channel`；移除「管理员模板频道不进列表」的过滤。
- D7 订阅色缺失（`null` 或空字符串）按「未设置」处理，不渲染空色点。
- D8 订阅者不渲染 `enabled` 开关、编辑、立即运行与删除入口；列表项不再假设「每一项都能编辑」。
- D9 四个新错误码各有独立本地化键；`presets_removed` 与普通 `not_found` 区分呈现。
- D10 界面默认只给「标题 + 交互组件」，不写解释性小字；仅保留二次确认说明、错误原因与空态下一步。用户主动要求时才加说明。
- D11 不使用底部通栏大按钮作为页面主操作：主操作放导航栏，或列表行、行尾箭头、开关等 iOS 惯用控件；整宽按钮仅用于单一任务的一次性确认（如登录页提交）。

# 待解决问题

无。Q1–Q5 已由用户确认，结论见上节 D1–D5。

# 验证预期

- `xcodegen generate` 后在 CI 的 iOS 任务里 `xcodebuild test` 通过；`android/**` 字节不变且 `assembleDebug` 通过。
- 单元测试覆盖 DTO 解码、可写性判定、四条订阅动作的请求形状与路径、四个新错误码归一化。
- 以固定响应替身驱动 UI 断言：三段列表、订阅按钮、只读卡无编辑入口、订阅后从「发现更多」消失。
- 生产环境实测（可选，凭据可得时）：登录后拉默认列表与 `discover=1`，订阅、改色、fork、取消订阅各一轮，并核对日报可见性变化。
