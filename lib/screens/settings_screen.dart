import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import '../providers/theme_provider.dart';
import '../providers/app_state.dart';
import '../utils/app_info.dart';
import '../utils/expressive_theme.dart';
import '../services/update_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import 'member_manager_screen.dart';
import 'group_manager_screen.dart';
import 'tag_manager_screen.dart';
import 'attendance_config_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCheckingUpdate = false;
  String _currentVersion = AppInfo.version; // syncs with AppInfo
  int _versionTapCount = 0; // 版本号点击计数
  DateTime? _lastVersionTap; // 上次点击时间
  bool _notificationsEnabled = false; // 通知开关状态（App内控制）

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    // 读取App内保存的通知开关状态
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('notifications_enabled');
    if (saved != null && mounted) {
      setState(() {
        _notificationsEnabled = saved;
      });
    }
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final version = await UpdateService.getCurrentVersion();
      if (mounted) {
        setState(() {
          _currentVersion = version;
        });
      }
    } catch (e) {
      // 使用默认版本号
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final appState = ref.watch(appStateProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        children: [
          // 设置标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              '设置',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

                // ===== 外观分组 =====
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '外观',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // 主题模式
                      ListTile(
                        leading: Icon(
                          themeState.themeMode == AppThemeMode.dark
                              ? Icons.dark_mode
                              : themeState.themeMode == AppThemeMode.light
                                  ? Icons.light_mode
                                  : Icons.brightness_auto,
                        ),
                        title: const Text('主题模式'),
                        subtitle: Text(_getThemeModeLabel(themeState.themeMode)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showThemeModeDialog(),
                      ),
                      const Divider(height: 1, indent: 52),
                      // 主题颜色
                      ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: themeState.seedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: const Text('主题颜色'),
                        subtitle: Text(_getThemeColorName(themeState.seedColor)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showColorPickerDialog(),
                      ),
                      const Divider(height: 1, indent: 52),
                      // 动态取色
                      SwitchListTile(
                        secondary: const Icon(Icons.palette_outlined),
                        title: const Text('动态取色'),
                        subtitle: Text(
                          themeState.dynamicColorEnabled
                              ? '已开启 - 高饱和度配色'
                              : '已关闭 - 柔和配色',
                        ),
                        value: themeState.dynamicColorEnabled,
                        onChanged: (value) {
                          themeState.setDynamicColorEnabled(value);
                        },
                      ),
                      const Divider(height: 1, indent: 52),
                      // 卡片显示格式
                      SwitchListTile(
                        secondary: const Icon(Icons.format_list_numbered_outlined),
                        title: const Text('卡片显示百分比'),
                        subtitle: Text(
                          appState.showPercentageOnCards
                              ? '显示占比百分比'
                              : '显示实际人数',
                        ),
                        value: appState.showPercentageOnCards,
                        onChanged: (value) {
                          appState.setShowPercentageOnCards(value);
                        },
                      ),
                      const Divider(height: 1, indent: 52),
                      SwitchListTile(
                        secondary: Icon(
                          Icons.celebration_outlined,
                          color: appState.confettiEnabled ? Colors.amber : null,
                        ),
                        title: const Text('纸屑特效'),
                        subtitle: Text(
                          appState.confettiEnabled
                              ? '点名完成和随机抽选时显示庆祝特效'
                              : '已关闭纸屑特效',
                        ),
                        value: appState.confettiEnabled,
                        onChanged: (value) {
                          appState.setConfettiEnabled(value);
                        },
                      ),
                      if (appState.confettiEnabled)
                        _buildConfettiSettings(context, theme, appState),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: const Icon(Icons.format_list_numbered),
                        title: const Text('排名显示人数'),
                        subtitle: Text('${appState.rankingCount} 人'),
                        trailing: SizedBox(
                          width: 160,
                          child: Slider(
                            value: appState.rankingCount.toDouble(),
                            min: 3,
                            max: 20,
                            divisions: 17,
                            label: '${appState.rankingCount}',
                            onChanged: (v) => appState.setRankingCount(v.round()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                // ===== 数据管理分组 =====
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '数据管理',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Hero(
                          tag: 'settingsIcon_members',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Icon(Icons.people_outline, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        title: const Text('人员管理'),
                        subtitle: Text('共 ${appState.members.length} 人'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MemberManagerScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: Hero(
                          tag: 'settingsIcon_groups',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Icon(Icons.folder_outlined, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        title: const Text('分组管理'),
                        subtitle: Text('共 ${appState.groups.length} 个分组'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const GroupManagerScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: Hero(
                          tag: 'settingsIcon_tags',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Icon(Icons.label_outline, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        title: const Text('标签管理'),
                        subtitle: Text('共 ${appState.tags.length} 个标签'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TagManagerScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: Icon(
                          Icons.fact_check_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text('出勤标签配置'),
                        subtitle: Text(
                          '视为出勤：${appState.attendanceTagIds.length} 个标签',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AttendanceConfigScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                // ===== 数据操作分组 =====
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '数据操作',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.upload_outlined),
                        title: const Text('导出备份'),
                        subtitle: const Text('导出为JSON文件，可分享保存'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _exportData(),
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: const Icon(Icons.download_outlined),
                        title: const Text('导入备份'),
                        subtitle: const Text('从JSON文件恢复数据'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _importData(),
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          '清除所有数据',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        subtitle: const Text('删除所有人员、分组和点名记录'),
                        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.error),
                        onTap: () => _confirmClearData(),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                // ===== 通知设置 =====
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '通知设置',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLowest,
                  child: Column(
                    children: [
                      // 通知开关
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active_outlined),
                        title: Row(
                          children: [
                            const Text('接收通知'),
                            const SizedBox(width: 8),
                            // 问号按钮
                            GestureDetector(
                              onTap: _showNotificationHelp,
                              child: Icon(
                                Icons.help_outline,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          _notificationsEnabled ? '已开启' : '已关闭',
                        ),
                        value: _notificationsEnabled,
                        onChanged: (value) async {
                          if (value) {
                            // 开启：先请求权限，成功后保存状态
                            final granted = await NotificationService().requestPermission();
                            if (mounted) {
                              if (granted) {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('notifications_enabled', true);
                                setState(() {
                                  _notificationsEnabled = true;
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('需要通知权限才能开启')),
                                );
                              }
                            }
                          } else {
                            // 关闭：直接保存状态，不去系统设置
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('notifications_enabled', false);
                            setState(() {
                              _notificationsEnabled = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                // ===== 关于分组 =====
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '关于',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('关于点到为止'),
                        subtitle: Text('点到为止 ${AppInfo.fullVersion}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AboutScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: const Icon(Icons.update),
                        title: const Text('版本信息'),
                        subtitle: Text('当前版本: $_currentVersion'),
                        onTap: _onVersionTap,
                      ),
                      const Divider(height: 1, indent: 52),
                      // 检查更新
                      ListTile(
                        leading: _isCheckingUpdate
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : Icon(Icons.system_update, color: theme.colorScheme.primary),
                        title: const Text('检查更新'),
                        subtitle: const Text('检查是否有新版本可用'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _isCheckingUpdate ? null : () => _checkForUpdate(),
                      ),
                      const Divider(height: 1, indent: 52),
                      // 启动时自动检查更新
                      SwitchListTile(
                        secondary: const Icon(Icons.sync),
                        title: const Text('启动时自动检查更新'),
                        subtitle: Text(
                          themeState.autoCheckUpdate ? '已开启' : '已关闭',
                        ),
                        value: themeState.autoCheckUpdate,
                        onChanged: (value) {
                          themeState.setAutoCheckUpdate(value);
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ],
        ),
      );
  }

  String _getThemeModeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return '跟随系统';
      case AppThemeMode.light:
        return '亮色模式';
      case AppThemeMode.dark:
        return '暗色模式';
    }
  }

  String _getThemeColorName(Color color) {
    // 先检查扩展预设颜色
    for (final themeColor in extendedPresetColors) {
      if (themeColor.color.value == color.value) {
        return themeColor.name;
      }
    }
    // 再检查原有预设颜色
    for (final themeColor in themeColors) {
      if (themeColor.color.value == color.value) {
        return themeColor.name;
      }
    }
    return '自定义';
  }

  void _showThemeModeDialog() {
    final themeState = ref.read(themeProvider);

    showExpressiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(_getThemeModeLabel(mode)),
              value: mode,
              groupValue: themeState.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeState.setThemeMode(value);
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showColorPickerDialog() {
    final themeState = ref.read(themeProvider);

    showExpressiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题颜色'),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: extendedPresetColors.length,
            itemBuilder: (context, index) {
              final themeColor = extendedPresetColors[index];
              final isSelected = themeState.seedColor.value == themeColor.color.value;
              return GestureDetector(
                onTap: () {
                  themeState.setSeedColor(themeColor.color);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: themeColor.color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: themeColor.color.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 20,
                          color: themeColor.color.computeLuminance() > 0.5
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onPrimary,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    final path = await BackupService.exportToJson();
    if (path != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('备份文件已生成，请选择保存位置')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出失败')),
        );
      }
    }
  }

  Future<void> _importData() async {
    // Show merge/overwrite choice
    final mode = await showExpressiveDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入备份'),
        content: const Text('选择导入方式：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'merge'),
            child: const Text('合并'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'overwrite'),
            child: const Text('覆盖'),
          ),
        ],
      ),
    );

    if (mode == null || mode == 'cancel') return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择备份文件...')),
      );
    }

    final (success, message, _) = await BackupService.importFromJson(
      merge: mode == 'merge',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      if (success) {
        // Reload all data
        ref.read(appStateProvider).loadData();
      }
    }
  }

  Future<void> _confirmClearData() async {
    final confirm = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text('此操作将删除所有人员、分组和点名记录，且不可恢复。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定清除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final appState = ref.read(appStateProvider);
      await appState.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据已清除')),
        );
      }
    }
  }

  /// 版本号点击彩蛋
  void _onVersionTap() {
    final now = DateTime.now();
    // 超过1.5秒重置计数
    if (_lastVersionTap != null &&
        now.difference(_lastVersionTap!).inMilliseconds > 1500) {
      _versionTapCount = 0;
    }
    _lastVersionTap = now;
    _versionTapCount++;

    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      _showDeveloperEasterEgg();
    } else if (_versionTapCount >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('再点击 ${7 - _versionTapCount} 次解锁彩蛋 🤫'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  /// 通知帮助说明
  void _showNotificationHelp() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('通知说明'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '开启通知后，您将收到以下类型的消息：',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildNotificationTypeItem(
              icon: Icons.cake_outlined,
              title: '生日提醒',
              desc: '当天有人过生日时发送祝福提醒',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _buildNotificationTypeItem(
              icon: Icons.calendar_today_outlined,
              title: '出勤率周报',
              desc: '每周日发送本周出勤统计报告',
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            _buildNotificationTypeItem(
              icon: Icons.trending_down_outlined,
              title: '出勤率异常',
              desc: '检测到出勤率突然下降时提醒',
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            _buildNotificationTypeItem(
              icon: Icons.new_releases_outlined,
              title: '新版本通知',
              desc: '有新版本发布时通知一次',
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '注意：每种通知每天/每周只发送一次，避免打扰。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTypeItem({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 开发者彩蛋
  void _showDeveloperEasterEgg() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                '开发者模式',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '恭喜你发现了隐藏彩蛋！',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDevInfo('应用名称', '点到为止'),
                    _buildDevInfo('版本', AppInfo.fullVersion),
                    _buildDevInfo('框架', 'Flutter'),
                    _buildDevInfo('架构', 'Riverpod'),
                    _buildDevInfo('开发者', 'Everett'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 检查更新
  Future<void> _checkForUpdate() async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仅支持 Android 平台')),
      );
      return;
    }

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final releaseInfo = await UpdateService.checkUpdate();

      if (!mounted) return;

      if (releaseInfo != null) {
        // 有新版本，显示更新对话框
        _showUpdateDialog(releaseInfo);
      } else {
        // 已是最新版本
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(ReleaseInfo releaseInfo) {
    final theme = Theme.of(context);

    showExpressiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('发现新版本'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最新版本: ${releaseInfo.version}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '当前版本: $_currentVersion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (releaseInfo.downloadSize != null) ...[
                const SizedBox(height: 4),
                Text(
                  '文件大小: ${_formatFileSize(releaseInfo.downloadSize!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '更新说明:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    releaseInfo.body.isNotEmpty
                        ? releaseInfo.body
                        : '暂无更新说明',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后更新'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (releaseInfo.downloadUrl != null) {
                _startDownload(releaseInfo.downloadUrl!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('未找到下载链接')),
                );
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  /// 开始下载更新
  Future<void> _startDownload(String downloadUrl) async {
    try {
      final success = await UpdateService.downloadAndInstall(downloadUrl);
      if (!mounted) return;
      // 无论成功与否都显示后台下载提示
      // 因为即使返回 false，下载可能已在后台启动
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在后台下载，请查看通知栏'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // 即使抛出异常，也显示后台下载提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在后台下载，请查看通知栏'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 纸屑特效详细设置 - 默认折叠为高级选项（仅形状/模式/强度）
  Widget _buildConfettiSettings(BuildContext context, ThemeData theme, AppState appState) {
    final shapeLabels = ['圆形', '方形', '混合'];
    final modeLabels = ['爆炸', '下雨', '侧边', '边角'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          title: const Text('高级选项'),
          subtitle: Text(
            '形状·模式·强度',
            style: theme.textTheme.bodySmall,
          ),
          leading: const Icon(Icons.tune, size: 20),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // Shape
            Row(
              children: [
                Text('纸屑形状', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<int>(
                    segments: shapeLabels.asMap().entries.map((e) =>
                      ButtonSegment(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 12)))
                    ).toList(),
                    selected: {appState.confettiShape},
                    onSelectionChanged: (s) => appState.setConfettiShape(s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Mode
            Row(
              children: [
                Text('发射模式', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<int>(
                    segments: modeLabels.asMap().entries.map((e) =>
                      ButtonSegment(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 12)))
                    ).toList(),
                    selected: {appState.confettiMode},
                    onSelectionChanged: (s) => appState.setConfettiMode(s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Intensity
            Row(
              children: [
                Text('强度', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                Expanded(
                  child: Slider(
                    value: appState.confettiIntensity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: '${(appState.confettiIntensity * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => appState.setConfettiIntensity(v),
                  ),
                ),
              ],
            ),
            // Preview
            Center(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.preview, size: 18),
                label: const Text('预览效果'),
                onPressed: () => _previewConfetti(context, appState),
              ),
            ),
          ],
        ),
      ),
    );
}

void _previewConfetti(BuildContext context, AppState appState) {
    final controller = ConfettiController(duration: const Duration(seconds: 2));
    controller.play();

    final colors = _getConfettiColors(appState, Theme.of(context));
    final directionality = appState.confettiMode == 0
        ? BlastDirectionality.explosive
        : BlastDirectionality.directional;
    final double blastDirection = appState.confettiMode == 1
        ? 3.14159 / 2 // rain - downward
        : appState.confettiMode == 2
            ? 0.0 // side - rightward
            : 5.49779; // corner - bottom-right
    final particleCount = (30 + appState.confettiIntensity * 70).round();

    showExpressiveDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.of(context).canPop()) Navigator.pop(context);
        });
        return IgnorePointer(
          child: Align(
            alignment: appState.confettiMode == 1
                ? Alignment.topCenter
                : appState.confettiMode == 2
                    ? Alignment.centerLeft
                    : appState.confettiMode == 3
                        ? Alignment.topLeft
                        : Alignment.center,
            child: ConfettiWidget(
              confettiController: controller,
              blastDirectionality: directionality,
              blastDirection: blastDirection,
              shouldLoop: false,
              numberOfParticles: particleCount,
              colors: colors,
              createParticlePath: (size) {
                if (appState.confettiShape == 0) {
                  return Path()..addOval(Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height));
                } else if (appState.confettiShape == 1) {
                  return Path()..addRect(Rect.fromCenter(center: Offset.zero, width: size.width * 0.7, height: size.height));
                } else {
                  final rnd = math.Random();
                  if (rnd.nextBool()) {
                    return Path()..addOval(Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height));
                  } else {
                    return Path()..addRect(Rect.fromCenter(center: Offset.zero, width: size.width * 0.7, height: size.height));
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  List<Color> _getConfettiColors(AppState appState, ThemeData theme) {
    switch (appState.confettiColor) {
      case 0: return [theme.colorScheme.primary];
      case 1: return [theme.colorScheme.secondary];
      case 2: return [theme.colorScheme.tertiary];
      default: return const [
        Color(0xFF4CAF50), Color(0xFFF44336), Color(0xFF2196F3),
        Color(0xFFFFC107), Color(0xFF9C27B0), Color(0xFFFF9800),
        Color(0xFF00BCD4), Color(0xFFE91E63),
      ];
    }
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
