# 后端 API 变更说明（2026-11-21）

对应你的 `backend-api-requests.md`。**清单里 9 条全部处理完毕**，另修 4 条你未列入但实际存在的缺陷。

验证依据：后端测试套件 82/82 通过；生产环境（`reachapi.niuma.art`）实测；生产数据副本逐端点打真实请求。

---

## 一、你清单里的 9 条：全部已修

### P0-1 `/cursor` 泄漏已删频道日报

`cursor.briefs` 与 `cursor.channels` 都已补 `deleted_at` 过滤。

```json
{ "briefs": [ { "id": "brf_…", "channelId": "chn_…", "title": "…", "createdAt": "…" } ],
  "channels": [ { "id": "chn_…", "name": "…", "enabled": true, "updatedAt": "…" } ] }
```

注意顺带改了字段名：`channel_id`→`channelId`、`created_at`→`createdAt`、`updated_at`→`updatedAt`，`enabled` 从 `1/0` 改成 `true/false`。**可以删掉 `FlexibleBool` 和 snake_case 映射了。**

### P0-2 预设参与调度 → 孤儿日报

采纳你的方案 A，但有调整（产品补充要求）：

- **预设不再参与调度**，`dueChannels` 加 `kind != 'preset'`
- `PATCH /channels/:id` 与 `POST /channels/:id/run` 对预设返回 `409 preset_read_only`
- **但用户新建频道时要能看到预设作模板**，所以新增了两个端点：

```
GET  /api/v1/presets
→ 200 { items: [ { id, name, prompt, tone, schedule, connectorIds } ], nextCursor: null }

POST /api/v1/presets/:id/instantiate
→ 201 返回新建的 kind='channel' 频道（复制预设的 prompt/tone/schedule/connectorIds）
```

**前端动作**：日报页和频道列表可以放心渲染，不会再有找不到频道的孤儿行；新建频道流程可以接入预设列表。

### P1-3 日报级与运行级端点未过滤软删除

抽了 `liveBrief()` / `liveRun()` 两个帮助函数统一过滤。覆盖：

| 端点 | 已删频道 |
|---|---|
| `GET /briefs/:id` | 404 |
| `GET /briefs/:id/items/:itemId` | 404 |
| `GET\|POST /briefs/:id/ask` | 404 |
| `POST /briefs/:id/regenerate` | 404 |
| `GET /runs/:id` | 404 |
| `POST /runs/:id/retry` | 404 |
| `POST /runs/:id/resume` | 404 |
| `POST /follows { sourceBriefId }` | 404 |

`publishBrief` 也拒绝向已删频道发布，从源头杜绝孤儿日报。

### P1-4 缺少全量日报端点

```
GET /api/v1/briefs?cursor=&limit=
→ 200 { items: [...], nextCursor }
```

- 跨频道按 `created_at DESC, id DESC` 排序（**已采纳你的 id tie-breaker 建议**）
- 每条额外含 `channelName`、`channelKind`，**不用再回查频道**
- 你指出的 `test/rules.test.mjs:151` 同毫秒打平问题，已在这条排序里规避

### P1-5 负 cursor 从尾部返回数据

`cursorPage` 已改为 `Math.max(0, offset)`，且 `nextCursor` 用 clamp 后的值。

实测：`cursor=-5&limit=2` 现在返回索引 0、1（而非你测到的 35、36），`nextCursor` 永不为负。补了完整真值表单测。

### P2-6 `/ask` 不返回引用了哪些素材

```json
POST /api/v1/briefs/:id/ask
→ 201 {
    "message": "...",
    "answer": "已基于「…」的归档摘要记录问题：…",
    "citedItemIds": ["itm_…", "itm_…"],
    "deterministic": true
  }
```

`citedItemIds` 从该 brief 的 `sections[].items[].itemIds` 汇总去重，就是本期素材。`deterministic: true` 明确标注这是确定性应答（未接 LLM）。

**前端动作**：引用卡可以落地了。

### P2-7 无法枚举连接器，不能创建频道

```
GET /api/v1/connectors
→ 200 { items: [ { id, name, kind } ], nextCursor: null }
```

**只返回 id/name/kind，绝不返回 config**——按你说的，`connector-catalog.mjs` 的 config 含 headers 有凭证泄漏风险。

