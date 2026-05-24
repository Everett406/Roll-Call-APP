import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Widget 截图导出工具
class WidgetCapture {
  /// 将 Widget 转换为图片数据
  static Future<Uint8List?> captureWidget(GlobalKey key, {double pixelRatio = 3.0}) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('WidgetCapture: RenderRepaintBoundary not found');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        debugPrint('WidgetCapture: Failed to convert to byte data');
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('WidgetCapture error: $e');
      return null;
    }
  }

  /// 保存图片到本地
  static Future<String?> saveToFile(Uint8List pngBytes, {String? fileName}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final name = fileName ?? 'capture_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$name');
      await file.writeAsBytes(pngBytes);
      return file.path;
    } catch (e) {
      debugPrint('WidgetCapture save error: $e');
      return null;
    }
  }

  /// 分享图片
  static Future<bool> shareImage(Uint8List pngBytes, {String? text, String? subject}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        subject: subject,
      );

      // 延迟删除临时文件
      Future.delayed(const Duration(seconds: 10), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      return true;
    } catch (e) {
      debugPrint('WidgetCapture share error: $e');
      return false;
    }
  }

  /// 转换为 Base64
  static String toBase64(Uint8List pngBytes) {
    return base64Encode(pngBytes);
  }
}

/// 可截图的 Widget 包装器
class CapturableWidget extends StatelessWidget {
  final Widget child;
  final GlobalKey captureKey;

  const CapturableWidget({
    super.key,
    required this.child,
    required this.captureKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: captureKey,
      child: child,
    );
  }
}
