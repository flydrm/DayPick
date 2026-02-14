# DayPick 指标事件字典（content-free / local_events）

**Date:** 2026-01-24  
**Scope:** Beta / Today v2 指标门禁（KPI-1/2/3/4/5 + Inbox Health）  
**Single Source of Truth:** 本文为实现与回归测试的唯一口径；PRD/Epics/Architecture 相关描述以本文为准（如有冲突，以本文更新为准并回填其它文档）。

## 0. 原则（必须遵守）

- **content-free**：`local_events` 绝不记录任何内容字段（标题/正文/AI prompt/AI response/日历事件标题等）。
- **强白名单**：每个 `event_name` 必须有明确的 `meta_json` allowlist；unknown key 一律拒写。
- **强 banlist**：任何命中敏感 key（如 `title`, `body`, `content`, `description`, `prompt`, `response`, `api_key`, `apikey`, `apiKey`）必须拒写并触发测试失败。
- **强 caps**：限制 `meta_json` 总大小、单个 string 长度、数组长度，防止“把内容塞进事件”。
- **确定性归因**：每条事件必须自动携带 `app_version` 与 `feature_flags` 快照（确定性序列化）。
- **snake_case**：事件名与字段名统一 snake_case；时间统一 `*_utc_ms`。

## 1. local_events 事件 Envelope（固定字段）

`local_events` 中每条事件必须具备以下固定字段（envelope）：

- `id`：string（ULID/UUID）
- `event_name`：string（snake_case）
- `occurred_at_utc_ms`：int
- `app_version`：string
- `feature_flags`：string（确定性序列化后的快照；实现可用 list 排序序列化）
- `meta_json`：object（仅允许“扁平 key-value”，见下一节）

## 2. meta_json 约束（强制）

`meta_json` 仅允许扁平结构（禁止嵌套 object/array-of-object）。值类型仅允许：

- string / int / bool / double / string[]

所有事件必须通过：

- `meta_allowlist_by_event_name`：事件级字段白名单
- `meta_banlist_keys`：全局敏感 key 黑名单
- `meta_caps`：大小与长度上限

## 3. KPI 与事件映射（总览）

- **KPI-1（3 秒清晰）**：`today_first_interactive` → `today_clarity_result`（成功=进入有效执行态；失败=首个失败原因分桶）
- **KPI-2（TTFA）**：`today_first_interactive` → `primary_action_invoked.elapsed_ms`
- **KPI-3（主线旅程 a→c→d→e）**：`today_opened`（a） + `primary_action_invoked(action=open_inbox|capture_submit|open_today_plan)`（c/d/e）
- **KPI-4（睡前回顾触达/完成）**：`journal_opened` / `journal_completed`
- **KPI-5（R7）**：按天 `app_launch_started`（或等价 session start）计算活跃日与第 7 日留存
- **Inbox Health**：
  - 日末待处理数量：`inbox_daily_snapshot(inbox_pending_count)`
  - 当天新增/处理/归类：`inbox_item_created` / `inbox_item_processed`

## 4. 事件定义（必须实现）

下面每个事件都定义了触发时机与允许的 `meta_json` 字段（仅列允许字段；除此之外一律拒写）。

### 4.1 App / Session

#### `app_launch_started`

- **When**：应用进入可交互主流程的启动开始时刻（可按冷启动/热启动区分）
- **Used by**：KPI-5
- **meta_json allowlist**
  - `cold_start`：bool
  - `source`：string（`icon|deep_link|notification|other`）

### 4.2 Today / 3 秒清晰

#### `today_opened`

- **When**：用户进入 Today tab 且 Today 页面成为当前前台页面（可重复）
- **Used by**：KPI-3（a）
- **meta_json allowlist**
  - `source`：string（`tab|redirect|deep_link|other`）

#### `today_first_interactive`

