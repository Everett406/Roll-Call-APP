import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';

class RandomPickerScreen extends ConsumerStatefulWidget {
  const RandomPickerScreen({super.key});

  @override
  ConsumerState<RandomPickerScreen> createState() => _RandomPickerScreenState();
}

class _RandomPickerScreenState extends ConsumerState<RandomPickerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String? _selectedMemberName;
  String? _selectedMemberId;
  bool _isRolling = false;
  int _rollCount = 0;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startRoll() async {
    final members = ref.read(appStateProvider).members;
    if (members.isEmpty) return;

    setState(() {
      _isRolling = true;
      _selectedMemberName = null;
      _selectedMemberId = null;
    });
    _animationController.forward();

    // Roll animation
    final random = math.Random();
    const rollDuration = Duration(milliseconds: 1800);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < rollDuration) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() {
        final idx = random.nextInt(members.length);
        _selectedMemberName = members[idx].name;
        _selectedMemberId = members[idx].id;
      });
    }

    // Final pick
    if (!mounted) return;
    final finalIdx = random.nextInt(members.length);
    setState(() {
      _isRolling = false;
      _selectedMemberName = members[finalIdx].name;
      _selectedMemberId = members[finalIdx].id;
      _rollCount++;
    });
    _animationController.stop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final members = state.members;
    final theme = Theme.of(context);

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
          '随机点名',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: members.isEmpty
          ? _buildEmptyState(theme)
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Result card
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final scale = 1.0 + (_animationController.value * 0.08);
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Card(
                      shape: ExpressiveShapes.cardLarge,
                      elevation: 2,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
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
                              if (!_isRolling && _selectedMemberId != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '学号: ${_selectedMemberId!.substring(0, math.min(8, _selectedMemberId!.length))}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats
                  if (_rollCount > 0)
                    Text(
                      '已抽取 $_rollCount 次',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  // Roll button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _isRolling ? null : _startRoll,
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
                  const SizedBox(height: 16),
                  // Pool info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          '候选池: ${members.length} 人',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
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
          const SizedBox(height: 8),
          Text(
            '先去导入或添加成员吧',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
