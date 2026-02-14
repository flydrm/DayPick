import 'package:flutter/material.dart';

import '../../ui/kit/dp_action_toast.dart';

class ActionToastService {
  ActionToastService({
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
    Duration defaultDuration = const Duration(seconds: 6),
  }) : _scaffoldMessengerKey = scaffoldMessengerKey,
       _defaultDuration = defaultDuration;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;
  final Duration _defaultDuration;
  VoidCallback? _onUnavailable;

  @visibleForTesting
  void setOnUnavailable(VoidCallback? callback) {
    _onUnavailable = callback;
  }

  void showSuccess(
    String message, {
    Duration? duration,
    DpActionToastUndoAction? undo,
    DpActionToastBridgeAction? bridge,
  }) {
    show(
      message: message,
      variant: DpActionToastVariant.success,
      duration: duration,
      undo: undo,
      bridge: bridge,
    );
  }

  void showError(String message, {Duration? duration}) {
    show(
      message: message,
      variant: DpActionToastVariant.error,
      duration: duration,
    );
  }

  void show({
    required String message,
    required DpActionToastVariant variant,
    Duration? duration,
    DpActionToastUndoAction? undo,
    DpActionToastBridgeAction? bridge,
  }) {
    final state = _scaffoldMessengerKey.currentState;
    if (state == null) {
      assert(() {
        debugPrint(
          'ActionToastService.show ignored because ScaffoldMessengerState is unavailable.',
        );
        return true;
      }());
      _onUnavailable?.call();
      return;
    }

    var actionTaken = false;

    DpActionToastUndoAction? guardedUndo;
    if (undo != null) {
      guardedUndo = DpActionToastUndoAction(
        label: undo.label,
        onPressed: () async {
          if (actionTaken) return;
          actionTaken = true;
          _dismissCurrent();
          try {
            await undo.onPressed();
            showSuccess('已撤销', duration: const Duration(seconds: 2));
          } catch (e) {
            showError('撤销失败：$e');
          }
        },
      );
    }

    DpActionToastBridgeAction? guardedBridge;
    if (bridge != null) {
      guardedBridge = DpActionToastBridgeAction(
        label: bridge.label,
        entryId: bridge.entryId,
        onPressed: (entryId) async {
          if (actionTaken) return;
          actionTaken = true;
          _dismissCurrent();
          try {
            await bridge.onPressed(entryId);
          } catch (e) {
            showError('跳转失败：$e');
          }
        },
      );
    }

    state.clearSnackBars();
    state.showSnackBar(
      SnackBar(
        duration: duration ?? _defaultDuration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: DpActionToast(
          message: message,
          variant: variant,
          undo: guardedUndo,
          bridge: guardedBridge,
        ),
      ),
    );
  }

  void _dismissCurrent() {
    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar(
      reason: SnackBarClosedReason.action,
    );
  }
}
