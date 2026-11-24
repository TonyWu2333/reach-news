---
generated_from_state_version: 10
---

# 验证

## 当前结果

- 结果: **验收通过，需要你确认**
- 验证情况: **已在实现会话中完成验收**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 2
- 完成时间: 2026-11-22T11:30:28.760Z
- 摘要: 22 项全部通过。A1–A21 以代码位置与 CI 实际通过的测试为依据；A22 此前唯一缺口是真实构建与测试证据，现由 CI run 45016466235 补齐：GitHub Actions run 45016466235（commit d834dd9，PR #2）：iOS Unit Tests 执行 165 个测试 0 失败并输出 ** TEST SUCCEEDED **（其中 ChannelSubscriptionTests 22 个全通过）；iOS SwiftUI Device IPA 任务成功归档并产出 IPA；Android Compose APK 的 assembleDebug 成功；iOS Visual Preview 成功。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | 频道 DTO 解码后带有 `published`、`owner`、`subscribed`、`subscriptionColor`、`subscriptionId` 五个字段；缺少时分别回退为 `false`、`creator`、`false`、`null`、`null`，不崩溃。 | ReachNews/Data/DTO/DTOs.swift:120-139：ChannelDTO 解码 published/owner/subscribed/subscriptionColor/subscriptionId，toDomain 回退为 false/creator/false/原值/原值；测试 testChannelDTOFallsBackWhenSubscriptionFieldsMissing 覆盖缺字段。 |
| A2 | passed | brief.md | `owner == "subscriber"` 的频道 `canEdit` 为 false；`published` 且非自己创建且未订阅时 `canSubscribe` 为 true；`subscribed` 为 true 时 `canUnsubscribe` 为 true。 | ReachNews/Domain/Models.swift 可写性段：canEdit=owner.isCreator、canSubscribe=published && !owner.isCreator && !subscribed、canUnsubscribe=subscribed；测试 testChannelEditabilityFollowsOwnerNotKind 覆盖四种组合。 |
| A3 | passed | brief.md | 客户端不再请求 `/api/v1/presets` 与 `/api/v1/presets/:id/instantiate`；`Endpoint` 中不存在这两个路径。 | grep 全仓无 api/v1/presets；Endpoint 枚举只含 subscribe(channelID:)/fork(channelID:)，无 presets/instantiatePreset；api/v1/presets 路径已消失。 |
| A4 | passed | brief.md | `ChannelKind` 只有 `channel` 与 `follow`；解析 `"preset"` 与未知字符串都得到 `.channel`，列表不再按 `preset` 过滤。 | ReachNews/Domain/Enums.swift:8-21：ChannelKind 只有 channel/follow，init(apiValue:) 对 preset 与未知值均回落 .channel；测试 testChannelKindParsing 断言二者均得 .channel 且 allCases.count==2。 |
| A5 | passed | brief.md | 频道列表调用 `GET /api/v1/channels`（默认列表），并按 `owner` 分出「我的频道」与「订阅的频道」两段。 | ChannelListView 分别渲染 myChannels 与 subscribedChannels 两段（sectionHeader channel.section.mine / channel.section.subscribed）；ChannelStore.apply 按 owner.isCreator 与 isSubscription 分流；测试 testLoadSplitsChannelsByOwner。 |
| A6 | passed | brief.md | 列表另有「发现更多」段，数据来自 `GET /api/v1/channels?discover=1`，只列出 `subscribed == false` 且 `owner != "creator"` 的项。 | ChannelStore.fetchAll(discover:true) 只在发现段使用，结果经 canSubscribe 过滤（published && !creator && !subscribed）；测试 testDiscoverListSendsDiscoverFlag 断言 query 带 discover=1，testDefaultListOmitsDiscoverFlag 断言默认列表不带。 |
| A7 | passed | brief.md | 点「订阅」调用 `POST /api/v1/channels/:id/subscribe`，请求体带当前选择颜色；成功后该频道出现在「订阅的频道」，并从「发现更多」移除。 | APIClient.subscribe 发 POST /api/v1/channels/:id/subscribe，body 仅 {color}；测试 testSubscribeSendsPaletteColorValue 断言 body 键为 [color] 且值为色板色值，testSubscribeMovesChannelToSubscribedSegment 断言从 discover 移入订阅段。 |
| A8 | passed | brief.md | 重复订阅按幂等处理：`200` 与 `201` 都视为成功，不出现重复卡片。 | 订阅成功不区分 200/201：send() 只判断 2xx；测试 testRepeatedSubscribeIsIdempotentForClient（200）与 testSubscribeMovesChannelToSubscribedSegment（201）各覆盖一次，重复订阅后订阅段仅一条。 |
| A9 | passed | brief.md | 订阅频道卡片显示订阅色点与只读标记，不显示 `enabled` 开关、编辑与删除入口。 | SubscribedChannelCard 不含 ChannelToggle、删除与编辑入口（grep 计数为 0），显示订阅色点与 channel.kind.subscribed 徽标；点击进入只读详情而非编辑页。 |
| A10 | passed | brief.md | 点击订阅频道进入只读详情；该页只提供改颜色、fork、取消订阅三项动作。 | 新增 SubscribedChannelDetail：只读展示方向/口吻/时间表/连接器，底部仅改颜色、fork、取消订阅三个动作，无保存/删除/运行入口；测试与规格逐条对应。 |
| A11 | passed | brief.md | 改订阅颜色调用 `PATCH /api/v1/channels/:id/subscribe`，只提交 `color`；成功后列表与详情立即使用新颜色。 | APIClient.updateSubscriptionColor 用 PATCH /api/v1/channels/:id/subscribe，body 仅 {color}；测试 testUpdateSubscriptionColorPatchesOnlyColor 断言方法/路径/body 键，testUpdateSubscriptionColorUsesPatchAndRefreshesChannel 断言列表立即换色。 |
| A12 | passed | brief.md | 取消订阅调用 `DELETE /api/v1/channels/:id/subscribe`；成功后该频道从「订阅的频道」消失，其日报也不再出现在日报流与筛选中。 | APIClient.unsubscribe 用 DELETE /api/v1/channels/:id/subscribe；ChannelStore.unsubscribe 立即从 subscribedChannels 移除并重取 discover，未订阅 404 按已取消处理；ChannelListView 的 onUnsubscribed 调 env.feed.forgetChannel 清掉本地日报流与筛选选中项；测试 testUnsubscribeRemovesChannelAndReloadsDiscoverable、testUnsubscribeTreatsNotFoundAsAlreadyRemoved、testForgetChannelClearsBriefsAndFilter。 |
| A13 | passed | brief.md | fork 调用 `POST /api/v1/channels/:id/fork`；成功后新频道以 `owner == "creator"`、`published == false` 出现在「我的频道」，原订阅消失。 | APIClient.forkChannel 发 POST /api/v1/channels/:id/fork；ChannelStore.fork 移除原订阅并把我创建的频道插入 myChannels 首位；界面二次确认后按原名 fork 再进编辑页；测试 testForkAddsOwnChannelAndDropsSubscription 断言 owner.isCreator、published==false、原订阅消失，testForkSendsForkMethodAndPath 断言方法/路径。 |
| A14 | passed | brief.md | 订阅自己创建的频道返回 `409 own_channel`；订阅未公开频道返回 `403 not_published`。两者都以归一化文案提示，不崩溃、不产生幽灵条目。 | ErrorEnvelope.normalized 把 own_channel 映射为 .ownChannel(message)、not_published 映射为 .notPublished(message)；ChannelStore.subscribe 失败只设 discoverError 且不插入任何条目；测试 testSubscribeOwnChannelSurfacesOwnChannelError 与 testSubscribeUnpublishedChannelSurfacesNotPublishedError 断言错误值与列表未被污染。 |
| A15 | passed | brief.md | 订阅者对频道调用 `PATCH` / 触发运行返回的 `403 subscriber_read_only` 被归一化为「订阅频道只读，可 fork 后修改」，界面不会先提供必然失败的按钮。 | subscriber_read_only 映射为 .subscriberReadOnly，messageKey 为「订阅频道只读，可 fork 后修改」；订阅卡与只读详情均不渲染 PATCH/运行/删除入口，故界面不会先给出必然失败的按钮。 |
| A16 | passed | brief.md | 遗留调用命中已下线端点时的 `404 presets_removed` 归一化为「旧接口已停用」，与普通 `not_found` 区分。 | APIErrorCode 新增 presetsRemoved 并映射为 APIError.removed，messageKey 为 error.presetsRemoved（「旧接口已停用」），与 .notFound 是不同的 case；测试 testSubscriptionErrorCodesAreDistinct 显式断言 presets_removed != not_found，testEnvelopeMapsNewCodesToAPIError 覆盖四种新码。 |
| A17 | passed | brief.md | 订阅色为空字符串时按「未设置」处理：显示本地色板颜色（或按 `channelId` 稳定回退色），不显示空色点。 | Channel.effectiveSubscriptionColor 把空串/纯空白视为 nil；ChannelColorStore.displayIndex 依次取服务端订阅色→本地色板→按 id 稳定色；测试 testSubscriptionColorIgnoresEmptyString、testDisplayIndexFallsBackWhenSubscriptionColorMissing、testPaletteHexValuesMatchColorOrder 覆盖。 |
| A18 | passed | brief.md | 「我的频道」内 `published == false` 的频道正常显示并可以编辑；界面不提供公开开关。 | Channel.canEdit 只看 owner，与 published 无关；三段列表把我的频道全部列入并保留开关与编辑入口，界面无 published 开关；测试 testPrivateOwnChannelRemainsEditable 断言 published==false 时 canEdit 为 true 且仍可查到该频道。 |
| A19 | passed | brief.md | 新建频道成功后进入「我的频道」；创建流程不再出现「从模板新建」入口。 | ChannelListView 工具栏 + 直接打开新建页，菜单中的「从模板新建」已随 PresetPicker 删除；grep 全仓无 fromPreset/PresetPicker 残留；ChannelStore.create 成功后 replace(created) 即以 creator 身份进入我的频道；UI 测试改为断言进入新建页。 |
| A20 | passed | brief.md | 订阅频道的日报与创建者读到同一份：日报流、日报详情、频道筛选里都按原 `channelId` 呈现。 | 频道、日报都按 channelId 关联；BriefFeedStore.loadAllChannels 取消了 kind 过滤，订阅频道与其日报按原 channelId 进入 channelsByID 与筛选列表；日报详情与列表均使用 brief.channelID。 |
| A21 | passed | brief.md | 中英文键集完全对齐，界面无硬编码文案；`PresetPicker` 删除后无残留引用与未使用键。 | 脚本比对两份 Localizable.strings：各 200 条，对称差为空；代码引用的 L10n 键全部存在；PresetPicker 删除后无残留引用，fromPreset/empty 三个预设专用键同时删除，未新增死键（剩余未用键为改动前既有）。 |
| A22 | passed | brief.md | 单元测试覆盖：五个新字段解码、可写性三判定、订阅/改色/取消/fork 的路径与请求方法、四个新错误码归一化、空字符串订阅色回退；`xcodegen generate` + `xcodebuild test` 通过。 | GitHub Actions run 45016466235（commit d834dd9，PR #2）：iOS Unit Tests 执行 165 个测试 0 失败并输出 ** TEST SUCCEEDED **（其中 ChannelSubscriptionTests 22 个全通过）；iOS SwiftUI Device IPA 任务成功归档并产出 IPA；Android Compose APK 的 assembleDebug 成功；iOS Visual Preview 成功。 覆盖了 A22 要求的可写性判定、四条订阅动作的路径与方法、四个新错误码归一化、空字符串订阅色回退；xcodegen generate 与 xcodebuild test 已实际执行并通过。 |

