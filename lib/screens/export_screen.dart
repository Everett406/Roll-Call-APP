import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/session.dart';

class ExportScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ExportScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _includeArrived = true;
  bool _showNotes = false;

  /// 生成导出摘要文字
  String _generateExportText(AppState state, Session session) {
    final checkIns = state.getSessionCheckIns(widget.sessionId);
    final totalPeople = session.memberIds.length;

    // 按状态分组
    final statusGroups = <String, List<String>>{};
    for (final ci in checkIns) {
      if (ci.statusId == null) continue;
      // 跳过已到达（如果未勾选包含已到达）
      if (!_includeArrived && ci.statusId == 'tag_arrived') continue;

      final tag = state.getTagById(ci.statusId!);
      final tagName = tag?.name ?? '未知状态';

      // 获取成员名称
      final memberIdx = session.memberIds.indexOf(ci.memberId);
      String memberName;
      if (memberIdx >= 0 && memberIdx < session.memberNames.length) {
        memberName = session.memberNames[memberIdx];
      } else {
        final member = state.getMemberById(ci.memberId);
        memberName = member?.name ?? '未知';
      }

      // 如果开启备注显示，且有备注，追加括号备注
      if (_showNotes && ci.note != null && ci.note!.isNotEmpty) {
        memberName = '$memberName（${ci.note}）';
      }

      statusGroups.putIfAbsent(tagName, () => []);
      statusGroups[tagName]!.add(memberName);
    }

    // 计算已到人数
    final arrivedCount = checkIns.where((c) => c.statusId == 'tag_arrived').length;

    final buffer = StringBuffer();
    buffer.writeln(session.title);
    buffer.writeln('应到：${totalPeople}人  实到：${arrivedCount}人');
    buffer.writeln();

    // 按状态分组输出
    for (final entry in statusGroups.entries) {
      final names = entry.value;
      if (names.isEmpty) continue;
      buffer.writeln('${entry.key}（${names.length}）：');
      buffer.writeln(names.join('\u3001'));
      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制到剪贴板'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final session = state.getSessionById(widget.sessionId);
    final theme = Theme.of(context);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('导出点名摘要')),
        body: const Center(child: Text('点名不存在')),
      );
    }

    final exportText = _generateExportText(state, session);

    return Scaffold(
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          '导出点名摘要',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _copyToClipboard(exportText),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('复制'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 选项卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  // 包含已到达
                  SwitchListTile(
                    title: const Text('包含已到达人员'),
                    subtitle: const Text('关闭后只显示未到和其他状态'),
                    value: _includeArrived,
                    onChanged: (val) {
                      setState(() {
                        _includeArrived = val;
                      });
                    },
                    secondary: Icon(
                      Icons.people_outline,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Divider(height: 1, indent: 72),
                  // 显示备注
                  SwitchListTile(
                    title: const Text('显示备注'),
                    subtitle: const Text('开启后在人名后以括号形式显示备注'),
                    value: _showNotes,
                    onChanged: (val) {
                      setState(() {
                        _showNotes = val;
                      });
                    },
                    secondary: Icon(
                      Icons.note_add_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 预览标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.preview_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '预览',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 字数统计
                Text(
                  '${exportText.length} 字',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 预览内容
          Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  exportText.isEmpty ? '（没有符合条件的数据）' : exportText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: exportText.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _copyToClipboard(exportText),
            icon: const Icon(Icons.copy),
            label: const Text('复制到剪贴板'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
