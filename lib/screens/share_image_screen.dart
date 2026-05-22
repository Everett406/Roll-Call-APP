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

/// Generate a beautiful shareable image of attendance results.
/// Uses RepaintBoundary to capture widget as image, then share via system share sheet.
class ShareImageScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ShareImageScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ShareImageScreen> createState() => _ShareImageScreenState();
}

class _ShareImageScreenState extends ConsumerState<ShareImageScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isCapturing = false;

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
    final statusGroups = <String, List<String>>{};
    for (final ci in checkIns) {
      if (ci.statusId == null) continue;
      final tag = state.getTagById(ci.statusId!);
      final name = tag?.name ?? '未知';
      statusGroups.putIfAbsent(name, () => []);
      final member = state.getMemberById(ci.memberId);
      statusGroups[name]!.add(member?.name ?? '未知');
    }

    // Unchecked members
    final checkedIds = checkIns.map((c) => c.memberId).toSet();
    final unchecked = session.memberIds
        .where((id) => !checkedIds.contains(id))
        .map((id) {
          final idx = session.memberIds.indexOf(id);
          return idx >= 0 && idx < session.memberNames.length
              ? session.memberNames[idx]
              : state.getMemberById(id)?.name ?? '未知';
        }).toList();
    if (unchecked.isNotEmpty) {
      statusGroups['未标记'] = unchecked;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('分享图片'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_isCapturing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _captureAndShare,
              icon: const Icon(Icons.share),
              label: const Text('分享'),
            ),
        ],
      ),
      body: SingleChildScrollView(
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
            RepaintBoundary(
              key: _captureKey,
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header decoration
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          session.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date
                      Text(
                        DateFormat('yyyy年M月d日 HH:mm').format(session.createdAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stats row
                      Row(
                        children: [
                          _buildStatBox(
                            '应到',
                            '$total',
                            theme.colorScheme.onSurface,
                            theme,
                          ),
                          const SizedBox(width: 12),
                          _buildStatBox(
                            '实到',
                            '$arrived',
                            theme.colorScheme.primary,
                            theme,
                          ),
                          const SizedBox(width: 12),
                          _buildStatBox(
                            '出勤率',
                            '$rate%',
                            arrived >= total * 0.9
                                ? const Color(0xFF4CAF50)
                                : arrived >= total * 0.7
                                    ? const Color(0xFFFF9800)
                                    : const Color(0xFFE53935),
                            theme,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      Divider(
                        color: theme.colorScheme.outlineVariant,
                        height: 1,
                      ),
                      const SizedBox(height: 16),

                      // Status groups
                      ...statusGroups.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.key}（${entry.value.length}）',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.value.join('\u3001'),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Footer
                      Row(
                        children: [
                          Icon(
                            Icons.fact_check,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '点到为止',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
