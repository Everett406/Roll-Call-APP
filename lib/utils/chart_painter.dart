import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ============================================================
/// Donut Chart Painter (Status Distribution)
/// ============================================================
class DonutChartPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double strokeWidth;
  final double gapAngle;

  DonutChartPainter({
    required this.segments,
    this.strokeWidth = 24,
    this.gapAngle = 0.05,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final total = segments.fold(0.0, (s, seg) => s + seg.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;

    for (final seg in segments) {
      final sweepAngle = (seg.value / total) * 2 * math.pi - gapAngle;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

/// Public donut segment data class
class DonutSegment {
  final double value;
  final Color color;
  final String label;

  DonutSegment({required this.value, required this.color, required this.label});
}

/// ============================================================
/// Donut Chart Widget
/// ============================================================
class DonutChart extends StatelessWidget {
  final List<MapEntry<String, dynamic>> data;

  const DonutChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.fold<int>(0, (s, d) => s + (d.value as int));

    final segments = data.map((d) {
      return DonutSegment(
        value: (d.value as int).toDouble(),
        color: d.key == 'uncheck'
            ? theme.colorScheme.surfaceContainerHighest
            : d.value is Color ? d.value as Color : theme.colorScheme.primary,
        label: d.key,
      );
    }).toList();

    return Row(
      children: [
        // Donut
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: DonutChartPainter(segments: segments),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '总签到',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: data.where((d) => (d.value as int) > 0).map((d) {
              final color = d.value is Color ? d.value as Color : theme.colorScheme.primary;
              return _LegendItem(
                label: d.key,
                color: color,
                value: '${d.value}次',
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final String value;

  const _LegendItem({required this.label, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// ============================================================
/// Line Chart Painter (Attendance Trend)
/// ============================================================
class LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final double maxY;

  LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    this.maxY = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final padding = const EdgeInsets.fromLTRB(32, 16, 12, 28);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = padding.top + (chartHeight * i / 4);
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(size.width - padding.right, y),
        gridPaint,
      );
    }

    // Draw Y axis labels
    final labelStyle = TextStyle(
      color: gridColor,
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );
    for (int i = 0; i <= 4; i++) {
      final y = padding.top + (chartHeight * i / 4);
      final value = ((4 - i) / 4 * maxY * 100).round();
      _drawText(canvas, '$value%', Offset(0, y - 5), labelStyle, maxWidth: 30);
    }

    // Build points
    final points = <Offset>[];
    final stepX = chartWidth / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      final x = padding.left + stepX * i;
      final y = padding.top + chartHeight * (1 - (values[i] / maxY));
      points.add(Offset(x, y));
    }

    // Draw area fill
    final fillPath = Path()
      ..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp1x = points[i - 1].dx + (points[i].dx - points[i - 1].dx) * 0.4;
      final cp1y = points[i - 1].dy;
      final cp2x = points[i - 1].dx + (points[i].dx - points[i - 1].dx) * 0.6;
      final cp2y = points[i].dy;
      fillPath.cubicTo(cp1x, cp1y, cp2x, cp2y, points[i].dx, points[i].dy);
    }
    fillPath
      ..lineTo(points.last.dx, padding.top + chartHeight)
      ..lineTo(points.first.dx, padding.top + chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor.withOpacity(0.3), fillColor.withOpacity(0.02)],
      ).createShader(Rect.fromLTWH(padding.left, padding.top, chartWidth, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // Draw smooth line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp1x = points[i - 1].dx + (points[i].dx - points[i - 1].dx) * 0.4;
      final cp1y = points[i - 1].dy;
      final cp2x = points[i - 1].dx + (points[i].dx - points[i - 1].dx) * 0.6;
      final cp2y = points[i].dy;
      linePath.cubicTo(cp1x, cp1y, cp2x, cp2y, points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Draw data points
    for (int i = 0; i < points.length; i++) {
      // Only draw first, last, and peaks
      if (i != 0 && i != values.length - 1) {
        bool isPeak = (i > 0 && values[i] > values[i - 1] && values[i] > values[i + 1]) ||
            (i > 0 && values[i] < values[i - 1] && values[i] < values[i + 1]);
        if (!isPeak) continue;
      }

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points[i], 4, dotPaint);

      final dotBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(points[i], 4, dotBorderPaint);
    }

    // X axis labels (first, middle, last)
    final xLabelStyle = TextStyle(color: gridColor, fontSize: 9, fontWeight: FontWeight.w500);
    if (values.length <= 7) {
      for (int i = 0; i < values.length; i++) {
        final x = padding.left + stepX * i;
        _drawText(canvas, '${i + 1}', Offset(x - 4, size.height - 16), xLabelStyle);
      }
    } else {
      _drawText(canvas, '1日', Offset(padding.left - 8, size.height - 16), xLabelStyle);
      _drawText(canvas, '${values.length ~/ 2}日',
          Offset(padding.left + chartWidth / 2 - 8, size.height - 16), xLabelStyle);
      _drawText(canvas, '${values.length}日',
          Offset(padding.left + chartWidth - 12, size.height - 16), xLabelStyle);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, {double? maxWidth}) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout(maxWidth: maxWidth ?? 60);
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

/// ============================================================
/// Line Chart Widget
/// ============================================================
class LineChart extends StatelessWidget {
  final List<double> values;
  final Color? lineColor;
  final double maxY;

  const LineChart({
    super.key,
    required this.values,
    this.lineColor,
    this.maxY = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = lineColor ?? theme.colorScheme.primary;

    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: LineChartPainter(
          values: values,
          lineColor: color,
          fillColor: color,
          gridColor: theme.colorScheme.outlineVariant.withOpacity(0.5),
          maxY: maxY,
        ),
        size: const Size(double.infinity, 160),
      ),
    );
  }
}

/// ============================================================
/// Period comparison badge widget
/// ============================================================
class ChangeBadge extends StatelessWidget {
  final double change;
  final String? label;

  const ChangeBadge({super.key, required this.change, this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = change >= 0;
    final color = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            '${change.abs() >= 1 ? change.abs().toStringAsFixed(0) : (change.abs() * 100).toStringAsFixed(1)}${change.abs() >= 1 ? '' : '%'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
