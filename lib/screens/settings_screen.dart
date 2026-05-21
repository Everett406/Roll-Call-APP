import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/app_state.dart';
import '../services/update_service.dart';
import 'member_manager_screen.dart';
import 'group_manager_screen.dart';
import 'tag_manager_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCheckingUpdate = false;
  String _currentVersion = '1.2.2';

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('设置'),
            floating: true,
            elevation: 0,
            scrolledUnderElevation: 4,
          ),
          SliverToBoxAdapter(
            child: Column(
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
                      // 图标风格
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text('图标风格'),
                        subtitle: Text(_getIconStyleName(themeState.iconStyle)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showIconStylePicker(context, themeState),
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
                        leading: const Icon(Icons.import_export),
                        title: const Text('导出数据'),
                        subtitle: const Text('导出为JSON文件'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _exportData(),
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
                        subtitle: const Text('点到为止 v1.2.2'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showAboutDialog(),
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: const Icon(Icons.update),
                        title: const Text('版本信息'),
                        subtitle: Text('当前版本: $_currentVersion'),
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

  String _getIconStyleName(AppIconStyle style) {
    switch (style) {
      case AppIconStyle.defaultStyle:
        return '默认';
      case AppIconStyle.rounded:
        return '圆角';
      case AppIconStyle.outlined:
        return '线条';
      case AppIconStyle.sharp:
        return '尖角';
    }
  }

  IconData _getPreviewIcon(AppIconStyle style) {
    switch (style) {
      case AppIconStyle.defaultStyle:
        return Icons.favorite;
      case AppIconStyle.rounded:
        return Icons.favorite_rounded;
      case AppIconStyle.outlined:
        return Icons.favorite_outline;
      case AppIconStyle.sharp:
        return Icons.favorite_sharp;
    }
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
                              ? Colors.black87
                              : Colors.white,
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

  void _showIconStylePicker(BuildContext context, ThemeState themeState) {
    showDialog(
      context: context,
      builder: (context) {
        final currentStyle = themeState.iconStyle;
        return AlertDialog(
          title: const Text('选择图标风格'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppIconStyle.values.map((style) {
              final isSelected = style == currentStyle;
              return RadioListTile<AppIconStyle>(
                title: Text(_getIconStyleName(style)),
                secondary: Icon(
                  _getPreviewIcon(style),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                value: style,
                groupValue: currentStyle,
                selected: isSelected,
                onChanged: (value) {
                  if (value != null) {
                    themeState.setIconStyle(value);
                  }
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
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
      applicationVersion: '1.2.2',
      applicationLegalese: '\u00a9 2026 Everett',
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
        const Text('\u2022 滑动点名，快速标记'),
        const Text('\u2022 自定义标签，灵活分类'),
        const Text('\u2022 多会话管理，历史可追溯'),
        const Text('\u2022 出勤统计，一目了然'),
      ],
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

    showDialog(
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
