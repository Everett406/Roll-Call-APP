import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        leading: IconButton(
          icon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // APP 图标 - 使用上传的图片
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 16),

            // APP 名称
            Text(
              '点到为止',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // 版本号
            Text(
              'v1.2.5',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 8),

            // 描述
            Text(
              '让点名更有诗意',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 24),

            // 分割线
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Divider(
                color: theme.colorScheme.outlineVariant,
                thickness: 1,
              ),
            ),

            const SizedBox(height: 24),

            // 功能介绍
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '功能介绍',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.assignment_outlined,
                          size: 20, color: theme.colorScheme.primary),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureListItem(
                    theme,
                    icon: Icons.paste,
                    title: '批量导入',
                    desc: '从Excel/Word复制粘贴',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureListItem(
                    theme,
                    icon: Icons.swipe,
                    title: '滑动点名',
                    desc: '右滑已到，左滑选状态',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureListItem(
                    theme,
                    icon: Icons.grid_view,
                    title: '网格视图',
                    desc: '姓名学号一目了然',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureListItem(
                    theme,
                    icon: Icons.schedule,
                    title: '自动归档',
                    desc: '24小时超时自动处理',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureListItem(
                    theme,
                    icon: Icons.system_update,
                    title: '应用内更新',
                    desc: '系统通知栏下载安装',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureListItem(
                    theme,
                    icon: Icons.dark_mode,
                    title: '深色模式',
                    desc: '亮色/暗色/跟随系统',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 分割线
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Divider(
                color: theme.colorScheme.outlineVariant,
                thickness: 1,
              ),
            ),

            const SizedBox(height: 24),

            // 支持开发者区块
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '支持开发者',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.favorite_outline,
                          size: 20, color: theme.colorScheme.primary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '如果这个应用对您有帮助...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 收款码并排
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 微信收款码
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/wechat_pay.png',
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.qr_code_2, size: 48),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '微信支付',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      // 支付宝收款码
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/alipay.png',
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.qr_code_2, size: 48),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '支付宝',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '感谢您的支持',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 分割线
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Divider(
                color: theme.colorScheme.outlineVariant,
                thickness: 1,
              ),
            ),

            const SizedBox(height: 24),

            // 技术栈
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    '技术栈',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.build_outlined,
                      size: 20, color: theme.colorScheme.primary),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTechChip(theme, 'Flutter'),
                  _buildTechChip(theme, 'Riverpod'),
                  _buildTechChip(theme, 'Hive'),
                  _buildTechChip(theme, 'Material Design 3'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 分割线
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Divider(
                color: theme.colorScheme.outlineVariant,
                thickness: 1,
              ),
            ),

            const SizedBox(height: 24),

            // 开发者信息
            Column(
              children: [
                Text(
                  '开发者',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Developed by Everett',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/Everett406/Roll-Call-APP'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.code,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'GitHub: Everett406/Roll-Call-APP',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 版权信息
            Text(
              '\u00a9 2026 Everett. All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 功能列表项
  Widget _buildFeatureListItem(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 技术栈标签
  Widget _buildTechChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
