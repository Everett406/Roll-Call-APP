import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 支持 Predictive Back 手势的页面包装组件
///
/// 使用 PopScope 拦截系统返回手势，并触发自定义的页面返回动画。
/// 当用户执行 Predictive Back 手势时，会执行缩放+淡出的返回动画。
class PredictiveBackPage extends StatefulWidget {
  /// 子页面内容
  final Widget child;

  /// 返回动画持续时间，默认 250ms
  final Duration duration;

  /// 自定义返回回调，如果提供则优先调用此回调
  final VoidCallback? onBack;

  /// 是否启用 Predictive Back，默认 true
  final bool enabled;

  const PredictiveBackPage({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
    this.onBack,
    this.enabled = true,
  });

  @override
  State<PredictiveBackPage> createState() => _PredictiveBackPageState();
}

class _PredictiveBackPageState extends State<PredictiveBackPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 执行 Predictive Back 返回动画
  Future<bool> _performPredictiveBack() async {
    if (!widget.enabled) return false;

    // 触觉反馈
    HapticFeedback.lightImpact();

    // 播放返回动画
    await _animationController.forward();

    // 动画完成后触发返回
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      // 默认行为：弹出当前页面
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return PopScope(
      canPop: false, // 阻止默认的返回行为
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 检测是否是 Predictive Back 手势
        // 在 Flutter 3.24+ 中，可以通过 BackGestureRecognizer 检测
        // 这里使用拦截方式处理
        await _performPredictiveBack();
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 页面路由生成器 - 创建支持 Predictive Back 的页面过渡
class PredictiveBackPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  PredictiveBackPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 进入动画：缩放 + 淡入
            final scaleAnimation = Tween<double>(
              begin: 0.9,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            return ScaleTransition(
              scale: scaleAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}

/// 辅助函数：使用 Predictive Back 路由导航到新页面
Future<T?> pushWithPredictiveBack<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(
    context,
    PredictiveBackPageRoute<T>(page: page),
  );
}