- **When**：Today 首屏达到“可交互”时刻（TTI/TTFI）——作为 KPI-1/TTFA 的统一计时起点
- **Used by**：KPI-1、KPI-2
- **meta_json allowlist**
  - `elapsed_ms`：int（从 `app_launch_started` 到此刻的耗时；若不可得可省略）
  - `segment`：string（`returning|new`）

#### `primary_action_invoked`

- **When**：用户触发首个关键动作（用于 TTFA）；每个 Today 会话内只记录第一次
- **Used by**：KPI-2、KPI-3（c/d/e）
- **meta_json allowlist**
  - `action`：string（`start_focus|capture_submit|open_inbox|open_today_plan`）
  - `elapsed_ms`：int（从 `today_first_interactive` 到该动作的耗时）

#### `effective_execution_state_entered`

- **When**：用户进入“有效执行态”（用于 KPI-1 成功判定；不得用按钮点击替代）
- **Used by**：KPI-1
- **meta_json allowlist**
  - `source`：string（`today_primary_cta|top3_item|today_plan|other`）
  - `kind`：string（`focus|other`）

#### `today_clarity_result`

- **When**：在 `today_first_interactive` 后的 3 秒窗口内，首次出现“成功（进入有效执行态）”或“失败原因”或“超时”时写入；同一 Today 会话只允许写一次
- **Used by**：KPI-1
- **meta_json allowlist**
  - `result`：string（`ok|fail`）
  - `elapsed_ms`：int（从 `today_first_interactive` 到结果的耗时；成功应 ≤3000）
  - `failure_bucket`：string（`scroll|fullscreen|tab_switch|leave_today|timeout|other`；`result=ok` 时可省略）
  - `failure_flags`：string[]（可选，多原因诊断；首因仍以 `failure_bucket` 为准）

#### `fullscreen_opened`

- **When**：在 Today 旅程中打开全屏页面/全屏弹层（用于 failure_bucket 与 fullscreen≈0 门禁）
- **meta_json allowlist**
  - `screen`：string
  - `reason`：string（`detail|settings|longform_editor|other`）

#### `tab_switched`

- **When**：用户在 3 秒窗口内切换底部 Tab（用于 failure_bucket=tab_switch）
- **meta_json allowlist**
  - `from_tab`：string（`ai|notes|today|tasks|focus|other`）
  - `to_tab`：string（同上）

#### `today_left`

- **When**：从 Today 导航到其它页面且离开 Today（用于 failure_bucket=leave_today）
- **meta_json allowlist**
  - `destination`：string（`route:<name>` 或 `screen:<name>`）

#### `today_scrolled`

- **When**：Today 首屏滚动超过“轻微抖动阈值”（用于 failure_bucket=scroll）
- **meta_json allowlist**
  - `delta_px`：int

#### `calendar_permission_path`

- **When**：用户在 Today 首屏的“时间约束（系统日历）”路径上做出关键选择/结果变化（例如：点击连接/跳过、权限请求结果、读取失败、去设置）
- **Used by**：权限路径分布（信任/可跳过门禁）
- **meta_json allowlist**
  - `action`：string（`connect|skip|open_settings|permission_result|read`）
  - `result`：string（`granted|denied|unknown|restricted|not_supported|error`；无结果时可省略）
  - `state`：string（`unknown|granted|denied|restricted|not_supported`）

### 4.3 Capture / Inbox / Health

#### `capture_submitted`

- **When**：Capture Bar 成功提交创建条目（与 `primary_action_invoked(action=capture_submit)` 可共存）
- **Used by**：KPI-3（d）、Inbox Health（新增）
- **meta_json allowlist**
  - `entry_kind`：string（`task|note|memo|other`）
  - `result`：string（`ok|error`）

#### `open_inbox`

- **When**：用户进入 Inbox/待处理入口
- **Used by**：KPI-3（c）
- **meta_json allowlist**
  - `source`：string（`today|tab|deeplink|other`）

#### `inbox_item_created`

- **When**：产生新的待处理条目（进入 inbox/triage 状态）
- **Used by**：Inbox Health（新增）
- **meta_json allowlist**
  - `item_kind`：string（`task|note|memo|other`）
  - `source`：string（`capture|import|ai|other`）