`POST /api/v1/follows` 现在校验 `connectorIds` 必须落在可用集合内，否则：

```json
400 { "error": { "code": "invalid_connector", "message": "Unknown or disabled connector: xxx" } }
```

**前端动作**：`+` 入口可以解开了，建频道时先 `GET /connectors` 让用户选。

### P2-8 字段风格不一致

`/cursor` 与 `/ask` 历史统一 `camelCase` + 布尔，与主体端点一致。`/ask` 历史条目现在是 `{ id, role, message, createdAt }`。

### P2-9 `retry` 返回 `queued: {}`

根因是 `drain()` 未 `await`，Promise 被序列化。已去掉该字段（它也不具业务含义）。现在 `POST /runs/:id/retry` 返回 `202 { runId, state: "queued" }`。

---

## 二、你标注「既有缺陷、非本次引入」的 3 条：也修了

### 非法 JSON 返回 500 → 400

```
POST /api/v1/login  -d '{ this is not json'
→ 400 { "error": { "code": "invalid_input", "message": "invalid JSON body" } }
```

所有 JSON 端点一致。此前 `/api/v1/login` 因为解析在 try 块外，会漏成 500。

### 限流补 `Retry-After`

```
HTTP 429
retry-after: 300

{ "error": { "code": "too_many_attempts", "message": "…" }, "retryAfterSeconds": 300 }
```

数值是 5 分钟窗口的剩余秒数。**按你现有的「429 不自动重试」策略继续即可**，现在有明确时间可以展示倒计时。

### 同一频道可并发多次触发

`POST /channels/:id/run` 与管理页触发都在**同一个写事务**（`BEGIN IMMEDIATE`）内完成「检查活跃运行 + 入队」，并发测试验证 10 次并发只成功 1 次。已有未结束运行返回 `409 busy`。

之前是路由层先查再调 `start()`，两步非原子；现在收进 `runEngine.start()` 内部，靠数据库写锁互斥。

---

## 三、额外发现的缺陷：时区配置从未生效

这不在你的清单里，但属于同类问题——**配置了不生效**。

`scheduleKey(date, timeZone = "Asia/Shanghai")` 本身支持传入时区，但所有调用方都只用默认值；管理页三处 `Asia/Shanghai` 是硬编码文本；`setting()` 只能读数字，时区字符串存不进去。

**现在：**

- 设置页可以改时区（IANA 名，如 `Asia/Tokyo`），**校验合法性**，非法则拒绝并保留上一个值
- 调度守护进程**每轮**从数据库读取，改完下一轮即生效，不用重启
- 管理页时区显示改为当前配置值

实测：同一时刻 `Asia/Shanghai` 是 `00:20`、`Asia/Tokyo` 是 `01:20`，调度按配置判断。

**对前端**：如果你有页面显示时区，建议从设置读取而不是写死。手机端 API 暂未暴露时区端点——需要的话告诉我。

---

## 四、对前端的净影响

**可以删除的防御代码**：

1. `FlexibleBool`（`enabled` 已是布尔）
2. `/cursor` 的 snake_case 映射
3. 负 cursor 的防御性丢弃（服务端已 clamp，但保留也无害）
4. preset 的剔除逻辑仍需保留（预设不进频道列表），但不再需要担心孤儿日报

**需要适配的**：

1. `/cursor` 字段名变化（`channel_id` → `channelId` 等）
2. `/ask` 历史条目字段名变化
3. 新增流程：`GET /connectors` 选连接器 → `POST /follows` 建频道
4. 新增流程：`GET /presets` 选模板 → `POST /presets/:id/instantiate` 实例化
5. `citedItemIds` 可渲染引用卡

**破坏性变更：无。** 除字段名规范化外，没有删除或改名已有字段的结构；`sections` 只加了可选字段。

---

## 五、仍未处理的（下次再说）

1. 手机端不能直接 `POST /channels` / `DELETE /channels/:id`（靠 `/follows` 与 `/presets/:id/instantiate` 间接达到）
2. `Ask` 不接 LLM（已明确标注 `deterministic: true`）
3. 「活跃频道至少一个连接器」未强制校验，建频道时请自选
4. `PUT` 等未实现方法返回 404 而非 405

完整契约见后端仓库 `API.md`（已同步更新，含「已修复」清单）。
