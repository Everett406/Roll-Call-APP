import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';

// ============================================================
// Share Theme Definitions
// ============================================================

enum ShareTheme {
  cleanWhite('简约白', Icons.clean_hands_outlined, Colors.white, Color(0xFF1A1A1A), Color(0xFFF5F5F5)),
  darkMode('深色模式', Icons.dark_mode_outlined, Color(0xFF1E1E1E), Colors.white, Color(0xFF2A2A2A)),
  freshGreen('活力绿', Icons.eco_outlined, Color(0xFFF0F7F0), Color(0xFF1B5E20), Color(0xFFE8F5E9)),
  warmOrange('暖橙色', Icons.wb_sunny_outlined, Color(0xFFFFF5E6), Color(0xFFE65100), Color(0xFFFFE0B2));

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color accentBgColor;

  const ShareTheme(this.label, this.icon, this.backgroundColor, this.textColor, this.accentBgColor);
}

// ============================================================
// Share Image Screen
// ============================================================

class ShareImageScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ShareImageScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ShareImageScreen> createState() => _ShareImageScreenState();
}

class _ShareImageScreenState extends ConsumerState<ShareImageScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isCapturing = false;

  ShareTheme _selectedTheme = ShareTheme.cleanWhite;

  // Display toggles
  bool _showTotal = true;
  bool _showArrived = true;
  bool _showRate = true;
  bool _showTime = true;
  bool _showStatusBreakdown = true;
  bool _showMemberList = true;
  bool _showNotes = true;
  bool _showAppName = true;

  Future<void> _captureAndShare() async {
    setState(() => _isCapturing = true);

    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '点名结果',
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final session = state.getSessionById(widget.sessionId);
    final theme = Theme.of(context);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('分享图片')),
        body: const Center(child: Text('点名不存在')),
      );
    }

    final checkIns = state.getSessionCheckIns(widget.sessionId);
    final total = session.memberIds.length;
    final arrived = checkIns.where((c) => c.statusId == 'tag_arrived').length;
    final rate = total > 0 ? (arrived / total * 100).toStringAsFixed(1) : '0';

    // Group by status
    final statusGroups = <String, List<Map<String, dynamic>>>{};
    for (final ci in checkIns) {
      final tag = ci.statusId != null ? state.getTagById(ci.statusId!) : null;
      final name = tag?.name ?? '未知';
      final color = tag != null ? Color(tag.colorValue) : Colors.grey;
      statusGroups.putIfAbsent(name, () => []);
      final member = state.getMemberById(ci.memberId);
      statusGroups[name]!.add({
        'name': member?.name ?? '未知',
        'note': ci.note,
        'color': color,
      });
    }

    // Unchecked members
    final checkedIds = checkIns.map((c) => c.memberId).toSet();
    final uncheckedMembers = session.memberIds
        .where((id) => !checkedIds.contains(id))
        .map((id) {
          final member = state.getMemberById(id);
          return {'name': member?.name ?? '未知', 'note': null, 'color': Colors.grey};
        }).toList();
    if (uncheckedMembers.isNotEmpty) {
      statusGroups['未标记'] = uncheckedMembers;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('分享图片'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ===== Theme Selector =====
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ShareTheme.values.length,
              itemBuilder: (context, index) {
                final t = ShareTheme.values[index];
                final isSelected = _selectedTheme == t;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedTheme = t),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 16),
                        const SizedBox(width: 4),
                        Text(t.label),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                );
              },
            ),
          ),

          // ===== Customization Options =====
          ExpansionTile(
            title: const Text('自定义显示内容'),
            leading: const Icon(Icons.tune_outlined),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildToggle('显示应到人数', _showTotal, (v) => setState(() => _showTotal = v)),
              _buildToggle('显示实到人数', _showArrived, (v) => setState(() => _showArrived = v)),
              _buildToggle('显示出勤率', _showRate, (v) => setState(() => _showRate = v)),
              _buildToggle('显示时间', _showTime, (v) => setState(() => _showTime = v)),
              _buildToggle('显示状态分布', _showStatusBreakdown, (v) => setState(() => _showStatusBreakdown = v)),
              _buildToggle('显示成员列表', _showMemberList, (v) => setState(() => _showMemberList = v)),
              _buildToggle('显示备注', _showNotes, (v) => setState(() => _showNotes = v)),
              _buildToggle('显示应用标识', _showAppName, (v) => setState(() => _showAppName = v)),
            ],
          ),

          // ===== Preview =====
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Preview label
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.preview_outlined,
                            size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          '预览（实际导出为图片）',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // The capturable card
                  Center(
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: _buildShareCard(
                        session: session,
                        total: total,
                        arrived: arrived,
                        rate: rate,
                        statusGroups: statusGroups,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isCapturing ? null : _captureAndShare,
            icon: _isCapturing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
            label: Text(_isCapturing ? '生成中...' : '分享图片'),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }

  Widget _buildShareCard({
    required dynamic session,
    required int total,
    required int arrived,
    required String rate,
    required Map<String, List<Map<String, dynamic>>> statusGroups,
  }) {
    final t = _selectedTheme;

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: t.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: t == ShareTheme.darkMode
            ? Border.all(color: Colors.white.withOpacity(0.1))
            : Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== Header with accent bar =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(
                color: t.accentBgColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: t == ShareTheme.darkMode
                          ? Colors.white.withOpacity(0.1)
                          : t.textColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Time
                  if (_showTime)
                    Text(
                      DateFormat('yyyy年M月d日 HH:mm').format(session.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: t.textColor.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),

            // ===== Stats Grid =====
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      if (_showTotal)
                        Expanded(child: _buildShareStat('应到', '$total', t.textColor.withOpacity(0.6), t)),
                      if (_showTotal && _showArrived) const SizedBox(width: 10),
                      if (_showArrived)
                        Expanded(child: _buildShareStat('实到', '$arrived', _arrivedColor(t), t)),
                      if (_showArrived && _showRate) const SizedBox(width: 10),
                      if (_showRate)
                        Expanded(child: _buildShareStat('出勤率', '$rate%', _rateColor(arrived, total, t), t)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress bar
                  if (_showRate)
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.accentBgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: total > 0 ? arrived / total : 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _rateColor(arrived, total, t),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                  // Status breakdown
                  if (_showStatusBreakdown && statusGroups.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Divider(color: t.textColor.withOpacity(0.08), height: 1),
                    const SizedBox(height: 16),
                    ...statusGroups.entries.map((entry) {
                      final count = entry.value.length;
                      final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
                      final color = entry.value.isNotEmpty ? entry.value.first['color'] as Color : Colors.grey;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: TextStyle(fontSize: 13, color: t.textColor.withOpacity(0.75)),
                              ),
                            ),
                            Text(
                              '$count人',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textColor),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$percentage%',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Member list - Grid layout
                  if (_showMemberList && statusGroups.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Divider(color: t.textColor.withOpacity(0.08), height: 1),
                    const SizedBox(height: 16),
                    Text(
                      '成员签到详情',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.textColor.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 按状态分组显示，每个状态内用 Wrap 布局
                    ...statusGroups.entries.map((entry) {
                      final statusName = entry.key;
                      final color = entry.value.isNotEmpty ? entry.value.first['color'] as Color : Colors.grey;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 状态标签
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: t.textColor.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${entry.value.length}人)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: t.textColor.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 成员网格
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: entry.value.map((member) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: color.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      member['name'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: t.textColor.withOpacity(0.85),
                                      ),
                                    ),
                                    if (_showNotes && member['note'] != null && (member['note'] as String).isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: t.accentBgColor,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          member['note'] as String,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: t.textColor.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    }),
                  ],

                  const SizedBox(height: 16),

                  // Footer
                  if (_showAppName)
                    Row(
                      children: [
                        Icon(
                          Icons.fact_check,
                          size: 12,
                          color: t.textColor.withOpacity(0.35),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '点到为止',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.textColor.withOpacity(0.35),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareStat(String label, String value, Color color, ShareTheme t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: t.accentBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: t.textColor.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Color _rateColor(int arrived, int total, ShareTheme t) {
    if (total == 0) return t.textColor.withOpacity(0.3);
    final rate = arrived / total;
    if (rate >= 0.9) return const Color(0xFF4CAF50);
    if (rate >= 0.7) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }

  Color _arrivedColor(ShareTheme t) {
    if (t == ShareTheme.freshGreen) return const Color(0xFF2E7D32);
    if (t == ShareTheme.warmOrange) return const Color(0xFFEF6C00);
    return const Color(0xFF4CAF50);
  }
}
