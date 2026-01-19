# DayPick · 一页今日

一款 **本地优先（Local-first）/离线可用/无登录** 的个人工作台：把「任务 → 专注 → 留痕 → 复盘」打成低摩擦闭环，并把 AI 做成“可控可信”的效率工具台（只在你触发时工作）。

## 功能概览（MVP）

- **创建入口（AppBar 右上角「＋」）**：统一 Quick Create（任务 / 闪念 Memo / 长文草稿；默认进 Inbox，任务可选直接加入今天）；仍保留系统分享/快捷方式直达 `/create`（可预填内容）
- **Inbox（待处理）**：收下 → 处理（加入今天 / 延期 / 归档 / 拆分子任务 / 编织进长文），支持批量与撤销
- **任务（Todo）**：CRUD、筛选/排序、批量处理、Checklist、关联笔记与番茄记录、一键开始专注
- **今天（工作台）**：模块化 Workbench（可开关/重排）、下一步主 CTA、今天计划（排序+建议填充）、预算/过载提示、昨天回顾
- **专注（Pomodoro）**：开始/暂停/继续/放弃、到点通知、状态恢复、结束收尾（进展/下一步/加入今天，支持撤销）
- **笔记（Notes）**：长文（纯文本/轻量 Markdown 渲染）+ Memo + 草稿；标签筛选；与任务双向关联；编织（Weave）；笔记内 AI 动作（总结/行动项/改写，含发送预览/离线草稿）
- **搜索（Search）**：全局搜索任务/笔记/Memo/专注记录
- **AI（效率台）**：AI 速记、拆任务（可导入/可撤销）、问答检索/今日计划/日周复盘（Evidence-first + 发送预览/字段开关；可保存为笔记）
- **数据掌控**：导出 JSON/Markdown、加密备份/恢复（6 位数字 PIN）、一键清空、隐私说明页
- **Android 系统入口**：App Shortcut（闪念/任务/专注）+ 系统分享/选中文本直达 `/create`（预填内容）
- **外观**：主题（系统/浅色/深色）、密度（舒适/紧凑）、Accent A/B/C

## 快速开始

### 环境要求

- Flutter `3.38.6`（Dart `3.10.7`）
- Android SDK + Java 17（Gradle 构建用）

> 如果你使用仓库内置 Flutter（`.tooling/flutter`）并希望 **避免每次测试都重新下载依赖**，
> 建议用 wrapper：`./tool/flutterw`（固定 `PUB_CACHE` 到 `.tooling/pub-cache`）。

### 运行（Android）

```bash
cd app
flutter pub get
flutter run
```

### 测试

```bash
cd app
flutter test
```

使用内置 Flutter + 缓存（推荐，避免每次都重新下载依赖）：

```bash
./tool/test
```

Analyze + 全量测试（含 `packages/data`）：

```bash
./tool/check
```

### 构建 APK（release）

```bash
cd app
flutter build apk --release
```

输出路径：`app/build/app/outputs/flutter-apk/app-release.apk`

## AI 设置（OpenAI 协议兼容）

在 `设置 → AI` 配置：

- `baseUrl`（示例：`https://api.openai.com` 或你的 OpenAI-compatible 服务地址；应用会自动补齐 `/v1`）
- `model`（示例：`gpt-4o-mini`）
- `apiKey`（仅本地密文存储；**导出/备份不包含 apiKey**）

说明：

- MVP 使用 **Chat Completions**：`POST /v1/chat/completions`
- 问答/复盘为 **Evidence-first**：回答必须附引用且可跳转；证据不足会明确提示
- AI 输出默认“建议”，采用前可编辑；支持取消

## GitHub Actions（自动打包 APK）

工作流：`.github/workflows/android-apk.yml`

- 触发：push/PR 到 `main`/`master`
- 产物：构建 `release` APK 并上传 Actions Artifact `daypick-apk`，同时会更新 `nightly` Release

## 仓库结构

- `app/`：Flutter UI（Shadcn UI 风格）与路由/页面
- `packages/domain/`：实体、UseCases、Repository 接口
- `packages/data/`：drift 数据库、Repository 实现、导出/备份/恢复、通知、密文存储
- `packages/ai/`：OpenAI-compatible 客户端与结构化输出解析
> 注：规划/设计等过程文档为本地文件，已加入 `.gitignore`，不会提交到仓库。

## 开发说明（可选）

如果你修改了 drift 表结构/数据库迁移逻辑，需要重新生成 `app_database.g.dart`：

```bash
cd packages/data
dart run build_runner build --delete-conflicting-outputs
```

使用内置 Dart + 缓存（推荐）：

```bash
cd packages/data
../../tool/dartw run build_runner build --delete-conflicting-outputs
```

## 安全提示

- 本项目为 **BYO Key**：AI 调用会把你选择的内容发送到你配置的 `baseUrl`。
- 加密备份使用 6 位数字 PIN（允许 0 开头）；PIN 丢失将无法恢复，请妥善保管。
