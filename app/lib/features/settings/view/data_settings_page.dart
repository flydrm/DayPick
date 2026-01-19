import 'dart:async';

import 'package:data/data.dart' as data;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../ai/providers/ai_providers.dart';
import '../providers/data_providers.dart';
import 'pin_entry_sheet.dart';

class DataSettingsPage extends ConsumerWidget {
  const DataSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return AppPageScaffold(
      title: '数据',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: ListView(
        padding: DpInsets.page,
        children: [
          const ShadAlert(
            icon: Icon(Icons.storage_outlined),
            title: Text('无登录、可控可信'),
            description: Text('导出 / 备份 / 恢复 / 清空，作为“单设备隐私党”的底层承诺。'),
          ),
          const SizedBox(height: DpSpacing.md),
          Text(
            '导出',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: DpSpacing.sm),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _DataRow(
                  icon: Icons.output_outlined,
                  title: '导出 JSON',
                  subtitle: '导出任务/笔记/番茄等全量数据（不含 apiKey）',
                  onTap: () => _exportJson(context, ref),
                ),
                Divider(height: 0, color: colorScheme.border),
                _DataRow(
                  icon: Icons.description_outlined,
                  title: '导出 Markdown',
                  subtitle: '生成可阅读的导出（笔记/复盘等）',
                  onTap: () => _exportMarkdown(context, ref),
                ),
                Divider(height: 0, color: colorScheme.border),
                _DataRow(
                  icon: Icons.list_alt_outlined,
                  title: '导出任务清单',
                  subtitle: '仅导出任务（Markdown）',
                  onTap: () => _exportTasksMarkdown(context, ref),
                ),
                Divider(height: 0, color: colorScheme.border),
                _DataRow(
                  icon: Icons.note_alt_outlined,
                  title: '导出笔记',
                  subtitle: '仅导出笔记（Markdown）',
                  onTap: () => _exportNotesMarkdown(context, ref),
                ),
                Divider(height: 0, color: colorScheme.border),
                _DataRow(
                  icon: Icons.event_note_outlined,
                  title: '导出复盘',
                  subtitle: '仅导出日/周复盘（Markdown）',
                  onTap: () => _exportReviewsMarkdown(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          Text(
            '备份',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: DpSpacing.sm),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _DataRow(
                  icon: Icons.lock_outline,
                  title: '创建加密备份',
                  subtitle: 'ZIP + AES-GCM，PIN 为恰好 6 位数字',
                  onTap: () => _createBackup(context, ref),
                ),
                Divider(height: 0, color: colorScheme.border),
                _DataRow(
                  icon: Icons.restore_outlined,
                  title: '恢复备份',
                  subtitle: '恢复前会自动生成“安全备份包”，失败原地不动',
                  onTap: () => _restoreBackup(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          Text(
            '隐私与清空',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: DpSpacing.sm),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _DataRow(
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私说明',
                  subtitle: '本地存储/AI 发送范围/备份与清空',
                  onTap: () => context.push('/settings/privacy'),
                ),
                Divider(height: 0, color: colorScheme.border),
                _DataRow(
                  icon: Icons.key_outlined,
                  title: '清除 AI apiKey',
                  subtitle: '仅删除 apiKey（baseUrl/model 保留）',
                  onTap: () => _clearAiApiKey(context, ref),
                ),
                Divider(height: 0, color: colorScheme.border),
                _DataRow(
                  icon: Icons.delete_forever_outlined,
                  title: '清空所有数据',
                  subtitle: '不可逆操作，建议先备份',
                  destructive: true,
                  onTap: () => _clearAllData(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAiApiKey(BuildContext context, WidgetRef ref) async {
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('清除 AI apiKey？'),
        description: const Text(
          '将从本地密文存储中删除 apiKey。\n\n'
          '- baseUrl/model 会保留\n'
          '- 不影响任务/笔记/番茄等本地数据',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final cleared = await _runWithProgress(
      context,
      label: '清除中…',
      run: () async {
        await ref.read(aiConfigRepositoryProvider).clearApiKey();
        ref.invalidate(aiConfigProvider);
        return true;
      },
    );
    if (cleared != true) return;
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除 AI apiKey')));
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final service = ref.read(dataExportServiceProvider);
    final fileName = 'daypick_export_${_ts(DateTime.now())}.json';
    final bytes = await _runWithProgress(
      context,
      label: '生成中…',
      run: () => service.exportJsonBytes(),
    );
    if (bytes == null) return;
    if (!context.mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        subject: 'DayPick 导出（JSON）',
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: 'application/json'),
        ],
      ),
    );
  }

  Future<void> _exportMarkdown(BuildContext context, WidgetRef ref) async {
    final service = ref.read(dataExportServiceProvider);
    final fileName = 'daypick_export_${_ts(DateTime.now())}.md';
    final bytes = await _runWithProgress(
      context,
      label: '生成中…',
      run: () => service.exportMarkdownBytes(),
    );
    if (bytes == null) return;
    if (!context.mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        subject: 'DayPick 导出（Markdown）',
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: 'text/markdown'),
        ],
      ),
    );
  }

  Future<void> _exportTasksMarkdown(BuildContext context, WidgetRef ref) async {
    final service = ref.read(dataExportServiceProvider);
    final fileName = 'daypick_tasks_${_ts(DateTime.now())}.md';
    final bytes = await _runWithProgress(
      context,
      label: '生成中…',
      run: () => service.exportTasksMarkdownBytes(),
    );
    if (bytes == null) return;
    if (!context.mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        subject: 'DayPick 导出（任务）',
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: 'text/markdown'),
        ],
      ),
    );
  }

  Future<void> _exportNotesMarkdown(BuildContext context, WidgetRef ref) async {
    final service = ref.read(dataExportServiceProvider);
    final fileName = 'daypick_notes_${_ts(DateTime.now())}.md';
    final bytes = await _runWithProgress(
      context,
      label: '生成中…',
      run: () => service.exportNotesMarkdownBytes(),
    );
    if (bytes == null) return;
    if (!context.mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        subject: 'DayPick 导出（笔记）',
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: 'text/markdown'),
        ],
      ),
    );
  }

  Future<void> _exportReviewsMarkdown(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final service = ref.read(dataExportServiceProvider);
    final fileName = 'daypick_reviews_${_ts(DateTime.now())}.md';
    final bytes = await _runWithProgress(
      context,
      label: '生成中…',
      run: () => service.exportReviewsMarkdownBytes(),
    );
    if (bytes == null) return;
    if (!context.mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        subject: 'DayPick 导出（复盘）',
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: 'text/markdown'),
        ],
      ),
    );
  }

  Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
    final pin = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const PinEntrySheet(
        request: PinEntryRequest(
          title: '创建加密备份',
          primaryLabel: '输入 6 位 PIN',
          secondaryLabel: '再次输入 PIN',
          requireConfirmation: true,
        ),
      ),
    );
    if (pin == null) return;
    if (!context.mounted) return;

    final backupService = ref.read(dataBackupServiceProvider);
    final store = ref.read(backupFileStoreProvider);

    final bytes = await _runWithProgress(
      context,
      label: '生成备份…',
      run: () => backupService.createEncryptedBackup(pin: pin),
    );
    if (bytes == null) return;
    if (!context.mounted) return;

    final fileName =
        'daypick_backup_${_ts(DateTime.now())}.${data.DataBackupService.fileExtension}';
    final savedPath = await _runWithProgress(
      context,
      label: '保存到应用内…',
      run: () => store.saveToAppDocuments(bytes: bytes, fileName: fileName),
    );
    if (savedPath == null) return;
    if (!context.mounted) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已创建备份，可通过分享保存到文件系统/网盘')));

    await SharePlus.instance.share(
      ShareParams(
        subject: 'DayPick 备份',
        text: '备份已加密（PIN 丢失将无法恢复）。',
        files: [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'application/octet-stream',
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'DayPick 备份',
          extensions: [data.DataBackupService.fileExtension],
        ),
      ],
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    final pin = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const PinEntrySheet(
        request: PinEntryRequest(
          title: '恢复备份',
          primaryLabel: '输入备份 PIN',
          requireConfirmation: false,
        ),
      ),
    );
    if (pin == null) return;
    if (!context.mounted) return;

    final backupService = ref.read(dataBackupServiceProvider);
    final preview = await _runWithProgress(
      context,
      label: '校验备份…',
      run: () =>
          backupService.readBackupPreview(encryptedBytes: bytes, pin: pin),
    );
    if (preview == null) return;
    if (!context.mounted) return;

    if (!context.mounted) return;
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('确认恢复？'),
        description: Text(
          '将恢复以下数量：\n'
          '- 任务：${preview.taskCount}\n'
          '- Checklist：${preview.checklistCount}\n'
          '- 笔记：${preview.noteCount}\n'
          '- 编织链接：${preview.weaveLinkCount}\n'
          '- 番茄：${preview.sessionCount}\n\n'
          '恢复前会自动生成“恢复前安全备份包”。',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ShadButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('继续恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final store = ref.read(backupFileStoreProvider);
    final safetyBytes = await _runWithProgress(
      context,
      label: '创建安全备份包…',
      run: () => backupService.createEncryptedBackup(pin: pin),
    );
    if (safetyBytes == null) return;
    if (!context.mounted) return;

    final safetyName =
        'daypick_safety_before_restore_${_ts(DateTime.now())}.${data.DataBackupService.fileExtension}';
    final safetyPath = await _runWithProgress(
      context,
      label: '写入安全备份包…',
      run: () =>
          store.saveToAppDocuments(bytes: safetyBytes, fileName: safetyName),
    );
    if (safetyPath == null) return;
    if (!context.mounted) return;

    final result = await _runWithProgress(
      context,
      label: '执行恢复…',
      run: () => backupService.restoreFromEncryptedBackup(
        encryptedBytes: bytes,
        pin: pin,
      ),
    );
    if (result == null) return;
    if (!context.mounted) return;

    await ref.read(cancelPomodoroNotificationUseCaseProvider)();

    if (!context.mounted) return;
    await showShadDialog<void>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('恢复完成'),
        description: Text(
          '已恢复：\n'
          '- 任务：${result.taskCount}\n'
          '- Checklist：${result.checklistCount}\n'
          '- 笔记：${result.noteCount}\n'
          '- 编织链接：${result.weaveLinkCount}\n'
          '- 番茄：${result.sessionCount}\n\n'
          '已生成恢复前安全备份包（应用内）：\n$safetyPath',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('完成'),
          ),
          ShadButton.secondary(
            onPressed: () async {
              await SharePlus.instance.share(
                ShareParams(
                  subject: 'DayPick 恢复前安全备份包',
                  files: [
                    XFile.fromData(
                      safetyBytes,
                      name: safetyName,
                      mimeType: 'application/octet-stream',
                    ),
                  ],
                ),
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('分享安全备份'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('清空所有数据？'),
        description: const Text('该操作不可逆，将清空任务/笔记/番茄记录等本地数据。\n\n建议先创建备份。'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.secondary(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
              unawaited(_createBackup(context, ref));
            },
            child: const Text('先备份'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final maintenance = ref.read(dataMaintenanceServiceProvider);
    final cleared = await _runWithProgress(
      context,
      label: '清空中…',
      run: () async {
        await maintenance.clearAllData();
        await ref.read(cancelPomodoroNotificationUseCaseProvider)();
        await ref.read(aiConfigRepositoryProvider).clear();
        ref.invalidate(aiConfigProvider);
        return true;
      },
    );
    if (cleared != true) return;
    if (!context.mounted) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清空所有数据')));
    if (context.mounted) {
      context.go('/today');
    }
  }

  Future<T?> _runWithProgress<T>(
    BuildContext context, {
    required String label,
    required Future<T> Function() run,
  }) async {
    unawaited(
      showShadDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ShadDialog(
          title: const Text('处理中…'),
          child: Row(
            children: [
              const DpSpinner(size: 18, strokeWidth: 2),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
    try {
      final result = await run();
      if (context.mounted) Navigator.of(context).pop();
      return result;
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('失败：$e')));
      }
      return null;
    }
  }

  String _ts(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final titleColor = destructive
        ? colorScheme.destructive
        : colorScheme.foreground;
    final iconColor = destructive
        ? colorScheme.destructive
        : colorScheme.mutedForeground;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: DpSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: DpSpacing.xs),
                  Text(
                    subtitle,
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}
