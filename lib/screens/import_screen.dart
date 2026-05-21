import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/member.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _textController = TextEditingController();
  List<_ParsedMember> _parsedMembers = [];
  bool _hasParsed = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseText() {
    final text = _textController.text;
    final lines = text.split('\n');
    final existing = ref.read(appStateProvider).members;

    final parsed = <_ParsedMember>[];
    final seenKeys = <String>{};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.isEmpty || parts[0].isEmpty) continue;

      final name = parts[0];
      final studentId = parts.length > 1 ? parts[1] : null;

      // Create a unique key for deduplication within the paste
      final key = studentId != null ? '$name|$studentId' : name;
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);

      // Check if member already exists (by name+studentId or name alone if no studentId)
      bool alreadyExists = existing.any((m) {
        if (studentId != null && m.studentId != null) {
          return m.name == name && m.studentId == studentId;
        } else if (studentId == null && m.studentId == null) {
          return m.name == name;
        } else if (studentId == null) {
          return m.name == name;
        }
        return false;
      });

      if (alreadyExists) continue;

      parsed.add(_ParsedMember(name: name, studentId: studentId));
    }

    setState(() {
      _parsedMembers = parsed;
      _hasParsed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      Scaffold(
      appBar: AppBar(
        title: const Text('批量导入'),
        actions: [
          if (_hasParsed)
            TextButton(
              onPressed: _parseText,
              child: const Text('重新解析'),
            ),
        ],
      body: Column(
        children: [
          // Input area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '粘贴人员信息',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '从Excel/Word复制粘贴，每行一个，支持"姓名 学号"格式',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      hintText: '张三 2024001\n李四 2024002\n王五\n...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _parseText,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('解析'),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1),
          // Preview area
          Expanded(
            child: _hasParsed
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(
                              '预览结果',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_parsedMembers.length} 人',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_parsedMembers.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              '没有可导入的新人员（可能已存在或内容为空）',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _parsedMembers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 2),
                            itemBuilder: (context, index) {
                              final m = _parsedMembers[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '${index + 1}.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      m.name,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (m.studentId != null) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        m.studentId!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Text(
                      '请在上方输入人员信息后点击"解析"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ],
      bottomNavigationBar: _hasParsed && _parsedMembers.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => _doImport(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '确认导入 ${_parsedMembers.length} 人',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _doImport() async {
    final state = ref.read(appStateProvider);
    final newMembers = _parsedMembers.map((m) {
      return Member(
        name: m.name,
        studentId: m.studentId,
      );
    }).toList();

    await state.addMembers(newMembers);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 ${newMembers.length} 人')),
      );
      Navigator.pop(context, true);
    }
  }
}

class _ParsedMember {
  final String name;
  final String? studentId;

  _ParsedMember({required this.name, this.studentId});
}
