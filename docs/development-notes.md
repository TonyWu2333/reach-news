# 开发踩坑与工作流记录

这份文档记录在 Reach News 客户端开发中**真实踩过**的坑，以及验证过的做法。目的是让新会话或新成员不必重复发现同一件事。

记录原则：只写亲身验证过的事实与可复用的判断依据。任务进展、一次性命令输出、未验证的猜测不写入。

---

## 一、环境与工具链

### 本机是 Linux，绝不能声称跑过 iOS 构建

这台开发机没有 `xcodebuild`、`swift`、`xcodegen`、`xcrun`。任何 iOS 编译、单元测试、IPA 产出**都只能由 GitHub Actions 提供**。

自查命令：

```bash
for t in xcodebuild swift xcodegen xcrun; do printf "%-10s " "$t"; command -v $t || echo "缺失"; done
```

**必须遵守**：不能用「本机跑不了」当作通过，也不能把静态检查说成「已编译验证」。CI 结果出来之前，验收项里与构建/测试相关的条目应记为 `not-run` 或 `blocked`，而不是 `passed`。

### 可用的本地静态检查

虽然不能编译，但能拦住一类问题（拼写、缺失成员、语法笔误）：

- 用 `tree-sitter-swift`（WASM 版）解析全部 `.swift`，报出 `ERROR` 节点。装法：`npm i web-tree-sitter@0.25.6 tree-sitter-wasms`。
- **注意它的误报**：它不支持 Swift 的 raw string（`#"..."#`），也不认识 `nonisolated(unsafe)`。遇到 `DisplayTime.swift:39` 那类报错，先确认该行本次有没有改过，不要当成自己引入的回归。
- 定位单个文件的真实错误时，**单独解析那一个文件**，比批量脚本准确（批量脚本会因多行字符串里的 `##`、反引号误报）。

### 静态检查抓不到什么

这轮里被 CI 抓出、而本地静态检查完全没发现的真实错误，供参考这类检查的边界：

| 问题 | 静态检查为何漏掉 |
|---|---|
| `Endpoint.channels` 加了参数但测试没改 | 语法合法，只是调用点过时 |
| `View` 结构体里声明了名为 `body` 的存储属性 | 语法合法，语义非法（与 `View.body` 冲突） |
| `AttributedString` 不是 `Collection`，`first`/`last` 用不了 | 语法合法，API 不存在 |
| `CharacterView` 的索引与 `AttributedString.Index` 不通用 | 语法合法，类型不匹配 |
| 测试替身无锁数组在并发下丢写 | 语法合法，运行期才暴露 |

结论：**静态检查只能当第一道筛子，不能替代 CI**。

---

## 二、凭证与权限

### GitHub 推送

仓库远端是 `https://github.com/tangsong404/reach-news.git`。本机**没有**持久化的 GitHub 凭据：

- `git push` 默认报 `could not read Username for 'https://github.com'`；
- `ssh -T git@github.com` 报 `Permission denied (publickey)`；
- `~/.config/gh` 不存在，`gh` CLI 未安装。

可用的做法是临时把 token 放在 URL 里推送，**不写入 git 配置**：

```bash
git -c credential.helper= -c http.version=HTTP/1.1 \
  push "https://<user>:<token>@github.com/tangsong404/reach-news.git" HEAD:refs/heads/<branch>
```

注意事项：

- 必须带 `-c credential.helper=`，否则可能沿用全局 helper 并把凭据留存下来。
- `-c http.version=HTTP/1.1` 能减少长连接被中间网络掐断的概率（见下条）。
- **token 会出现在命令行历史与对话中**，用完应吊销并更换。

### 网络不稳定是常态，不要一次失败就放弃

与 GitHub 的连接经常间歇性失败，典型错误：

- `Empty reply from server`
- `Failed to connect to github.com port 443: Connection timed out`
- `RPC failed; curl 52`

