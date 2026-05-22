import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:vibration/vibration.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_state.dart';
import '../models/member.dart';
import '../models/random_pick_record.dart';
import '../utils/expressive_theme.dart';
import '../widgets/confetti_overlay.dart';
import 'candidate_config_screen.dart';

class RandomPickerScreen extends ConsumerStatefulWidget {
  const RandomPickerScreen({super.key});

  @override
  ConsumerState<RandomPickerScreen> createState() => _RandomPickerScreenState();
}

class _RandomPickerScreenState extends ConsumerState<RandomPickerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late ConfettiController _confettiController;
  String? _selectedMemberName;
  String? _selectedMemberStudentId;
  bool _isRolling = false;
  final Set<String> _selectedCandidateIds = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed && _isRolling) {
          _animationController.forward();
        }
      });
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _ensureAllSelected(List<Member> members) {
    if (_selectedCandidateIds.isEmpty && members.isNotEmpty) {
      _selectedCandidateIds.addAll(members.map((m) => m.id));
    }
  }

  void _startRoll() async {
    final state = ref.read(appStateProvider);
    final members = state.members.where(
      (m) => _selectedCandidateIds.contains(m.id),
    ).toList();
    if (members.isEmpty) return;

    setState(() {
      _isRolling = true;
      _selectedMemberName = null;
      _selectedMemberStudentId = null;
    });
    _animationController.forward();

    final random = math.Random();
    const rollDuration = Duration(milliseconds: 1800);
    final startTime = DateTime.now();

    var tickCount = 0;
    while (DateTime.now().difference(startTime) < rollDuration) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      final idx = random.nextInt(members.length);
      setState(() {
        _selectedMemberName = members[idx].name;
        _selectedMemberStudentId = members[idx].studentId;
      });
      // Tactile feedback every tick for rhythm
      Vibration.vibrate(duration: 10);
    }

    if (!mounted) return;
    final finalIdx = random.nextInt(members.length);
    final pickedMember = members[finalIdx];
    setState(() {
      _isRolling = false;
      _selectedMemberName = pickedMember.name;
      _selectedMemberStudentId = pickedMember.studentId;
    });
    _animationController.stop();

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 300);
    }

    final record = RandomPickRecord(
      id: const Uuid().v4(),
      memberId: pickedMember.id,
      memberName: pickedMember.name,
      studentId: pickedMember.studentId,
      pickedAt: DateTime.now(),
    );
    await state.addRandomPickRecord(record);

    if (state.confettiEnabled) {
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final members = state.members;
    final theme = Theme.of(context);
    final records = state.randomPickRecords;

    _ensureAllSelected(members);

    final candidateCount = members.where(
      (m) => _selectedCandidateIds.contains(m.id),
    ).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('随机点名'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (records.isNotEmpty)
            TextButton(
              onPressed: () => _showHistorySheet(context, state),
              child: const Text('历史'),
            ),
        ],
      ),
      body: Stack(
        children: [
          members.isEmpty
              ? _buildEmptyState(theme)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildResultCard(theme),
                      const Spacer(),
                      _buildCandidatePool(theme, members, candidateCount),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _isRolling || candidateCount == 0 ? null : _startRoll,
                          icon: _isRolling
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.casino),
                          label: Text(_isRolling ? '抽取中...' : '开始抽取'),
                          style: FilledButton.styleFrom(
                            shape: ExpressiveShapes.pill,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
          ConfettiOverlay(
            controller: _confettiController,
            appState: state,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final scale = 1.0 + (_animationController.value * 0.08);
        return Transform.scale(scale: scale, child: child);
      },
      child: Card(
        shape: ExpressiveShapes.cardLarge,
        elevation: 2,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            children: [
              if (_selectedMemberName == null) ...[
                Icon(
                  Icons.casino_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  '点击按钮开始抽取',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                Text(
                  _isRolling ? '抽取中...' : '选中',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedMemberName!,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_selectedMemberStudentId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '学号: ${_selectedMemberStudentId!}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else if (!_isRolling) ...[
                  const SizedBox(height: 8),
                  Text(
                    '未设置学号',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidatePool(ThemeData theme, List<Member> members, int count) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push<Set<String>>(
          context,
          MaterialPageRoute(
            builder: (_) => CandidateConfigScreen(
              initialSelectedIds: _selectedCandidateIds,
            ),
          ),
        );
        if (result != null) {
          setState(() {
            _selectedCandidateIds
              ..clear()
              ..addAll(result);
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.people_outline,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '候选: $count / ${members.length} 人',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '设置',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }



  void _showHistorySheet(BuildContext context, AppState state) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '抽选历史',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制全部'),
                        onPressed: () => _copyAllHistory(state),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '清空历史',
                        onPressed: () => _confirmClearHistory(state),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: state.randomPickRecords.isEmpty
                      ? const Center(child: Text('暂无记录'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: state.randomPickRecords.length,
                          itemBuilder: (context, index) {
                            final record = state.randomPickRecords[index];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(
                                  '${state.randomPickRecords.length - index}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              title: Text(record.memberName),
                              subtitle: record.studentId != null
                                  ? Text(record.studentId!)
                                  : null,
                              trailing: TextButton(
                                child: const Text('复制'),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                    text: record.studentId != null
                                        ? '${record.memberName}（${record.studentId}）'
                                        : record.memberName,
                                  ));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已复制')),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _copyAllHistory(AppState state) {
    final buffer = StringBuffer();
    for (final r in state.randomPickRecords) {
      if (r.studentId != null) {
        buffer.writeln('${r.memberName}（${r.studentId}）');
      } else {
        buffer.writeln(r.memberName);
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制全部历史到剪贴板')),
    );
  }

  Future<void> _confirmClearHistory(AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有抽选历史记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              shape: ExpressiveShapes.pill,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.clearRandomPickRecords();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined,
              size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            '暂无成员',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
