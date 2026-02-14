---
title: "DayPick（日拣）定位一页纸：核心竞争力与竞品对照"
date: "2026-01-20"
owner: "User"
status: "draft"
inputs:
  - "prds/daypick-beta-prd.md"
  - "prds/beta-implementation-summary.md"
  - "_bmad-output/analysis/brainstorming-session-2026-01-20T14:46:58.657Z.md"
  - "_bmad-output/planning-artifacts/product-brief-DayPick-2026-01-20.md"
  - "_bmad-output/planning-artifacts/ux-blueprints/daypick-today-workbench-v2-blueprint-2026-01-20.md"
  - "_bmad-output/planning-artifacts/product-briefs/daypick-today-workbench-v2-uiux-product-brief-2026-01-20.md"
external_references:
  - name: "Microsoft To Do · My Day & Suggestions"
    url: "https://support.microsoft.com/en-us/office/my-day-and-suggestions-fc09a1b9-0854-4906-b166-f480ee97a139"
  - name: "Todoist · Today view"
    url: "https://www.todoist.com/help/articles/plan-your-day-with-the-today-view-UVUXaiSs"
  - name: "TickTick · Arrange Tasks（拖拽任务到日历）"
    url: "https://blog.ticktick.com/2018/08/02/ticktickarrangetasks4android/"
  - name: "TickTick · Calendar Quickstart（Time blocking）"
    url: "https://blog.ticktick.com/2020/11/30/ticktick-calendar-quickstart/"
  - name: "Things · Today & This Evening（降噪分区）"
    url: "https://culturedcode.com/things/support/articles/4001304/"
  - name: "Obsidian · Local Markdown data（plain text）"
    url: "https://help.obsidian.md/import"
---

# 1) 一句话定位

**DayPick（日拣）是一款本地优先的今日工作台：用 3 秒把今天变清晰，并用「捕捉→计划→专注→留痕→复盘」的低摩擦闭环，让进度与产出可追溯。**

# 2) 目标用户与核心场景

- **主要人群**：日常上班族（碎片捕捉 + 白天执行 + 睡前回顾/复盘）
- **核心场景**：
  - **通勤/碎片时间**：快速捕捉闪念/任务/笔记草稿
  - **白天执行**：打开 Today 立刻知道“先做什么、时间够不够、还有多少待处理”，并一键开始专注
  - **睡前收尾**：10 秒留痕 + 轻量复盘，为明天滚动

# 3) 核心问题（定位切入）

用户打开“今天”时常见的真实痛点不是“缺功能”，而是：

- **看不清**：今天最重要做什么？时间是否够用？还有多少待处理要消化？
- **链路断裂**：捕捉的东西进了收件箱/笔记，但很难低摩擦沉淀为“今天的可执行计划”
- **工具切换**：在 Notion/Todoist/滴答/ChatGPT 等多个工具之间搬运信息，最终弃用

# 4) 核心承诺（可核验）

- **3 秒清晰（北极星）**：进入 Today 后 ≤3 秒进入“开始第 1 件事”的执行态（不是停留在找入口/找信息）。
- **3-2-10 闭环**：3 秒看清下一步；2 步开专注；番茄结束后 10 秒留痕回填并回到 Today。

# 5) 核心竞争力（建议用于对外叙事）

## P0：三条主轴（最稳定、可证据化）

1) **Today 不是清单，是“决策面”（Decision Surface）**
   - **主张**：一屏回答三件事：① 今天 Top3/下一步 ② 今日时间约束（时间块/日程概览）③ 待处理负载（Inbox 数量与入口）。
   - **为什么重要**：把“靠猜/靠找”的成本压到接近 0，让用户立刻进入可执行状态。
   - **对标差异**：相较 “My Day/Today view” 这类**今日清单**，DayPick 强调“清单 + 时间约束 + 待处理负载”在同一屏的默认主线组织方式。

2) **低摩擦闭环主线（Capture→Plan→Focus→留痕→Review）**
   - **主张**：捕捉不打断、执行不绕路、收尾有证据、复盘可沉淀。
   - **为什么重要**：把用户从“记录/计划”推进到“执行/产出”，并降低工具切换。
   - **证据/落地（现有 Beta/规划）**：Today/Tasks/Focus（含 Wrap-up 与通知持久化）、Notes、以及复盘与日记入口的 v2 规划已明确。

