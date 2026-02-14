import 'dart:io';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/capture/capture_submit_result.dart';
import '../../core/providers/app_providers.dart';
import 'date_picker_sheet.dart';
import '../kit/dp_inline_notice.dart';
import '../tokens/dp_insets.dart';
import '../tokens/dp_accessibility.dart';
import '../tokens/dp_spacing.dart';

enum QuickCreateType { task, memo, draft }

bool get _isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

class QuickCreateSheet extends ConsumerStatefulWidget {
  const QuickCreateSheet({
    super.key,
    this.initialType = QuickCreateType.task,
    this.initialTaskAddToToday = false,
    this.initialText,
  });

  final QuickCreateType initialType;
  final bool initialTaskAddToToday;
  final String? initialText;

  @override
  ConsumerState<QuickCreateSheet> createState() => _QuickCreateSheetState();
}

class _QuickCreateSheetState extends ConsumerState<QuickCreateSheet> {
  late QuickCreateType _type;
  bool _creating = false;

  QuickCreateType? _submitErrorType;
  String? _submitErrorTitle;
  String? _submitErrorDescription;
  CaptureSubmitResult? _pendingTaskSubmitResult;

  String? _taskTitleValidationError;

  final _taskTitleController = TextEditingController();
  final _taskTagsController = TextEditingController();
  late bool _taskAddToToday;
  bool _taskShowOptional = false;
  domain.TaskPriority _taskPriority = domain.TaskPriority.medium;
  DateTime? _taskDueAt;
  int _taskEstimatedPomodoros = 0;

  final _memoBodyController = TextEditingController();
  final _memoTagsController = TextEditingController();

  final _draftTitleController = TextEditingController();
  final _draftBodyController = TextEditingController();
  final _draftTagsController = TextEditingController();
  final FocusNode _sheetPrimaryFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _taskAddToToday = widget.initialTaskAddToToday;
    _taskTitleController.addListener(_onTaskTitleChanged);

