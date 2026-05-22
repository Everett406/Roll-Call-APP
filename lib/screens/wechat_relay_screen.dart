import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../models/status_tag.dart';
import '../providers/app_state.dart';
import '../services/wechat_relay_parser.dart';

class WechatRelayScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const WechatRelayScreen({super.key, required this.sessionId});

  @override
  ConsumerState<WechatRelayScreen> createState() => _WechatRelayScreenState();
}

class _WechatRelayScreenState extends ConsumerState<WechatRelayScreen> {
  final _textController = TextEditingController();
  List<RelayParseResult> _parseResults = [];
  List<RelayParseResult> _modifiedResults = [];
  Map<String, String> _mappings = {};
  bool _hasParsed = false;
  bool _inputExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadMappings();
  }

  void _loadMappings() {
    _mappings = WechatRelayParser.loadMappings();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseText() {
    final state = ref.read(appStateProvider);
    final session = state.getSessionById(widget.sessionId);
    if (session == null) return;

    // 获取会话中的成员
    final members = <Member>[];
    for (final memberId in session.memberIds) {
      final member = state.getMemberById(memberId);
      if (member != null) {
        members.add(member);
      }
    }

    // 获取当前状态
    final currentStatuses = <String, String>{};
    for (final memberId in session.memberIds) {
      final checkIn = state.getActiveCheckIn(widget.sessionId, memberId);
      if (checkIn != null && checkIn.statusId != null) {
        currentStatuses[memberId] = checkIn.statusId!;
      }
    }

    final results = WechatRelayParser.parse(
      _textController.text,
      members,
      state.tags,
      _mappings,
      currentStatuses,
    );

    setState(() {
      _parseResults = results;
      _modifiedResults = List.from(results);
      _hasParsed = true;
      _inputExpanded = false; // 解析后自动收起输入框
    });
  }

  /// 更新结果标签 - 只保存映射，不改变板块位置
  void _updateResultTag(int index, String? tagId) {
    if (tagId == null) return;

    final result = _modifiedResults[index];
    final state = ref.read(appStateProvider);
    final tag = state.getTagById(tagId);

    // 自动保存映射
    if (result.status.isNotEmpty && result.matchedTagId != tagId) {
      WechatRelayParser.saveMapping(result.status, tagId);
      _mappings[result.status] = tagId;
    }

    setState(() {
      // 只更新标签ID和名称，不改变 parseStatus（保持原板块）
      _modifiedResults[index] = result.copyWith(
        matchedTagId: tagId,
        matchedTagName: tag?.name,
        // 不修改 parseStatus，保持在原来的板块
      );
    });
  }

  /// 新建标签并选择
  Future<void> _createAndSelectTag(int index) async {
    final nameController = TextEditingController();
    final state = ref.read(appStateProvider);

    // 自动生成差异化颜色
    final colorValue = state.generateDistinctColor();

    final result = await showDialog<(String, int)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建标签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '标签名称',
                hintText: '例如：外勤、图书馆',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 颜色预览
            Row(
              children: [
                Text('颜色: ', style: Theme.of(context).textTheme.bodyMedium),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(colorValue),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '自动分配（可在标签管理中修改）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(
                  context,
                  (nameController.text.trim(), colorValue),
                );
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (result != null) {
      final (name, color) = result;
      // 创建标签
      final newTag = await state.addTag(
        name: name,
        colorValue: color,
      );

      if (newTag != null && mounted) {
        // 自动选择新标签
        _updateResultTag(index, newTag.id);

        // 重新解析以更新其他相同状态的条目
        _parseText();
      }
    }
  }

  Future<void> _confirmAndMark() async {
    final state = ref.read(appStateProvider);

    // 分离冲突和非冲突的条目
    final conflictResults = <RelayParseResult>[];
    final nonConflictResults = <RelayParseResult>[];

    for (final result in _modifiedResults) {
      // 只处理有成员ID和标签ID的条目
      if (result.memberId == null || result.matchedTagId == null) continue;

      if (result.parseStatus == ParseStatus.alreadySet) {
        conflictResults.add(result);
      } else {
        nonConflictResults.add(result);
      }
    }

    // 处理非冲突条目
    for (final result in nonConflictResults) {
      await state.checkIn(
        sessionId: widget.sessionId,
        memberId: result.memberId!,
        statusId: result.matchedTagId!,
        note: '微信接龙导入',
      );
    }

    // 处理冲突条目
    for (final result in conflictResults) {
      final shouldOverride = await _showConflictDialog(result);
      if (shouldOverride == true) {
        await state.checkIn(
          sessionId: widget.sessionId,
          memberId: result.memberId!,
          statusId: result.matchedTagId!,
          note: '微信接龙导入（覆盖）',
        );
      } else if (shouldOverride == null) {
        // 用户选择取消全部
        break;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已标记 ${nonConflictResults.length + conflictResults.length} 人'),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<bool?> _showConflictDialog(RelayParseResult result) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('状态冲突'),
        content: Text(
          '${result.name} 已有状态 "${result.currentTagName}"，\n'
          '接龙中为 "${result.matchedTagName ?? result.status}"。\n\n'
          '是否覆盖现有状态？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消全部'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('覆盖'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    // 分类结果
    final matchedResults = _modifiedResults
        .where((r) => r.parseStatus == ParseStatus.matched)
        .toList();
    final statusMissingResults = _modifiedResults
        .where((r) => r.parseStatus == ParseStatus.statusMissing)
        .toList();
    final nameMissingResults = _modifiedResults
        .where((r) => r.parseStatus == ParseStatus.nameMissing)
        .toList();
    final alreadySetResults = _modifiedResults
        .where((r) => r.parseStatus == ParseStatus.alreadySet)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('微信接龙'),
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Column(
        children: [
          // 文本输入区（可折叠）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // 输入框标题栏（始终显示）
                InkWell(
                  onTap: () => setState(() => _inputExpanded = !_inputExpanded),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.paste,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _hasParsed
                                ? '接龙内容（点击${_inputExpanded ? "收起" : "展开"}编辑）'
                                : '粘贴微信接龙内容...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _hasParsed
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Icon(
                          _inputExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                // 输入框（可折叠）
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _inputExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextField(
                            controller: _textController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: '示例：\n1. 张三 已到\n2. 李四 请假\n3. 王五 迟到',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // 解析按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null && data!.text!.isNotEmpty) {
                        setState(() {
                          _textController.text = data.text!;
                          _inputExpanded = true;
                        });
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('剪贴板为空'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: const Text('粘贴'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _parseText,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('解析接龙'),
                  ),
                ),
              ],
            ),
          ),

          // 预览区
          if (_hasParsed)
            Expanded(
              child: _parseResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '未识别到有效人员',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // 统计信息
                        _buildStatsCard(
                          theme,
                          matchedResults.length,
                          statusMissingResults.length,
                          nameMissingResults.length,
                          alreadySetResults.length,
                        ),
                        const SizedBox(height: 12),

                        // 已匹配板块
                        if (matchedResults.isNotEmpty)
                          _buildSection(
                            theme,
                            icon: Icons.check_circle,
                            iconColor: Colors.green,
                            title: '已匹配 (${matchedResults.length})',
                            results: matchedResults,
                            state: state,
                          ),

                        // 状态未匹配板块
                        if (statusMissingResults.isNotEmpty)
                          _buildSection(
                            theme,
                            icon: Icons.warning,
                            iconColor: Colors.orange,
                            title: '状态未匹配 (${statusMissingResults.length})',
                            results: statusMissingResults,
                            state: state,
                          ),

                        // 已有状态板块
                        if (alreadySetResults.isNotEmpty)
                          _buildSection(
                            theme,
                            icon: Icons.info,
                            iconColor: Colors.blue,
                            title: '已有状态 - 将询问是否覆盖 (${alreadySetResults.length})',
                            results: alreadySetResults,
                            state: state,
                          ),

                        // 人名未找到板块
                        if (nameMissingResults.isNotEmpty)
                          _buildSection(
                            theme,
                            icon: Icons.error,
                            iconColor: Colors.red,
                            title: '人名未找到 (${nameMissingResults.length})',
                            results: nameMissingResults,
                            state: state,
                          ),

                        const SizedBox(height: 100),
                      ],
                    ),
            ),
        ],
      ),
      bottomNavigationBar: _hasParsed && _parseResults.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _confirmAndMark,
                        icon: const Icon(Icons.check),
                        label: const Text('确认标记'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStatsCard(
    ThemeData theme,
    int matched,
    int statusMissing,
    int nameMissing,
    int alreadySet,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(theme, matched, '已匹配', Colors.green),
            _buildStatItem(theme, statusMissing, '待选标签', Colors.orange),
            _buildStatItem(theme, alreadySet, '有冲突', Colors.blue),
            _buildStatItem(theme, nameMissing, '未找到', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, int count, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<RelayParseResult> results,
    required AppState state,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...results.asMap().entries.map((entry) {
          final index = _modifiedResults.indexOf(entry.value);
          return _buildResultItem(theme, entry.value, state, index);
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildResultItem(
    ThemeData theme,
    RelayParseResult result,
    AppState state,
    int index,
  ) {
    final tagOptions = state.tags
        .map((tag) => DropdownMenuItem(
              value: tag.id,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(tag.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(tag.name, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ))
        .toList();

    // 添加"新建标签"选项
    tagOptions.add(
      DropdownMenuItem(
        value: '__new_tag__',
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '新建标签',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 姓名
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.name ?? '未知',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 原始状态
                if (result.status.isNotEmpty)
                  Expanded(
                    child: Text(
                      result.status,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // 标签选择下拉框
            Row(
              children: [
                Text(
                  '标签: ',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: result.matchedTagId,
                        hint: const Text('选择标签', style: TextStyle(fontSize: 13)),
                        isExpanded: true,
                        isDense: true,
                        items: tagOptions,
                        onChanged: (tagId) {
                          if (tagId == '__new_tag__') {
                            _createAndSelectTag(index);
                          } else {
                            _updateResultTag(index, tagId);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // 当前状态提示（冲突时）
            if (result.parseStatus == ParseStatus.alreadySet &&
                result.currentTagName != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '当前状态: ${result.currentTagName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
