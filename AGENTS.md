<comet-ambient-resume>
<!-- Managed by Comet. Edits inside this block may be replaced by comet init/update. -->
<!-- Contract: comet.resume_probe.v2 -->

## Comet Ambient Resume

在这个仓库中，开始处理需要改动或调查的任务前，如果可能存在活跃 Comet workflow，把当前用户请求传入只读探针：`comet resume-probe . --stdin --json`。

- 如果用户通过宿主明确调用任意 Comet Skill（例如 `@comet`、`/comet`、`@comet-native` 或 `/comet-hotfix`），显式调用优先于本恢复协议；不要运行 resume probe，直接进入被调用的 Skill。
- 如果用户通过宿主明确调用的是非 Comet 的 Skill 或斜杠命令，任务意图已由该调用明确：不要运行 resume probe，直接执行该 Skill。
- 如果你正在 Comet 流程内（包括正在等待用户回复你在流程中提出的问题），不要运行 resume probe；把这类回复（例如方案/选项选择）当作当前 change 的继续，直接按用户的选择推进。
- 只信任返回的 `workflow`、`skill` 和 `entrySource`；它们只由项目配置或无配置兼容回退决定。不得扫描或切换另一套 workflow。
- 如果 probe 返回 `auto_resume`，简短说明选中的 active change，并进入 `nextCommand` 指向的永久入口。不要把状态命令当作恢复入口直接推进。
- 如果 probe 返回 `ask_user`，只问一个简短问题并等待用户回复。
- `reasonCode: ambient-resume-confirmation-required` 表示发现了相关 change，但本会话尚未确认进入。展示名称和阶段，询问本次是否继续该流程；收到确认后直接加载返回的 `skill`，无需再次扫描。拒绝时按普通任务处理，保留原 change、selection、批准和阶段写入约束。
- 如果当前请求未明确调用 Comet Skill，且 probe 返回 `out_of_scope` 或 `none`，不要进入 Comet workflow。
- `out_of_scope` 或 `none` 只表示不要因为这个新请求进入 Comet workflow；它绝不表示要暂停或退出一个已在进行的 Comet 流程。
- 如果配置或状态无效且没有 `nextCommand`，停止并报告原因；不要猜测另一个 workflow。
- 不能只因为存在 active change 就把无关任务挂到该 change。Native 的未提交改动由 Native 入口检查，不由探针自动归因。
</comet-ambient-resume>

## iOS 界面约定

以下两条是长期适用的界面规则，新建或修改任何界面都按此执行，不需要用户每次重申。

### 文案克制

按苹果的交互理念，界面默认只给**标题 + 交互组件**，不写解释性小字。

- 不要为标题、字段、按钮配「说明这句话是什么意思」的辅助文案。用户能从标签和控件本身理解的部分，一律不加小字。
- 表单字段用标签加控件即可；不写「这个字段决定什么」「如何填写」之类的引导语。
- 只有以下情况允许保留文字：不可逆或有副作用操作前的二次确认说明；服务端拒绝、校验失败等**错误原因**；空态需要用户知道下一步做什么。
- 用户主动要求补充说明时，才加说明文字；主动加的文字不是默认行为。
- 同一条信息不要在多个位置重复（例如标题旁已有徽标，就不再用小字复述）。

### 不使用底部大按钮

- 不把整宽的实心或浅色大按钮固定在表单/页面底部作为主操作。
- 页面主操作放在导航栏（如右上角「保存」「完成」），或作为列表内的常规行、行尾箭头、开关、分段控件等 iOS 惯用控件。
- 破坏性操作走菜单或行内入口加二次确认，不用通栏醒目按钮铺在底部。
- 整宽按钮仅用于确有必要、且屏幕内容为单一任务的一次性确认（例如登录页提交）；页面内的常规增删改一律不用。