但这些同时说明并非凭据问题：`curl https://api.github.com/` 通常仍是 `200`。**做法是重试 3–4 次、每次间隔 20–25 秒**，这轮里几乎每次都在第 2–4 次成功。不要把网络抖动误判成 token 失效。

真正确认 token 是否有效，用一次轻量 API 调用：

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $T" https://api.github.com/user
```

### 从截图里读 token 的教训

用户曾直接发来一张 token 截图。OCR/肉眼极易把形近字符搞错（`I` 与 `l`、`0` 与 `O`），第一遍转写就错了，导致全部请求返回 `401 Bad credentials`。

**可靠做法**：GitHub token 的最后 6 位是 CRC32 校验位。可以先列出所有形近字符的组合，再用 CRC32 反推唯一正确的那个，然后才拿去认证。这样一次就能定位错在哪一位，而不是盲目试。

---

## 三、CI（GitHub Actions）

### 工作流只在 push 到 main 或开 PR 时触发

`.github/workflows/build.yml` 的触发条件是 `push: [main]` 与 `pull_request`。**推到普通分支不会触发 CI**，必须开一个 PR 才会跑。

### 四个任务，各自独立失败

| 任务 | 作用 |
|---|---|
| `iOS Unit Tests` | `xcodebuild test`，只跑 `ReachNewsTests` |
| `iOS SwiftUI Device IPA` | archive 并打包成 IPA |
| `iOS Visual Preview` | 模拟器截图 |
| `Android Compose APK` | `assembleDebug` |

**重要细节**：App 能编译成功并不代表测试能编译成功——测试目标是独立编译单元。这轮多次出现「IPA 成功、Unit Tests 失败」，失败原因都是测试代码里的编译错误或断言错误。看 CI 时不要只看 IPA。

### 下载产物需要认证

artifacts API 未鉴权返回 `401 Requires authentication`，必须带 token：

```bash
curl -sL -H "Authorization: Bearer $T" \
  "https://api.github.com/repos/tangsong404/reach-news/actions/artifacts/<id>/zip"
```

产物是 zip 里套一个 `ReachNews.ipa`，解出来才是真正的包。

### 任务可能被平台中途取消

遇到过 `iOS SwiftUI Device IPA` 状态为 `cancelled`、但没有任何失败步骤的情况——是 runner 侧中断。处理方式是只重跑失败任务：

```bash
curl -s -X POST -H "Authorization: Bearer $T" \
  "https://api.github.com/repos/tangsong404/reach-news/actions/runs/<run>/rerun-failed-jobs"