#### `inbox_item_processed`

- **When**：待处理条目被处理/归类/加入今天/归档等（从 inbox/triage 状态迁移）
- **Used by**：Inbox Health（处理/归类）
- **meta_json allowlist**
  - `item_kind`：string（`task|note|memo|other`）
  - `action`：string（`classify|defer|archive|add_to_today|delete|other`）
  - `batch`：bool

#### `inbox_daily_snapshot`

- **When**：KPI 引擎对某天执行日聚合时写入（建议在“日切”或应用首次启动时补算前一天）
- **Used by**：Inbox Health（日末待处理数量）
- **meta_json allowlist**
  - `day_key`：string（`yyyy-mm-dd`）
  - `inbox_pending_count`：int

#### `today_plan_opened`

- **When**：用户进入 Today Plan
- **Used by**：KPI-3（e）
- **meta_json allowlist**
  - `source`：string（`today|deeplink|other`）

### 4.4 Journal / Review

#### `journal_opened`

- **When**：进入当天 JournalEntry 编辑界面且页面可交互
- **Used by**：KPI-4（触达）
- **meta_json allowlist**
  - `day_key`：string（`yyyy-mm-dd`）
  - `source`：string（`today|focus_wrapup|tab|deeplink|other`）

#### `journal_completed`

- **When**：用户显式完成/保存当天复盘（完成判定需产品定义；必须是用户操作而非自动保存）
- **Used by**：KPI-4（完成）
- **meta_json allowlist**
  - `day_key`：string（`yyyy-mm-dd`）
  - `answered_prompts_count`：int
  - `refs_count`：int
  - `has_text`：bool（仅允许 true/false；不得记录正文）

### 4.5 Export / Backup / Restore / Security

#### `export_started` / `export_completed`

- **When**：用户发起明文导出（JSON/Markdown）或导出完成
- **meta_json allowlist**
  - `format`：string（`json|markdown`）
  - `result`：string（`ok|error`）

#### `backup_created`

- **When**：用户生成备份包（加密/明文均需区分；**明文备份不得包含密钥**）
- **meta_json allowlist**
  - `includes_secrets`：bool
  - `result`：string（`ok|error`）

#### `restore_started` / `restore_completed`

- **When**：用户开始恢复/恢复完成（包含失败）
- **meta_json allowlist**
  - `includes_secrets`：bool
  - `result`：string（`ok|error|cancelled`）

#### `safe_mode_entered`

- **When**：DB key 缺失/不可读/解密失败导致进入“安全模式”
- **meta_json allowlist**
  - `reason`：string（`db_key_missing|decrypt_failed|migration_failed|other`）

## 5. 去重规则（必须）

- `primary_action_invoked`：同一 Today 会话仅记录一次（第一次关键动作）。
- `effective_execution_state_entered`：同一 Today 会话仅记录第一次进入。
- `today_clarity_result`：同一 Today 会话仅记录一次（先到者为准：成功/失败/超时）。

> “Today 会话”建议以 `today_first_interactive` 为起点，到离开 Today 或应用进入后台/超时结束；实现需可测试化并保持一致。

## 6. 示例（JSONL，content-free）

```json
{"id":"01J...","event_name":"today_first_interactive","occurred_at_utc_ms":1766236800123,"app_version":"1.2.3","feature_flags":"today_v2=on;capture_bar=on","meta_json":{"elapsed_ms":820,"segment":"returning"}}
{"id":"01J...","event_name":"primary_action_invoked","occurred_at_utc_ms":1766236801023,"app_version":"1.2.3","feature_flags":"today_v2=on;capture_bar=on","meta_json":{"action":"start_focus","elapsed_ms":900}}
{"id":"01J...","event_name":"today_clarity_result","occurred_at_utc_ms":1766236801023,"app_version":"1.2.3","feature_flags":"today_v2=on;capture_bar=on","meta_json":{"result":"ok","elapsed_ms":900}}
```
