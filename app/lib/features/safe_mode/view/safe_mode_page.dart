import 'dart:async';
import 'dart:io';

import 'package:data/data.dart' as data;
import 'package:data/db/db_key_store.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../settings/view/passphrase_entry_sheet.dart';
import '../model/safe_mode_reason.dart';

class SafeModePage extends StatefulWidget {
  const SafeModePage({
    super.key,
    required this.info,
    required this.onRetryBootstrap,
  });

  final SafeModeInfo info;
  final Future<void> Function() onRetryBootstrap;

  @override
  State<SafeModePage> createState() => _SafeModePageState();
}

class _SafeModePageState extends State<SafeModePage> {
  Future<bool>? _hasMigrationBackupFilesFuture;

  @override
  void initState() {
    super.initState();
    _ensureMigrationBackupFilesCheck();
  }

  @override
  void didUpdateWidget(covariant SafeModePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.reason != widget.info.reason) {
      _hasMigrationBackupFilesFuture = null;
      _ensureMigrationBackupFilesCheck();
    }
  }

  void _ensureMigrationBackupFilesCheck() {
    if (widget.info.reason != SafeModeReason.migrationFailed) return;
    _hasMigrationBackupFilesFuture ??= _safeHasMigrationBackupFiles();
  }

  Future<bool> _safeHasMigrationBackupFiles() async {
    try {
      return await data.DbMigrationBackupExportService()
          .hasMigrationBackupFiles();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final info = widget.info;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: DpInsets.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '数据已锁定（安全模式）',
                style: shadTheme.textTheme.h2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                '我们无法安全打开本地数据库。\n'
                '可能是设备安全存储异常、密钥丢失，或迁移失败。\n'
                '你可以尝试恢复，或选择清库重建。',
                style: shadTheme.textTheme.p.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              _DetailsCard(info: info),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadButton(
                    onPressed: () => _restoreFromEncryptedBackup(context),
                    child: const Text('从加密备份恢复'),
                  ),
                  const SizedBox(height: DpSpacing.sm),
                  if (info.reason == SafeModeReason.migrationFailed) ...[
                    FutureBuilder<bool>(
                      future: _hasMigrationBackupFilesFuture,
                      builder: (context, snapshot) {
                        final hasFiles = snapshot.data == true;
                        if (!hasFiles) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ShadButton.secondary(
                              onPressed: () => _exportMigrationBackup(context),
                              child: const Text('导出迁移前备份'),
                            ),
                            const SizedBox(height: DpSpacing.sm),
                          ],
                        );
                      },
                    ),
                  ],
                  ShadButton.secondary(
                    onPressed: () => widget.onRetryBootstrap(),
                    child: const Text('重试打开'),
                  ),
                  const SizedBox(height: DpSpacing.sm),
                  ShadButton.destructive(
                    onPressed: () => _confirmAndResetDb(context),
                    child: const Text('清库重建'),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndResetDb(BuildContext context) async {
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('确认清空本地数据？'),
        description: const Text('此操作会删除本机所有 DayPick 数据，且无法撤销。建议先从备份恢复。'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('仍要清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final reset = await _runWithProgress(
      context,
      label: '清库重建中…',
      run: () => data.DatabaseResetService().resetAll(),
    );
    if (reset != true) return;
    if (!context.mounted) return;

    await widget.onRetryBootstrap();
  }

  Future<void> _restoreFromEncryptedBackup(BuildContext context) async {
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

    final passphrase = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const PassphraseEntrySheet(
        request: PassphraseEntryRequest(
          title: '从备份恢复',
          primaryLabel: '输入备份密码',
          requireConfirmation: false,
          hintText: '仅用于解密备份包（不会上传）',
        ),
      ),
    );
    if (passphrase == null) return;
    if (!context.mounted) return;

    final preview = await _runWithProgress(
      context,
      label: '校验备份…',
      run: () async {
        final tmpDb = data.AppDatabase.inMemoryForTesting();
        try {
          final service = data.DataBackupService(db: tmpDb);
          return await service.readBackupPreview(
            encryptedBytes: bytes,
            passphrase: passphrase,
          );
        } finally {
          await tmpDb.close();
        }
      },
      errorMessage: _backupErrorMessage,
    );
    if (preview == null) return;
    if (!context.mounted) return;

    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('确认恢复？'),
        description: Text(
          '备份摘要（content-free）：\n'
          '- export_schema_version：${preview.schemaVersion}\n'
          '- exported_at_utc_ms：${preview.exportedAtUtcMillis}\n'
          '- includes_secrets：${preview.includesSecrets ? 'true' : 'false'}\n\n'
          '将恢复以下数量：\n'
          '- 任务：${preview.taskCount}\n'
          '- Checklist：${preview.checklistCount}\n'
          '- 笔记：${preview.noteCount}\n'
          '- 编织链接：${preview.weaveLinkCount}\n'
          '- 番茄：${preview.sessionCount}\n\n'
          '提示：当前数据库处于锁定状态，无法生成“恢复前安全备份包”。',
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

    final (result, _) = await _runWithCancellableProgress(
      context,
      label: '执行恢复…',
      run: (cancelToken) async {
        final reset = data.DatabaseResetService();
        final backup = await reset.backupExistingDatabaseFiles();
        await reset.clearMigrationStateMarker();
        try {
          final db = data.AppDatabase();
          try {
            final service = data.DataBackupService(db: db);
            return await service.restoreFromEncryptedBackup(
              encryptedBytes: bytes,
              passphrase: passphrase,
              cancelToken: cancelToken,
            );
          } finally {
            await db.close();
          }
        } catch (_) {
          await reset.restoreDatabaseFilesFromBackup(backup);
          if (widget.info.reason == SafeModeReason.dbKeyMissing) {
            try {
              await DbKeyStore().deleteKey();
            } catch (_) {}
          }
          rethrow;
        } finally {
          await reset.deleteDatabaseFileBackup(backup);
        }
      },
      errorMessage: _backupErrorMessage,
    );
    if (result == null) return;
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
          '- 番茄：${result.sessionCount}',
        ),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;

    await widget.onRetryBootstrap();
  }

  Future<void> _exportMigrationBackup(BuildContext context) async {
    final file = await _runWithProgress<File?>(
      context,
      label: '生成迁移前备份包…',
      run: () async {
        final bytes = await data.DbMigrationBackupExportService()
            .createMigrationBackupZipBytes();
        if (bytes == null) return null;

        final timestamp = DateTime.now()
            .toUtc()
            .toIso8601String()
            .replaceAll(':', '')
            .replaceAll('.', '');
        final fileName = 'daypick-migration-backup-$timestamp.zip';

        final dir = await Directory.systemTemp.createTemp(
          'daypick_migration_backup_',
        );
        final file = File('${dir.path}${Platform.pathSeparator}$fileName');
        await file.writeAsBytes(bytes, flush: true);
        return file;
      },
    );

    if (file == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未找到迁移前备份文件')));
      }
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: 'DayPick 迁移前备份',
          text: 'DayPick 迁移前备份（请妥善保管）',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分享失败：$e')));
      }
    }
  }

  Future<T?> _runWithProgress<T>(
    BuildContext context, {
    required String label,
    required Future<T> Function() run,
    String Function(Object error)? errorMessage,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage?.call(e) ?? '失败：$e')),
        );
      }
      return null;
    }
  }

  Future<(T? value, bool cancelled)> _runWithCancellableProgress<T>(
    BuildContext context, {
    required String label,
    required Future<T> Function(data.BackupCancellationToken cancelToken) run,
    String Function(Object error)? errorMessage,
  }) async {
    final cancelToken = data.BackupCancellationToken();
    unawaited(
      showShadDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          var cancelling = false;
          return StatefulBuilder(
            builder: (context, setState) => ShadDialog(
              title: const Text('处理中…'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const DpSpinner(size: 18, strokeWidth: 2),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label)),
                    ],
                  ),
                  const SizedBox(height: DpSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ShadButton.outline(
                      onPressed: cancelling
                          ? null
                          : () {
                              cancelToken.cancel();
                              setState(() => cancelling = true);
                            },
                      child: Text(cancelling ? '取消中…' : '取消'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    try {
      final result = await run(cancelToken);
      if (context.mounted) Navigator.of(context).pop();
      return (result, false);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (e is data.BackupCancelledException || cancelToken.isCancelled) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已取消')));
        }
        return (null, true);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage?.call(e) ?? '失败：$e')),
        );
      }
      return (null, false);
    }
  }

  String _backupErrorMessage(Object error) {
    if (error is data.BackupWrongPassphraseOrCorruptedException) {
      return '失败：密码错误或文件损坏';
    }
    if (error is data.BackupWeakPassphraseException) {
      return '失败：${error.toString()}';
    }
    if (error is data.BackupMissingAiApiKeyException) {
      return '失败：${error.toString()}';
    }
    if (error is data.BackupMissingAiConfigException) {
      return '失败：${error.toString()}';
    }
    if (error is data.BackupSensitiveContentDetectedException) {
      return '失败：检测到疑似密钥，已中止';
    }
    if (error is data.BackupUnsupportedException) {
      return '失败：${error.toString()}';
    }
    return '失败：操作失败，请重试';
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.info});

  final SafeModeInfo info;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final debugLabel = info.debugLabel?.trim();

    return ShadCard(
      padding: const EdgeInsets.all(DpSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
              const SizedBox(width: DpSpacing.xs),
              Text(
                '详情（content-free）',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: DpSpacing.sm),
          Text(
            'reason_code：${info.reason.code}',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
          if (debugLabel != null && debugLabel.isNotEmpty) ...[
            const SizedBox(height: DpSpacing.xs),
            Text(
              'debug：$debugLabel',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