3) **Local-first 信任底座（可迁移、可审计、可清空）**
   - **主张**：无登录、离线可用；导出/加密备份/恢复/清空构成“数据掌控面”。
   - **为什么重要**：在个人效率工具高度云化的今天，“信任”会直接影响是否愿意把工作内容放进来。
   - **证据/落地（现有 Beta）**：已交付 export json/markdown、encrypted zip backup、restore、privacy reset 等能力。

## P1：两条加速器（差异化加分项）

4) **AI 可控可信（节点加速器 + Evidence-first）**
   - **主张**：AI 默认不是主舞台；只在你触发时工作，并以“草稿/建议”形式输出：预览→编辑→采用/撤销；不足则明确“不足”。
   - **对标差异**：与 Motion 式“重型默认自动排程”心智切割；避免 AI 变成额外负担。

5) **任务×笔记×复盘的引用联动（把碎片变产出、可追溯）**
   - **主张**：闪念/笔记/专注留痕能回填任务并进入复盘引用，让“今天做了什么”可讲述、可追溯。
   - **对标差异**：对标 PKM 工具（如 Obsidian 的本地 Markdown）更强调“数据可控”，但 DayPick 的重点是把它放进“今天的默认执行主线”里。

# 6) 竞品/替代方案对照（按用户心智分组）

> 目标不是“功能对齐”，而是明确 DayPick 的主张落在“Today 决策面 + 闭环执行 + 信任底座”的组合优势。

| 类别 | 用户买的是什么 | 代表产品/公开模式 | DayPick 的对照差异 |
|---|---|---|---|
| 今日清单/任务管理 | 快速列清单、按到期/优先级推进 | Microsoft To Do（My Day/Suggestions：每日重置聚焦）/ Todoist（Today view） | DayPick 把“下一步 + 时间约束 + 待处理负载”压到一屏，并把 Focus/留痕/复盘做成默认闭环，而不是分散在多视图/多模块里 |
| 任务 + 日历工作台 | timeboxing/仪式化日计划 | TickTick（拖拽到日历/Arrange Tasks） | DayPick 可以借鉴 timeblocking 的执行层，但在定位上强调“更轻、更安静、更可信（本地优先）”，并把复盘留痕纳入主线 |
| 纯 PKM/笔记 | 数据在本地、可迁移、可链接 | Obsidian（本地 Markdown）等 | DayPick 不与“笔记自由度”正面对抗，而强调“今天可执行”与“闭环留痕复盘”作为默认入口，降低搭系统成本 |
| 纯 LLM | 建议/总结/规划生成 | ChatGPT 等 | DayPick 把 AI 放回行动面：输出草稿并可采用/撤销；并把证据/引用链作为可信护栏 |

# 7) 对外表达资产（可直接复用）

## Tagline 备选（短句）

- 让今天 3 秒变清晰
- 本地优先的今日工作台
- 少而关键：下一步、时间、负载

## Elevator Pitch（20 秒）

DayPick 把“今天”做成可执行的决策面：打开就知道先做什么、时间够不够、还有多少待处理；然后用捕捉→计划→专注→留痕→复盘的闭环，把进度沉淀成可追溯的产出。全程本地优先，AI 仅在你触发时作为可控草稿加速器。

# 8) App Store 文案骨架（草案）

## 副标题（Subtitle）备选

- 本地优先 · 今日清晰 · 低摩擦闭环
- 把今天变清晰，把进度变可追溯

## 关键卖点（要点）

- **Today 3 秒清晰**：下一步、时间约束、待处理负载一屏看懂
- **专注可依赖**：一键开始专注，结束 10 秒留痕回填
- **隐私与掌控**：无登录、离线可用；支持导出/加密备份/恢复/清空
- **AI 可控**：只在你触发时工作，输出可预览编辑的草稿建议

## 隐私声明（短版）

DayPick 以本地存储为默认：不要求登录，核心功能离线可用。AI 功能仅在你触发时工作，并遵循可预览/可编辑/可撤销的原则。

