import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/app_state.dart';
import 'member_manager_screen.dart';
import 'group_manager_screen.dart';
import 'tag_manager_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final appState = ref.watch(appStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 外观设置
          _SectionHeader(title: '外观', theme: theme),
          
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
            onTap: () => _showThemeModeDialog(),
          ),
          
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
            onTap: () => _showColorPickerDialog(),
          ),
          
          // 动态取色开关
          SwitchListTile(
            secondary: const Icon(Icons.palette_outlined),
            title: const Text('动态取色'),
            subtitle: Text(themeState.dynamicColorEnabled ? '已开启 - 高饱和度配色' : '已关闭 - 柔和配色'),
            value: themeState.dynamicColorEnabled,
            onChanged: (value) {
              themeState.setDynamicColorEnabled(value);
            },
          ),

          const Divider(),

          // 数据管理
          _SectionHeader(title: '数据管理', theme: theme),
          
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('人员管理'),
            subtitle: Text('共 ${appState.members.length} 人'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MemberManagerScreen()));
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('分组管理'),
            subtitle: Text('共 ${appState.groups.length} 个分组'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupManagerScreen()));
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('标签管理'),
            subtitle: Text('共 ${appState.tags.length} 个标签'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TagManagerScreen()));
            },
          ),

          const Divider(),

          // 数据操作
          _SectionHeader(title: '数据操作', theme: theme),
          
          ListTile(
            leading: const Icon(Icons.import_export),
            title: const Text('导出数据'),
            subtitle: const Text('导出为JSON文件'),
            onTap: () => _exportData(),
          ),
          
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
            onTap: () => _confirmClearData(),
          ),

          const Divider(),

          // 关于
          _SectionHeader(title: '关于', theme: theme),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于点到为止'),
            subtitle: const Text('点到为止 v1.1.5'),
            onTap: () => _showAboutDialog(),
          ),
          
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('版本信息'),
            subtitle: const Text('当前版本: 1.1.5 (Build 5)'),
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
    for (final themeColor in themeColors) {
      if (themeColor.color.value == color.value) {
        return themeColor.name;
      }
    }
    return '自定义';
  }

  void _showThemeModeDialog() {
    final themeState = ref.read(themeProvider);
    
    showDialog(
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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题颜色'),
        content: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: themeColors.map((themeColor) {
            final isSelected = themeState.seedColor.value == themeColor.color.value;
            return GestureDetector(
              onTap: () {
                themeState.setSeedColor(themeColor.color);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
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
                        color: themeColor.color.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
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

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中')),
    );
  }

  Future<void> _confirmClearData() async {
    final confirm = await showDialog<bool>(
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

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '点到为止',
      applicationVersion: '1.1.5',
      applicationLegalese: '© 2026 Everett',
      children: [
        const SizedBox(height: 16),
        const Text(
          '一款专为班级骨干设计的点名应用，让点名操作更快速、更直觉。',
        ),
        const SizedBox(height: 8),
        const Text(
          '功能特性：',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('• 滑动点名，快速标记'),
        const Text('• 自定义标签，灵活分类'),
        const Text('• 多会话管理，历史可追溯'),
        const Text('• 出勤统计，一目了然'),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({
    required this.title,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