## 检查

| Agent 报告的检查 | 结果 | 执行与证据 |
| --- | --- | --- |
| swift-syntax-parse | passed | tree-sitter-swift 解析 37 个 .swift：36 无错；DisplayTime.swift:39 为解析器文法缺口且本次未改。 |
| localization-parity | passed | zh-Hans 与 en 各 201 条且键集一致；代码引用键全部存在；IPA 内本地化亦为 201 条。 |
| ios-unit-tests | passed | CI run 45016466235：Executed 165 tests, with 0 failures；** TEST SUCCEEDED **；ChannelSubscriptionTests 22 个全通过。 |
| ios-device-archive | passed | 同一 run 的 iOS SwiftUI Device IPA 任务成功，产出 ReachNews.ipa（787,959 字节 artifact），已下载并核对含本轮新符号。 |
| android-assembleDebug | passed | 同一 run 的 Android Compose APK 任务成功；android/** 未改动。 |
| ios-visual-preview | passed | 同一 run 的 iOS Visual Preview 任务成功。 |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- swift-syntax-parse: passed — 用 tree-sitter-swift 解析 ReachNews/、ReachNewsTests/、ReachNewsUITests/ 共 37 个 .swift 文件：36 个无语法错误；唯一报错 DisplayTime.swift:39 是 nonisolated(unsafe) 语法在 tree-sitter-swift 0.7.1 文法中的已知缺口（该行本次未改动，git diff 可证），非本次回归。
- localization-parity: passed — 脚本比对 zh-Hans 与 en 两份 Localizable.strings：键集完全一致（各 200 条，对称差为空）；代码中引用的 L10n 键全部存在；新错误码 messageKey 的 16 条 error.* 键在两种语言中都存在。
- preset-removal-audit: passed — grep 全仓（ReachNews/、ReachNewsTests/、ReachNewsUITests/）确认无 presets()、instantiatePreset、ChannelPreset、ChannelKind.preset、isUserVisible、PresetPicker 残留引用；Endpoint 中不存在 /api/v1/presets 路径。
- channel-api-audit: passed — 静态核对 Channel 模型字段顺序与 ChannelDTO.toDomain() 实参顺序一致；ChannelListView/ChannelEditView/ChannelCreateSheet/SubscribedChannelDetail 引用的 ChannelStore 成员全部存在；Channel 派生属性被视图引用的成员全部存在。
- ios-unit-tests: not-run — 本机为 Linux，无 swift/xcodebuild 工具链（which swift、which xcodebuild 均不存在），无法执行 xcodegen generate 与 xcodebuild test。证据须由 GitHub Actions 的 iOS 任务提供，此处如实记为未运行。
- android-assembleDebug: not-run — 本机无 Android/Gradle 工具链，且本轮未改动 android/**（git status 无该目录条目）。CI 的 assembleDebug 结果须以 CI 为准。
- 已知限制: 本机没有 Swift/Xcode 工具链，未能执行 xcodegen generate 与 xcodebuild test；编译与测试结论只能由 CI 的 iOS 任务给出，当前尚无该证据。
- 已知限制: 未对生产环境消费端做真机/模拟器实测；订阅、改色、fork、取消订阅四条动作只有固定响应替身的单元测试覆盖。
- 已知限制: 订阅预览色在「发现更多」列表按 channelId 稳定色显示，实际订阅时用的是当前建议色，两者可能不同（订阅成功后即以服务端返回色为准）。

## 阻塞项

- **user**: Verification passed; user acceptance is required before Archive. — next: `await-user`

## 风险与跳过的工作

- 四条订阅动作只经固定响应替身的单元测试与 CI 构建验证，未在生产环境做真机实测。
- 订阅预览色用按 channelId 的稳定色，订阅成功后以服务端返回色为准，两者在极端情况下可能不同（已记录为已知限制）。
- 产出的 IPA 为未签名包（CI 使用 CODE_SIGNING_ALLOWED=NO），需要自行签名后才能装到真机。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | blocked | A22 | A1–A21 共 21 项按当前工作区代码逐项核对通过；A22 中与订阅相关的断言均有对应测试，但该条末尾要求「xcodegen generate + xcodebuild test 通过」，本机无 Swift/Xcode 工具链、也无 CI 运行记录，无法取得该证据，因此整体结论记为 blocked 而非 pass。需在 CI 的 iOS 任务上实际跑通后再判定 A22。 | 2026-11-22T04:28:24.603Z |
| 1 | 1 | 1 | recovery | — | A22 缺失的外部证据已取得：GitHub Actions run 45016466235（commit d834dd9）四个任务全部成功——iOS Unit Tests 执行 165 个测试 0 失败并 TEST SUCCEEDED（含 22 个 ChannelSubscriptionTests 全通过），iOS SwiftUI Device IPA 归档成功并产出 IPA，Android assembleDebug 成功，iOS Visual Preview 成功。A22 要求的 xcodegen generate + xcodebuild test 已实际执行通过，其余 21 项结论不变。 | 2026-11-22T11:29:14.551Z |
| 1 | 1 | 2 | pass | — | 22 项全部通过。A1–A21 以代码位置与 CI 实际通过的测试为依据；A22 此前唯一缺口是真实构建与测试证据，现由 CI run 45016466235 补齐：GitHub Actions run 45016466235（commit d834dd9，PR #2）：iOS Unit Tests 执行 165 个测试 0 失败并输出 ** TEST SUCCEEDED **（其中 ChannelSubscriptionTests 22 个全通过）；iOS SwiftUI Device IPA 任务成功归档并产出 IPA；Android Compose APK 的 assembleDebug 成功；iOS Visual Preview 成功。 | 2026-11-22T11:30:28.760Z |



## 结论

22 项全部通过。A1–A21 以代码位置与 CI 实际通过的测试为依据；A22 此前唯一缺口是真实构建与测试证据，现由 CI run 45016466235 补齐：GitHub Actions run 45016466235（commit d834dd9，PR #2）：iOS Unit Tests 执行 165 个测试 0 失败并输出 ** TEST SUCCEEDED **（其中 ChannelSubscriptionTests 22 个全通过）；iOS SwiftUI Device IPA 任务成功归档并产出 IPA；Android Compose APK 的 assembleDebug 成功；iOS Visual Preview 成功。
