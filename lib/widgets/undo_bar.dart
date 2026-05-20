import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/operation_log.dart';
import '../providers/app_state.dart';

class UndoBar extends ConsumerWidget {
  final String sessionId;

  const UndoBar({
    super.key,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final lastLog = state.getLastUndoableLog(sessionId);

    if (lastLog == null) return const SizedBox.shrink();

    final member = state.getMemberById(lastLog.targetMemberId);
    final tag = lastLog.newStatusId != null
        ? state.getTagById(lastLog.newStatusId!)
        : null;
    final memberName = member?.name ?? '未知';
    final tagName = tag?.name ?? '未知';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.undo,
            color: Theme.of(context).colorScheme.inversePrimary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '撤销 $memberName -> $tagName',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onInverseSurface,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await state.undoLastAction(sessionId);
            },
            child: Text(
              '撤销',
              style: TextStyle(
                color: Theme.of(context).colorScheme.inversePrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