```

### 排队可能很久

CI 有时排队十几分钟才启动。轮询时不要因为长时间 `queued` 就以为卡死。

---

## 四、测试

### 测试替身必须线程安全

`StubTransport.recorded` 原本是无锁的 `[Recorded]`，而 `ChannelStore.load()` 用 `async let` **并发**发两个请求。两个 `append` 同时发生会丢写，导致「看起来只发了一个请求」的偶发失败。

这类 bug 极难复现，一旦测试出现「计数对不上」且实现确实发了请求，先怀疑**记录容器本身**。解决方式是加 `NSLock` 保护，读也走锁。

### 不要对原始 URL 做子串匹配

判断「这个请求带没带 `discover=1`」时，直接 `url.query?.contains("discover=1")` 依赖参数顺序。应改用 `URLComponents` 解析 `queryItems`，按 name/value 判断。

### 时间相关的测试不能写死日期

`testThisWeekFilterExcludesOlderBriefs` 曾把「本周内」写死为某个具体日期，结果**每逢周日必挂**（按 `zh_Hans_CN` 日历，一周从周日起算，周日当天「本周」只剩当天）。

做法：样本相对 `Date()` 构造。先取 `resolvedRange(now:)` 的真实下界，再取区间中点作为「区间内」样本、下界前一天作为「区间外」样本。

### 边界条件要覆盖到「看起来一样但不是」

`body` 的「无正文」判定最初只查 `text.isEmpty`，但样本是空格 `"   "`，于是判定永不触发。**空白字符**（空格、换行、制表符）必须 trim 后再判断。

### Fixtures 要覆盖真实的状态差异

日报 `body` 需要覆盖三种互斥状态，缺一不可：

1. 有正文（含 `link` 片段）
2. `body` 为 `null`（升级前发布或模型未产出）
3. `body` 字段**缺失**（更老的响应）

第 3 种容易被忽略：JSON 里没有该键时，解码成可选类型是 `nil`，但与显式 `null` 走的是不同代码路径，必须都测。

---

## 五、iOS 开发

### 命名冲突

- **`View` 结构体里不能有名为 `body` 的存储属性**，会与 `View.body` 冲突并报 `invalid redeclaration`。输入属性应叫 `content` 之类。
- 若引入了 `Markdown` 这类模块，它的 `Text`、`Link`、`Paragraph` 与 SwiftUI 同名，会造成 `ambiguous for type lookup`。要么用 `Markdown.Text` 全限定，**要么干脆不引入该依赖**（见下条）。

### Markdown 优先用原生方案

**别再急着引第三方库**。Foundation 自带 CommonMark 解析器：

```swift
let options = AttributedString.MarkdownParsingOptions(
    interpretedSyntax: .full,
    failurePolicy: .returnPartiallyParsedIfPossible
)
let attributed = try? AttributedString(markdown: source, options: options)
```

这轮先试了 `swift-markdown`，遇到两个问题：与 SwiftUI 同名类型冲突；而且它是项目第一个 SPM 依赖，构建成本高。改用原生后依赖清零。

**关键限制**：`Text` 只渲染**行内**样式（粗体、斜体、行内代码、链接、删除线）。它**不会**因为 `presentationIntent` 自动把 `##` 放大成标题、也不会给列表加项目符号。所以必须按 `presentationIntent` 自己切块渲染。

切块要点：

- `presentationIntent.components` 是**从最外层到最内层**的链，例如列表项内文字是 `[unorderedList, listItem, paragraph]`。
- 判断列表项不能只看**最深**一层（那是 `paragraph`），要取链里第一个需要块级表现的种类。
- 有序与无序由链里是否出现 `orderedList` / `unorderedList` 决定。
- **相邻两个都是 `paragraph` 时，只看 kind 会把它们并成一块**。必须同时比较 `components.last?.identity`（类型是 `Int`，不是结构体）——`identity` 在每个块边界都会变。
- `OrderedList.startIndex` **不是 public**，外部读不到，有序列表从 1 开始编号即可。
- `AttributedString` **不是** `Collection`，`first`/`last`/`removeSubrange` 不能直接用；字符要经 `.characters` 视图取，但该视图的索引与原串索引**不通用**。为避免踩这个坑，块首尾的空白交给布局（`VStack` 间距）处理，不要手工裁剪富文本。

### 多个 `navigationDestination(item:)` 会互相覆盖

同一个 `NavigationStack` 里对**同一类型**挂两个 `navigationDestination(item:)`，后一个会覆盖前一个。改用一个路由枚举：

```swift
enum Route: Hashable { case edit(Channel), subscribed(Channel) }
```

配合 `navigationDestination(for: Route.self)`。

### `Text` 拼接无法绑定点击

`Text("a") + Text("b")` 得到的新 `Text` 无法为其中片段单独绑定点击。要可点链接必须用 `AttributedString` 的 `.link` 属性，再通过 `.environment(\.openURL, OpenURLAction { ... })` 接管跳转。

### 跨阶段产物：`sections` 退出读者界面但模型保留

订阅与正文两轮之后，读者端只展示「标题 + 描述 + 正文」。`sections` 仍在模型里解析并保留（供后台核对与将来使用），但**不进任何读者界面**，包括不出现在详情页、不作为正文脚注、不用于反推正文。

