import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';
import '../models/member.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _textController = TextEditingController();
  List<_ParsedMember> _parsedMembers = [];
  List<_ParsedMember> _updateMembers = []; // 需要更新生日的人员
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

    final newMembers = <_ParsedMember>[];
    final updateMembers = <_ParsedMember>[];
    final seenKeys = <String>{};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.isEmpty || parts[0].isEmpty) continue;

      final name = parts[0];
      final studentId = parts.length > 1 ? parts[1] : null;
      
      // 解析可选的生日字段（第三个字段）
      DateTime? birthday;
      if (parts.length > 2) {
        birthday = _parseBirthday(parts[2]);
      }

      // Create a unique key for deduplication within the paste
      final key = studentId != null ? '$name|$studentId' : name;
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);

      // 查找是否已存在
      final existingMember = existing.firstWhere(
        (m) {
          if (studentId != null && m.studentId != null) {
            return m.name == name && m.studentId == studentId;
          } else if (studentId == null && m.studentId == null) {
            return m.name == name;
          } else if (studentId == null) {
            return m.name == name;
          }
          return false;
        },
        orElse: () => Member(id: '', name: ''),
      );

      if (existingMember.id.isNotEmpty) {
        // 已存在，检查是否需要更新生日
        if (birthday != null && existingMember.birthday == null) {
          updateMembers.add(_ParsedMember(
            name: name,
            studentId: studentId,
            birthday: birthday,
            existingId: existingMember.id,
          ));
        }
      } else {
        // 新成员
        newMembers.add(_ParsedMember(name: name, studentId: studentId, birthday: birthday));
      }
    }

    setState(() {
      _parsedMembers = newMembers;
      _updateMembers = updateMembers;
      _hasParsed = true;
    });
  }

  /// 解析生日字符串
  /// 支持格式：2005-02-01、2005/02/01、20050201
  DateTime? _parseBirthday(String str) {
    // 尝试 YYYY-MM-DD 格式
    if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(str)) {
      final parts = str.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    // 尝试 YYYY/MM/DD 格式
    if (RegExp(r'^\d{4}/\d{1,2}/\d{1,2}$').hasMatch(str)) {
      final parts = str.split('/');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    // 尝试 YYYYMMDD 格式（8位数字）
    if (RegExp(r'^\d{8}$').hasMatch(str)) {
      return DateTime(
        int.parse(str.substring(0, 4)),
        int.parse(str.substring(4, 6)),
        int.parse(str.substring(6, 8)),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalChanges = _parsedMembers.length + _updateMembers.length;

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
          '批量导入',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_hasParsed)
            TextButton(
              onPressed: _parseText,
              child: const Text('重新解析'),
            ),
        ],
      ),
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
                  '每行一个，支持格式：\n• 姓名\n• 姓名 学号\n• 姓名 学号 生日（可为已有人员补充生日）',
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
                      hintText: '张三 2024001 2005-02-01\n李四 2024002\n王五\n...',
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
                ? _buildPreview(theme)
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
      ),
      bottomNavigationBar: _hasParsed && totalChanges > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => _doImport(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: ExpressiveShapes.pill,
                  ),
                  child: Text(
                    '确认导入 (${_parsedMembers.length}新 + ${_updateMembers.length}更新)',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPreview(ThemeData theme) {
    if (_parsedMembers.isEmpty && _updateMembers.isEmpty) {
      return Center(
        child: Text(
          '没有可导入或更新的内容',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 新增人员
        if (_parsedMembers.isNotEmpty) ...[
          _buildSectionTitle(theme, '新增人员', _parsedMembers.length, theme.colorScheme.primary),
          const SizedBox(height: 8),
          ..._parsedMembers.asMap().entries.map((e) => _buildMemberItem(theme, e.value, e.key + 1, false)),
          const SizedBox(height: 16),
        ],
        // 更新生日
        if (_updateMembers.isNotEmpty) ...[
          _buildSectionTitle(theme, '补充生日', _updateMembers.length, theme.colorScheme.tertiary),
          const SizedBox(height: 8),
          ..._updateMembers.asMap().entries.map((e) => _buildMemberItem(theme, e.value, e.key + 1, true)),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count 人',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem(ThemeData theme, _ParsedMember m, int index, bool isUpdate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isUpdate
            ? theme.colorScheme.tertiaryContainer.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: isUpdate
            ? Border.all(color: theme.colorScheme.tertiary.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Text(
            '$index.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
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
          const Spacer(),
          if (m.birthday != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cake_outlined,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${m.birthday!.month}/${m.birthday!.day}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          if (isUpdate) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '更新',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _doImport() async {
    final state = ref.read(appStateProvider);
    
    // 新增人员
    for (final m in _parsedMembers) {
      await state.addMember(Member(
        name: m.name,
        studentId: m.studentId,
        birthday: m.birthday,
      ));
    }
    
    // 更新生日
    for (final m in _updateMembers) {
      if (m.existingId != null) {
        final existing = state.members.firstWhere((e) => e.id == m.existingId);
        await state.updateMember(existing.copyWith(birthday: m.birthday));
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 ${_parsedMembers.length} 人，更新 ${_updateMembers.length} 人')),
      );
      Navigator.pop(context, true);
    }
  }
}

class _ParsedMember {
  final String name;
  final String? studentId;
  final DateTime? birthday;
  final String? existingId; // 如果是更新，记录已有ID

  _ParsedMember({
    required this.name,
    this.studentId,
    this.birthday,
    this.existingId,
  });
}
