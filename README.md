# DayPick · 一页今日（pace-pilot）

一款 **本地优先（Local-first）/离线可用/无登录** 的个人工作台：把「任务 → 专注 → 留痕 → 复盘」打成低摩擦闭环，并把 AI 做成“可控可信”的效率工具台（只在你触发时工作）。

## 功能概览（MVP）

- **任务（Todo）**：CRUD、筛选/排序、Quick Add、一键开始专注、Checklist、关联笔记与番茄记录
- **今天（工作台）**：下一步、可编辑且持久化的今天计划、昨天回顾摘要、今日专注统计
- **专注（Pomodoro）**：开始/暂停/继续/放弃、到点通知、状态恢复、结束收尾（保存/稍后补/AI 生成，支持撤销）
- **笔记（Notes）**：标题+正文、标签筛选、与任务双向关联；笔记内 AI 动作（总结/提取行动项/对外同步改写）
- **AI（效率台）**：AI 速记、一句话拆任务（可导入/可撤销）、问答检索（Evidence-first 引用可跳转）、今日计划草稿、昨日回顾、周复盘（保存为笔记）
- **数据掌控**：导出 JSON/Markdown、加密备份/恢复（6 位数字 PIN）、一键清空、隐私说明页
- **外观**：主题（系统/浅色/深色）、密度（舒适/紧凑）、Accent A/B/C

## 快速开始

### 环境要求

- Flutter `3.38.6`（Dart `3.10.7`）
- Android SDK + Java 17（Gradle 构建用）

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

- `app/`：Flutter UI（Material 3）与路由/页面
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

## 安全提示

- 本项目为 **BYO Key**：AI 调用会把你选择的内容发送到你配置的 `baseUrl`。
- 加密备份使用 6 位数字 PIN（允许 0 开头）；PIN 丢失将无法恢复，请妥善保管。