    final initialText = widget.initialText?.trimRight();
    if (initialText != null && initialText.trim().isNotEmpty) {
      _memoBodyController.text = initialText;
      _draftBodyController.text = initialText;
      _taskTitleController.text = _taskTitleFromPrefill(initialText);
    }
  }

  @override
  void dispose() {
    _taskTitleController.removeListener(_onTaskTitleChanged);
    _taskTitleController.dispose();
    _taskTagsController.dispose();
    _memoBodyController.dispose();
    _memoTagsController.dispose();
    _draftTitleController.dispose();
    _draftBodyController.dispose();
    _draftTagsController.dispose();
    _sheetPrimaryFocusNode.dispose();
    super.dispose();
  }

  void _clearSubmitError() {
    _submitErrorType = null;
    _submitErrorTitle = null;
    _submitErrorDescription = null;
  }

  void _onTaskTitleChanged() {
    if (_taskTitleValidationError == null) return;
    if (_taskTitleController.text.trim().isEmpty) return;
    if (!mounted) return;
    setState(() => _taskTitleValidationError = null);
  }

  void _setSubmitError({
    required QuickCreateType type,
    required String title,
    required String description,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    if (cause != null && kDebugMode && !_isFlutterTest) {
      debugPrint('QuickCreate submit failed: $cause');
      if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) return;
    setState(() {
      _submitErrorType = type;
      _submitErrorTitle = title;
      _submitErrorDescription = description;
    });
  }

  Future<void> _retrySubmit(BuildContext context) async {
    return switch (_type) {
      QuickCreateType.task => _submitTask(context),
      QuickCreateType.memo => _submitMemo(context),
      QuickCreateType.draft => _submitDraft(context),
    };
  }

  Future<void> _addTaskToToday(String taskId) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    await ref
        .read(todayPlanRepositoryProvider)
        .addTask(day: day, taskId: taskId);
  }

  void _resetTaskForm() {
    _taskTitleController.clear();
    _taskTagsController.clear();
    _taskAddToToday = widget.initialTaskAddToToday;
    _taskShowOptional = false;
    _taskPriority = domain.TaskPriority.medium;
    _taskDueAt = null;
    _taskEstimatedPomodoros = 0;
  }

  void _resetMemoForm() {
    _memoBodyController.clear();
    _memoTagsController.clear();
  }

  void _resetDraftForm() {
    _draftTitleController.clear();
    _draftBodyController.clear();
    _draftTagsController.clear();
  }

  void _onTabChanged(QuickCreateType nextType) {
    if (_type == nextType) return;
    setState(() => _type = nextType);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sheetPrimaryFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final showSubmitError =
        _submitErrorTitle != null &&
        _submitErrorDescription != null &&
        _submitErrorType == _type;

    return SafeArea(
      child: Semantics(
        liveRegion: showSubmitError,
        child: Padding(
          padding: EdgeInsets.only(
            left: DpSpacing.lg,
            right: DpSpacing.lg,
            top: DpSpacing.md,
            bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick Create',
                      style: shadTheme.textTheme.h3.copyWith(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Semantics(
                    key: const ValueKey('quick_create_close'),
                    label: '关闭快速创建',
                    hint: '关闭后返回上一层',
                    button: true,
                    child: Tooltip(
                      message: '关闭',
                      child: ConstrainedBox(
                        constraints: DpAccessibility.minTouchTargetConstraints,
                        child: ShadIconButton.ghost(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.md),
              if (showSubmitError) ...[
                DpInlineNotice(
                  key: const ValueKey('quick_create_error'),
                  variant: DpInlineNoticeVariant.destructive,
                  title: _submitErrorTitle!,
                  description: _submitErrorDescription!,
                  icon: const Icon(Icons.error_outline),
                ),
                const SizedBox(height: DpSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: ShadButton.outline(
                    key: const ValueKey('quick_create_retry'),
                    onPressed: _creating ? null : () => _retrySubmit(context),
                    child: const Text('重试'),
                  ),
                ),
                const SizedBox(height: DpSpacing.md),
              ],
              ShadTabs<QuickCreateType>(
                value: _type,
                onChanged: _onTabChanged,
                scrollable: false,
                tabs: [
                  ShadTab(
                    value: QuickCreateType.task,
                    content: _TaskForm(
                      titleController: _taskTitleController,
                      tagsController: _taskTagsController,
                      addToToday: _taskAddToToday,
                      onAddToTodayChanged: (v) =>
                          setState(() => _taskAddToToday = v),
                      showOptional: _taskShowOptional,
                      onToggleOptional: () => setState(
                        () => _taskShowOptional = !_taskShowOptional,
                      ),
                      priority: _taskPriority,
                      onPriorityChanged: (v) =>
                          setState(() => _taskPriority = v),
                      dueAt: _taskDueAt,
                      onDueAtChanged: (v) => setState(() => _taskDueAt = v),
                      estimatedPomodoros: _taskEstimatedPomodoros,
                      onEstimatedPomodorosChanged: (v) =>
                          setState(() => _taskEstimatedPomodoros = v),
                      creating: _creating,
                      onSubmit: () => _submitTask(context),
                      titleErrorText: _taskTitleValidationError,
                      autofocus: _type == QuickCreateType.task,
                      primaryFocusNode: _type == QuickCreateType.task
                          ? _sheetPrimaryFocusNode
                          : null,
                    ),
                    child: const Text('任务'),
                  ),
                  ShadTab(
                    value: QuickCreateType.memo,
                    content: _MemoForm(
                      bodyController: _memoBodyController,
                      tagsController: _memoTagsController,
                      creating: _creating,
                      onSubmit: () => _submitMemo(context),
                      autofocus: _type == QuickCreateType.memo,
                      primaryFocusNode: _type == QuickCreateType.memo
                          ? _sheetPrimaryFocusNode
                          : null,
                    ),
                    child: const Text('闪念'),
                  ),
                  ShadTab(
                    value: QuickCreateType.draft,
                    content: _DraftForm(
                      titleController: _draftTitleController,
                      bodyController: _draftBodyController,
                      tagsController: _draftTagsController,
                      creating: _creating,
                      onSubmit: () => _submitDraft(context),
                      autofocus: _type == QuickCreateType.draft,
                      primaryFocusNode: _type == QuickCreateType.draft
                          ? _sheetPrimaryFocusNode
                          : null,
                    ),
                    child: const Text('长文'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitTask(BuildContext context) async {
    final pending = _pendingTaskSubmitResult;
    if (pending != null) {
      setState(() {
        _creating = true;
        _clearSubmitError();
      });
      try {
        await _addTaskToToday(pending.entryId);
        _pendingTaskSubmitResult = null;
        _resetTaskForm();
        if (context.mounted) {
          Navigator.of(context).pop(pending);
        }
      } catch (e, st) {
        _setSubmitError(
          type: QuickCreateType.task,
          title: '加入今天失败',
          description: '任务已创建（已进入待处理），但加入今天计划仍失败。输入已保留，请稍后重试。',
          cause: e,
          stackTrace: st,
        );
      } finally {
        if (mounted) setState(() => _creating = false);
      }
      return;
    }

    final title = _taskTitleController.text.trim();
    if (title.isEmpty) {
      setState(() => _taskTitleValidationError = '标题不能为空');
      return;
    }
    _taskTitleValidationError = null;

    const createTriageStatus = domain.TriageStatus.inbox;
    final resultTriageStatus = _taskAddToToday
        ? domain.TriageStatus.plannedToday
        : domain.TriageStatus.inbox;

    setState(() {
      _creating = true;
      _clearSubmitError();
    });
    try {
      final create = ref.read(createTaskUseCaseProvider);
      final task = await create(
        title: title,
        tags: _parseTags(_taskTagsController.text),
        priority: _taskPriority,
        dueAt: _taskDueAt,
        estimatedPomodoros: _taskEstimatedPomodoros <= 0
            ? null
            : _taskEstimatedPomodoros,
        triageStatus: createTriageStatus,
      );

      if (_taskAddToToday) {
        try {
          await _addTaskToToday(task.id);
        } catch (e, st) {
          _pendingTaskSubmitResult = CaptureSubmitResult(
            entryId: task.id,
            entryKind: CaptureEntryKind.task,
            triageStatus: resultTriageStatus,
          );
          _setSubmitError(
            type: QuickCreateType.task,
            title: '加入今天失败',
            description: '任务已创建（已进入待处理），但加入今天计划失败。输入已保留，请点击“重试”。',
            cause: e,
            stackTrace: st,
          );
          return;
        }
      }

      _resetTaskForm();
      if (context.mounted) {
        Navigator.of(context).pop(
          CaptureSubmitResult(
            entryId: task.id,
            entryKind: CaptureEntryKind.task,
            triageStatus: resultTriageStatus,
          ),
        );
      }
    } on domain.TaskTitleEmptyException {
      if (!mounted) return;
      setState(() => _taskTitleValidationError = '标题不能为空');
    } catch (e, st) {
      _setSubmitError(
        type: QuickCreateType.task,
        title: '创建失败',
        description: '本地写入失败，输入已保留。请点击“重试”。',
        cause: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _submitMemo(BuildContext context) async {
    final body = _memoBodyController.text.trimRight();
    if (body.trim().isEmpty) return;
    final title = _titleFromBody(body, fallback: '闪念');

    setState(() {
      _creating = true;
      _clearSubmitError();
    });
    try {
      final create = ref.read(createNoteUseCaseProvider);
      final note = await create(
        title: title,
        body: body,
        tags: _parseTags(_memoTagsController.text),
        kind: domain.NoteKind.memo,
        triageStatus: domain.TriageStatus.inbox,
      );
      _resetMemoForm();
      if (context.mounted) {
        Navigator.of(context).pop(
          CaptureSubmitResult(
            entryId: note.id,
            entryKind: CaptureEntryKind.memo,
            triageStatus: note.triageStatus,
          ),
        );
      }
    } on domain.NoteTitleEmptyException {
      _setSubmitError(
        type: QuickCreateType.memo,
        title: '标题不能为空',
        description: '请先填写内容再提交。',
      );
    } catch (e, st) {
      _setSubmitError(
        type: QuickCreateType.memo,
        title: '创建失败',
        description: '本地写入失败，输入已保留。请点击“重试”。',
        cause: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _submitDraft(BuildContext context) async {
    final body = _draftBodyController.text.trimRight();
    final title = _draftTitleController.text.trim().isEmpty
        ? _titleFromBody(body, fallback: '长文草稿')
        : _draftTitleController.text.trim();

    setState(() {
      _creating = true;
      _clearSubmitError();
    });
    try {
      final create = ref.read(createNoteUseCaseProvider);
      final note = await create(
        title: title,
        body: body,
        tags: _parseTags(_draftTagsController.text),
        kind: domain.NoteKind.draft,
        triageStatus: domain.TriageStatus.inbox,
      );
      _resetDraftForm();
      if (context.mounted) {
        Navigator.of(context).pop(
          CaptureSubmitResult(
            entryId: note.id,
            entryKind: CaptureEntryKind.draft,
            triageStatus: note.triageStatus,
          ),
        );
      }
    } on domain.NoteTitleEmptyException {
      _setSubmitError(
        type: QuickCreateType.draft,
        title: '标题不能为空',
        description: '请先填写内容再提交。',
      );
    } catch (e, st) {
      _setSubmitError(
        type: QuickCreateType.draft,
        title: '创建失败',
        description: '本地写入失败，输入已保留。请点击“重试”。',
        cause: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  String _titleFromBody(String body, {required String fallback}) {
    final firstLine = body.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return fallback;
    const max = 24;
    if (firstLine.length <= max) return firstLine;
    return '${firstLine.substring(0, max)}…';
  }

  String _taskTitleFromPrefill(String raw) {
    final firstLine = raw.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return '';
    const max = 60;
    if (firstLine.length <= max) return firstLine;
    return '${firstLine.substring(0, max)}…';
  }
}

class _TaskForm extends StatelessWidget {
  const _TaskForm({
    required this.titleController,
    required this.tagsController,
    required this.addToToday,
    required this.onAddToTodayChanged,
    required this.showOptional,
    required this.onToggleOptional,
    required this.priority,
    required this.onPriorityChanged,
    required this.dueAt,
    required this.onDueAtChanged,
    required this.estimatedPomodoros,
    required this.onEstimatedPomodorosChanged,
    required this.creating,
    required this.onSubmit,
    this.titleErrorText,
    this.autofocus = false,
    this.primaryFocusNode,
  });

  final TextEditingController titleController;
  final TextEditingController tagsController;
  final bool addToToday;
  final ValueChanged<bool> onAddToTodayChanged;
  final bool showOptional;
  final VoidCallback onToggleOptional;
  final domain.TaskPriority priority;
  final ValueChanged<domain.TaskPriority> onPriorityChanged;
  final DateTime? dueAt;
  final ValueChanged<DateTime?> onDueAtChanged;
  final int estimatedPomodoros;
  final ValueChanged<int> onEstimatedPomodorosChanged;
  final bool creating;
  final VoidCallback onSubmit;
  final String? titleErrorText;
  final bool autofocus;
  final FocusNode? primaryFocusNode;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DpSpacing.md),
        ShadCard(
          padding: DpInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadInput(
                key: const ValueKey('quick_create_task_title'),
                controller: titleController,
                autofocus: autofocus,
                focusNode: primaryFocusNode,
                enabled: !creating,
                placeholder: Text(
                  '输入一句话创建任务…',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.add_task, size: 18),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmit(),
              ),
              if (titleErrorText != null) ...[
                const SizedBox(height: DpSpacing.xs),
                Text(
                  titleErrorText!,
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.destructive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: DpSpacing.sm),
              ShadInput(
                controller: tagsController,
                enabled: !creating,
                placeholder: Text(
                  '标签（逗号分隔，可选）',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.tag_outlined, size: 18),
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadSwitch(
                value: addToToday,
                enabled: !creating,
                onChanged: onAddToTodayChanged,
                label: const Text('直接加入今天'),
                sublabel: const Text('开启后将不进入待处理'),
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: creating ? null : onToggleOptional,
                leading: Icon(
                  showOptional ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                child: Text(showOptional ? '收起可选字段' : '展开可选字段'),
              ),
              if (showOptional) ...[
                const SizedBox(height: DpSpacing.sm),
                Text(
                  '优先级',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: DpSpacing.xs),
                ShadSelect<domain.TaskPriority>(
                  enabled: !creating,
                  initialValue: priority,
                  selectedOptionBuilder: (context, value) => Text(
                    _priorityLabel(value),
                    style: shadTheme.textTheme.small.copyWith(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  options: const [
                    ShadOption(
                      value: domain.TaskPriority.high,
                      child: Text('高'),
                    ),
                    ShadOption(
                      value: domain.TaskPriority.medium,
                      child: Text('中'),
                    ),
                    ShadOption(
                      value: domain.TaskPriority.low,
                      child: Text('低'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    onPriorityChanged(value);
                  },
                ),
                const SizedBox(height: DpSpacing.md),
                _DueDateRow(
                  value: dueAt,
                  enabled: !creating,
                  onPick: () async {
                    final now = DateTime.now();
                    final initial =
                        dueAt ?? DateTime(now.year, now.month, now.day);
                    final picked = await showModalBottomSheet<DateTime>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      sheetAnimationStyle:
                          DpAccessibility.bottomSheetAnimationStyle(context),
                      builder: (context) => DatePickerSheet(
                        title: '选择截止日期',
                        initialDate: initial,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      ),
                    );
                    if (picked == null) return;
                    onDueAtChanged(
                      DateTime(picked.year, picked.month, picked.day),
                    );
                  },
                  onClear: dueAt == null ? null : () => onDueAtChanged(null),
                  onSetToday: () {
                    final now = DateTime.now();
                    onDueAtChanged(DateTime(now.year, now.month, now.day));
                  },
                  onSetTomorrow: () {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    onDueAtChanged(today.add(const Duration(days: 1)));
                  },
                ),
                const SizedBox(height: DpSpacing.md),
                Text(
                  '预计番茄',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: DpSpacing.xs),
                ShadSelect<int>(
                  enabled: !creating,
                  initialValue: estimatedPomodoros,
                  selectedOptionBuilder: (context, value) => Text(
                    value <= 0 ? '不估算' : '$value 番茄',
                    style: shadTheme.textTheme.small.copyWith(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  options: const [
                    ShadOption(value: 0, child: Text('不估算')),
                    ShadOption(value: 1, child: Text('1')),
                    ShadOption(value: 2, child: Text('2')),
                    ShadOption(value: 3, child: Text('3')),
                    ShadOption(value: 4, child: Text('4')),
                    ShadOption(value: 5, child: Text('5')),
                    ShadOption(value: 6, child: Text('6')),
                    ShadOption(value: 8, child: Text('8')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    onEstimatedPomodorosChanged(value);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            key: const ValueKey('quick_create_task_submit_semantics'),
            label: '创建任务',
            button: true,
            enabled: !creating,
            child: ConstrainedBox(
              constraints: DpAccessibility.minTouchTargetConstraints,
              child: ShadButton(
                key: const ValueKey('quick_create_task_submit'),
                onPressed: creating ? null : onSubmit,
                child: Text(creating ? '创建中…' : '创建任务'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemoForm extends StatelessWidget {
  const _MemoForm({
    required this.bodyController,
    required this.tagsController,
    required this.creating,
    required this.onSubmit,
    this.autofocus = false,
    this.primaryFocusNode,
  });

  final TextEditingController bodyController;
  final TextEditingController tagsController;
  final bool creating;
  final VoidCallback onSubmit;
  final bool autofocus;
  final FocusNode? primaryFocusNode;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DpSpacing.md),
        ShadCard(
          padding: DpInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadInput(
                key: const ValueKey('quick_create_memo_body'),
                controller: bodyController,
                autofocus: autofocus,
                focusNode: primaryFocusNode,
                enabled: !creating,
                maxLines: 4,
                placeholder: Text(
                  '打开即写，先收下再处理…',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.bolt_outlined, size: 18),
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadInput(
                controller: tagsController,
                enabled: !creating,
                placeholder: Text(
                  '标签（逗号分隔，可选）',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.tag_outlined, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            key: const ValueKey('quick_create_memo_submit_semantics'),
            label: '创建闪念',
            button: true,
            enabled: !creating,
            child: ConstrainedBox(
              constraints: DpAccessibility.minTouchTargetConstraints,
              child: ShadButton(
                key: const ValueKey('quick_create_memo_submit'),
                onPressed: creating ? null : onSubmit,
                child: Text(creating ? '创建中…' : '创建闪念'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftForm extends StatelessWidget {
  const _DraftForm({
    required this.titleController,
    required this.bodyController,
    required this.tagsController,
    required this.creating,
    required this.onSubmit,
    this.autofocus = false,
    this.primaryFocusNode,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final TextEditingController tagsController;
  final bool creating;
  final VoidCallback onSubmit;
  final bool autofocus;
  final FocusNode? primaryFocusNode;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DpSpacing.md),
        ShadCard(
          padding: DpInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadInput(
                key: const ValueKey('quick_create_draft_title'),
                controller: titleController,
                enabled: !creating,
                placeholder: Text(
                  '标题（可选）',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.title_outlined, size: 18),
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadInput(
                key: const ValueKey('quick_create_draft_body'),
                controller: bodyController,
                autofocus: autofocus,
                focusNode: primaryFocusNode,
                enabled: !creating,
                maxLines: 6,
                placeholder: Text(
                  '长文草稿：先写，再慢慢整理…',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.subject_outlined, size: 18),
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadInput(
                controller: tagsController,
                enabled: !creating,
                placeholder: Text(
                  '标签（逗号分隔，可选）',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.tag_outlined, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            key: const ValueKey('quick_create_draft_submit_semantics'),
            label: '创建长文草稿',
            button: true,
            enabled: !creating,
            child: ConstrainedBox(
              constraints: DpAccessibility.minTouchTargetConstraints,
              child: ShadButton(
                key: const ValueKey('quick_create_draft_submit'),
                onPressed: creating ? null : onSubmit,
                child: Text(creating ? '创建中…' : '创建长文草稿'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _priorityLabel(domain.TaskPriority priority) {
  return switch (priority) {
    domain.TaskPriority.high => '高',
    domain.TaskPriority.medium => '中',
    domain.TaskPriority.low => '低',
  };
}

class _DueDateRow extends StatelessWidget {
  const _DueDateRow({
    required this.value,
    required this.enabled,
    required this.onPick,
    required this.onSetToday,
    required this.onSetTomorrow,
    this.onClear,
  });

  final DateTime? value;
  final bool enabled;
  final Future<void> Function() onPick;
  final VoidCallback onSetToday;
  final VoidCallback onSetTomorrow;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final text = value == null
        ? '未设置'
        : '${value!.year}-${_two(value!.month)}-${_two(value!.day)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 18),
            const SizedBox(width: DpSpacing.sm),
            Expanded(
              child: Text(
                '截止：$text',
                style: shadTheme.textTheme.small.copyWith(
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Semantics(
              label: '选择截止日期',
              button: true,
              enabled: enabled,
              child: Tooltip(
                message: '选择日期',
                child: ConstrainedBox(
                  constraints: DpAccessibility.minTouchTargetConstraints,
                  child: ShadIconButton.ghost(
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    onPressed: enabled ? () async => onPick() : null,
                  ),
                ),
              ),
            ),
            Semantics(
              label: '清除截止日期',
              button: true,
              enabled: enabled && onClear != null,
              child: Tooltip(
                message: '清除',
                child: ConstrainedBox(
                  constraints: DpAccessibility.minTouchTargetConstraints,
                  child: ShadIconButton.ghost(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: enabled ? onClear : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DpSpacing.sm),
        Wrap(
          spacing: DpSpacing.sm,
          runSpacing: DpSpacing.sm,
          children: [
            ConstrainedBox(
              constraints: DpAccessibility.minTouchTargetConstraints,
              child: ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: enabled ? onSetToday : null,
                child: const Text('今天'),
              ),
            ),
            ConstrainedBox(
              constraints: DpAccessibility.minTouchTargetConstraints,
              child: ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: enabled ? onSetTomorrow : null,
                child: const Text('明天'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
