# DayPick 数据掌控 UX 流程（导出 / 备份 / 恢复 / 安全模式）

**Date:** 2026-01-24  
**Scope:** Beta（local-first / SQLCipher / includes_secrets）  
**Related Contracts:** `prds/daypick-event-dictionary-2026-01-24.md`、`_bmad-output/planning-artifacts/prd.md`、`_bmad-output/planning-artifacts/architecture.md`

## 0. 目标与硬规则

- **不静默清库**：任何 DB key 缺失/不可读/解密失败/迁移失败都必须进入“安全模式”，由用户选择下一步。
- **失败可继续**：导出/备份/恢复失败不得污染现有数据；应提供 `重试` / `取消` / `返回继续使用`。
- **强提示 + 二次确认**：所有危险动作（清空/覆盖/含密钥导出）必须二次确认。
- **content-free**：导出/备份流程相关日志与事件不得包含内容字段；事件定义以事件字典为准。
- **离线可用**：除文件选择/分享外，不依赖网络；无 AI key 不阻塞数据掌控路径。

## 1. 入口与信息架构

- Settings → **Data Control（数据掌控）**
  - 明文导出（不含密钥）
  - 加密备份（不含密钥，`includes_secrets=false`）
  - 安全导出/备份（含密钥，`includes_secrets=true`，强门禁）
  - 从备份恢复
  - 清库重建（危险）
- **安全模式入口**（仅当 DB 无法安全打开时出现）：App 启动时或需要访问 DB 的关键时刻。

## 2. Flow A：安全模式（DB key 缺失/不可读/迁移失败）

### A1. 触发条件

- secure storage 丢失/不可读导致 DB key 缺失
- SQLCipher 解密失败
- brownfield 迁移失败（包含校验失败）

### A2. UI 结构（全屏允许）

- Title：`数据已锁定（安全模式）`
- Body（3 句结构）：
  1) 结论：`我们无法安全打开本地数据库。`
  2) 人话原因：`可能是设备安全存储异常、密钥丢失，或迁移失败。`
  3) 下一步：`你可以尝试恢复，或选择清库重建。`
- Optional details（折叠）：展示 `reason_code`（不含内容/密钥），用于诊断与客服支持。

### A3. CTA（从安全到危险排序）

1. Primary：`从加密备份恢复` → 进入 Flow E
2. Secondary：`重试打开`（仅重试，不写入/不覆盖）
3. Tertiary：`继续（只读安全视图）`（若可行：仅展示解释与导出帮助；不能访问 DB 时可隐藏该项）
4. Destructive：`清库重建`（二次确认，见 A4）

### A4. 清库重建（二次确认）

- Confirm dialog:
  - Title：`确认清空本地数据？`
  - Body：`此操作会删除本机所有 DayPick 数据，且无法撤销。建议先从备份恢复。`
  - Buttons：`取消` / `仍要清空`

## 3. Flow B：明文导出（不含密钥）

### B1. 入口

Settings → Data Control → `明文导出（不含密钥）`

### B2. 选择项

- Format：`JSON` / `Markdown`
- 说明文案：`导出文件不包含任何密钥（如 AI API Key）。`

### B3. 执行与结果

- Progress：Inline loading（不全屏遮罩）
- Success：Toast + `分享/保存`（系统 share sheet）
- Failure：Inline error（原因一句话）+ `重试` / `取消`

## 4. Flow C：加密备份（includes_secrets=false）

### C1. 入口

Settings → Data Control → `加密备份（不含密钥）`

### C2. Passphrase 设置（最小门禁）

- Field：`备份密码（passphrase）`
- Helper：`我们无法找回此密码；请妥善保存。`
- Confirm field：`再次输入`

### C3. 结果

- Success：展示包摘要（`schema_version`、`exported_at`、`includes_secrets=false`）+ `保存到文件`（share sheet）
- Failure：不污染现有数据；给 `重试` / `取消`

## 5. Flow D：安全导出/备份（includes_secrets=true，强门禁）

### D1. 入口

Settings → Data Control → `安全导出（含密钥）`

### D2. 强提示（必须）

- Warning card（红色语义但不制造压力墙）：
  - `该导出将包含设备上的密钥（如 AI API Key）。`
  - `请仅在你完全信任的环境中保存，并使用强密码。`
- Checkbox：`我理解此导出包含密钥，丢失可能导致风险。`（必须勾选）

### D3. Passphrase 强度门禁

- 弱 PIN（如 6 位数字）禁止：提示 `密码过弱，请使用更强的 passphrase（建议 ≥12 位，含字母与数字）。`
- 可选：显示 strength meter（仅本地计算）

### D4. 二次确认

- Confirm dialog：
  - Title：`确认创建“含密钥”加密包？`
  - Body：`仅在你需要迁移设备且理解风险时使用。`
  - Buttons：`取消` / `确认创建`

## 6. Flow E：恢复（从加密包）

### E1. 入口

- Settings → Data Control → `从备份恢复`
- 或安全模式 Primary：`从加密备份恢复`

### E2. 选择文件 + 解析摘要

- 选择文件后，展示仅结构化摘要（不展示任何内容）：
  - `schema_version`
  - `exported_at`
  - `includes_secrets`
  - 可选：记录数量（按表计数，不含标题/正文）

### E3. 恢复前保护（必须）

- 在执行覆盖前，强制提示并提供按钮：`先创建安全备份（推荐）`
  - 若用户跳过：要求二次确认（避免误触）

### E4. Passphrase 输入 + 执行

- 输入错误：提示 `密码错误或文件损坏`；不泄露更多细节；给 `重试` / `取消`
- 执行中：展示进度（可不精确，但必须可取消）

### E5. 完成

- Success：Toast + `继续`（回到主线；必要时提示重启）
- Failure：保持现有数据不变；给 `重试` / `返回继续使用`

## 7. 统一文案模板（复用）

- 错误：`结论一句话 + 人话原因 + 下一步按钮`
- 权限/不可用：`不影响使用` + `继续无约束` + `去设置`
- 危险动作：红色语义 + 二次确认 + 明确不可撤销

## 8. 埋点对齐（事件字典）

实现需按 `prds/daypick-event-dictionary-2026-01-24.md` 记录：

- `export_started` / `export_completed`
- `backup_created`
- `restore_started` / `restore_completed`
- `safe_mode_entered`