---

## 六、Comet 工作流

### 归档前必须先验收

「归档」不是随时可执行的。Native 流程要求先提交候选实现、走完 Verify、由用户接受结果，才会进入 Archive。直接说「归档」时，如果状态还在 Build 且验收项全为 pending，必须先补完验收。

### 同一目录有活跃 change 时，新 change 要用独立 worktree

CLI 会拒绝并要求：

```
Native working directory already contains active change <name>; create the new change in a separate worktree
```

用 `--isolation worktree --worktree-path <path>` 创建。

### 未归档的 change 不会更新规范 Spec

**这是个容易踩的坑**：`docs/comet/specs/ios-client/spec.md`（canonical）只在归档时更新。若上一轮 change 已验收但未归档，新 change 基于 canonical 写 Spec，**归档时会把上一轮的内容冲掉**。

做法：先归档上一轮，让它的 Spec 发布进 canonical，再基于新的 canonical 写下一轮。

### 关联已有 capability 时用 delta 或完整目标 Spec

关联到 `ios-client` 后，change 目录里可能自动生成 `specs/ios-client/delta.yaml`（空 operations）。此时直接改同目录的 `spec.md` 会被判定为「Native target has independent edits」而拒绝。

这轮验证过的处理：删除空的 `delta.yaml`，改用完整目标 Spec 模式即可继续。

### 归档时可能出现 Spec 合并冲突

两个分支若都从同一旧提交出发重写同一份 canonical Spec，合并会冲突。**不要强行合并**：本地手动取并集、删掉重复条目、跑 CI 确认后再合并 PR。

### skill 子代理可能长时间不返回

派去做独立审查的子代理有一次运行很久没有任何输出。不要盲目等待——用 `interrupt_agent` 停掉，自己逐项核对验收。

---

## 七、交付与产物

### `dist/` 里只应有正确的包

`dist/` 被 `.gitignore` 忽略。这轮一度同时存在新旧两个 IPA，**用户拿错了旧包**，导致「为什么看不到正文」的误报。

做法：`dist/ReachNews.ipa` 只保留 main 分支 CI 产出的最新包；旧包要么删除，要么明确改名带 `OLD`。切换分支后**务必重新下载**对应提交的产物，不要复用上一次的文件。

核对一个包是否含某项功能，可比对二进制里的符号或本地化键：

```bash
python3 -c "
import zipfile
z=zipfile.ZipFile('dist/ReachNews.ipa')
d=z.read('Payload/ReachNews.app/ReachNews')
print(b'MarkdownBlockBuilder' in d)"
```

### IPA 是未签名的

CI 用 `CODE_SIGNING_ALLOWED=NO`，产出的 IPA **未签名**，装真机前需自行重签（AltStore / Sideloadly 之类）。装之前先卸载旧版本，避免界面缓存残留。

### 本地化键必须两侧对齐

`zh-Hans` 与 `en` 两份 `Localizable.strings` 的键集必须完全一致，CI 里有测试专门守着。新增或删除键时**同时改两份**。改完可用脚本快速核对对称差。

---

## 八、快速上手清单

新会话开始时的最小核对：

```bash
pwd                                  # 确认在 /var/lib/dsh/reachnews-client
git log --oneline -1                 # 确认在 main 的最新提交
git status --short                   # 确认工作区干净
cat .comet/current-change.json       # 有 Comet 需求时确认 selection
for t in xcodebuild swift xcodegen; do command -v $t || echo "$t 缺失"; done
```

推送与验证的固定套路：

1. 在分支上提交
2. 用 URL 内嵌 token 推送（带 `http.version=HTTP/1.1`，失败重试）
3. **开 PR**（否则 CI 不跑）
4. 轮询 `actions/runs`，看**每个任务**的结论，别只看 IPA
5. 需要产物时用带认证的 curl 下载 artifact
6. 合并顺序：先合下游分支的 PR，再合向 main 的 PR
