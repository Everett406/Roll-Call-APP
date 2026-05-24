import 'dart:math';
import 'package:flutter/material.dart';

/// 随机点名转盘组件
class RandomPickerWheel extends StatefulWidget {
  final List<String> items;
  final Function(String)? onSelected;
  final Color? color;

  const RandomPickerWheel({
    super.key,
    required this.items,
    this.onSelected,
    this.color,
  });

  @override
  State<RandomPickerWheel> createState() => _RandomPickerWheelState();
}

class _RandomPickerWheelState extends State<RandomPickerWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentAngle = 0;
  String? _selectedItem;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _animation.addListener(() {
      setState(() {});
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isSpinning = false;
        widget.onSelected?.call(_selectedItem ?? widget.items.first);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning || widget.items.isEmpty) return;

    setState(() {
      _isSpinning = true;
    });

    // 随机选择一个项目
    final random = Random();
    final selectedIndex = random.nextInt(widget.items.length);
    _selectedItem = widget.items[selectedIndex];

    // 计算旋转角度：5-8圈 + 停在选中项
    final baseSpins = 5 + random.nextDouble() * 3;
    final itemAngle = 2 * pi / widget.items.length;
    final targetAngle = baseSpins * 2 * pi + (selectedIndex * itemAngle);

    _animation = Tween<double>(
      begin: _currentAngle,
      end: _currentAngle + targetAngle,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward(from: 0);
    _currentAngle += targetAngle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 指针
        CustomPaint(
          size: const Size(40, 30),
          painter: _ArrowPainter(color),
        ),
        const SizedBox(height: 8),
        // 转盘
        GestureDetector(
          onTap: _spin,
          child: SizedBox(
            width: 280,
            height: 280,
            child: CustomPaint(
              painter: _WheelPainter(
                items: widget.items,
                angle: _animation.value > 0
                    ? _animation.value
                    : _currentAngle,
                color: color,
                selectedIndex: _selectedItem != null
                    ? widget.items.indexOf(_selectedItem!)
                    : -1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 结果显示
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _isSpinning
                ? theme.colorScheme.surfaceContainerHighest
                : _selectedItem != null
                    ? color.withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: _selectedItem != null
                ? Border.all(color: color, width: 2)
                : null,
          ),
          child: Text(
            _isSpinning
                ? '抽取中...'
                : _selectedItem ?? '点击转盘开始',
            style: theme.textTheme.titleLarge?.copyWith(
              color: _selectedItem != null ? color : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 重新抽取按钮
        if (_selectedItem != null && !_isSpinning)
          TextButton.icon(
            onPressed: _spin,
            icon: const Icon(Icons.refresh),
            label: const Text('重新抽取'),
          ),
      ],
    );
  }
}

/// 转盘绘制器
class _WheelPainter extends CustomPainter {
  final List<String> items;
  final double angle;
  final Color color;
  final int selectedIndex;

  _WheelPainter({
    required this.items,
    required this.angle,
    required this.color,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final itemAngle = 2 * pi / items.length;

    // 颜色列表
    final colors = [
      color,
      color.withOpacity(0.7),
      color.withOpacity(0.5),
      color.withOpacity(0.8),
      color.withOpacity(0.6),
    ];

    for (int i = 0; i < items.length; i++) {
      final startAngle = angle + (i * itemAngle);
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      // 绘制扇形
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        itemAngle,
        true,
        paint,
      );

      // 绘制边框
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        itemAngle,
        true,
        borderPaint,
      );

      // 绘制文字
      final textAngle = startAngle + itemAngle / 2;
      final textRadius = radius * 0.65;
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: items[i].length > 4 ? '${items[i].substring(0, 4)}...' : items[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 2,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // 绘制中心圆
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 30, centerPaint);

    final centerBorderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 30, centerBorderPaint);

    // 中心文字
    final centerText = TextPainter(
      text: TextSpan(
        text: '点名',
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    centerText.paint(
      canvas,
      Offset(
        center.dx - centerText.width / 2,
        center.dy - centerText.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return angle != oldDelegate.angle || selectedIndex != oldDelegate.selectedIndex;
  }
}

/// 箭头绘制器
class _ArrowPainter extends CustomPainter {
  final Color color;

  _ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);

    // 边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
