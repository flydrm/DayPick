import 'dart:async';

import 'package:data/data.dart' as data;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../ai/providers/ai_providers.dart';
import '../providers/data_providers.dart';
import 'pin_entry_sheet.dart';

class DataSettingsPage extends ConsumerWidget {
  const DataSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageScaffold(
      title: '数据',
      showSettingsAction: false,
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '导出 / 备份 / 恢复 / 清空，作为“无登录可控可信”的底层承诺。',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.output_outlined),
            title: const Text('导出 JSON'),
            subtitle: const Text('导出任务/笔记/番茄等全量数据（不含 apiKey）'),
            onTap: () => _exportJson(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('导出 Markdown'),
            subtitle: const Text('生成可阅读的导出（笔记/复盘等）'),
            onTap: () => _exportMarkdown(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('导出任务清单'),
            subtitle: const Text('仅导出任务（Markdown）'),
            onTap: () => _exportTasksMarkdown(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.note_alt_outlined),
            title: const Text('导出笔记'),
            subtitle: const Text('仅导出笔记（Markdown）'),
            onTap: () => _exportNotesMarkdown(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: const Text('导出复盘'),
            subtitle: const Text('仅导出日/周复盘（Markdown）'),
            onTap: () => _exportReviewsMarkdown(context, ref),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('创建加密备份'),
            subtitle: const Text('ZIP + AES-GCM，PIN 为恰好 6 位数字'),
            onTap: () => _createBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('恢复备份'),
            subtitle: const Text('恢复前会自动生成“安全备份包”，失败原地不动'),
            onTap: () => _restoreBackup(context, ref),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私说明'),
            subtitle: const Text('本地存储/AI 发送范围/备份与清空'),
            onTap: () => context.push('/settings/privacy'),
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.redAccent,
            ),
            title: const Text(
              '清空所有数据',
              style: TextStyle(color: Colors.redAccent),
            ),
            subtitle: const Text('不可逆操作，建议先备份'),
            onTap: () => _clearAllData(context, ref),
          ),
        ],
      ),
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认恢复？'),
        content: Text(
          '将恢复以下数量：\n'
          '- 任务：${preview.taskCount}\n'
          '- Checklist：${preview.checklistCount}\n'
          '- 笔记：${preview.noteCount}\n'
          '- 番茄：${preview.sessionCount}\n\n'
          '恢复前会自动生成“恢复前安全备份包”。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复完成'),
        content: Text(
          '已恢复：\n'
          '- 任务：${result.taskCount}\n'
          '- Checklist：${result.checklistCount}\n'
          '- 笔记：${result.noteCount}\n'
          '- 番茄：${result.sessionCount}\n\n'
          '已生成恢复前安全备份包（应用内）：\n$safetyPath',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
          FilledButton(
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
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('分享安全备份'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有数据？'),
        content: const Text('该操作不可逆，将清空任务/笔记/番茄记录等本地数据。\n\n建议先创建备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              _createBackup(context, ref);
            },
            child: const Text('先备份'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
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
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
