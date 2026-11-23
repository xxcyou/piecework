import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/color_names.dart';
import '../../data/services/photo_service.dart';
import '../widgets/color_chip.dart';

/// 取色针：在货物实拍上点一下，取出那个颜色并反推颜色名。
///
/// 返回颜色名（例如「黑色」）；取消返回 null。
class ColorPickerPage extends StatefulWidget {
  const ColorPickerPage({super.key, required this.photoName});

  final String photoName;

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage> {
  ui.Image? _image;
  ByteData? _pixels;
  bool _loading = true;
  String? _error;

  Color? _picked;
  String _name = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await PhotoService.instance.fileOf(widget.photoName);
      if (file == null) {
        setState(() {
          _loading = false;
          _error = '找不到这张图片';
        });
        return;
      }
      final bytes = await File(file.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (!mounted) return;
      setState(() {
        _image = frame.image;
        _pixels = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读图失败：$e';
      });
    }
  }

  /// 取 3×3 平均色（单点容易取到噪点/高光）
  Color? _sampleAt(int x, int y) {
    final img = _image;
    final data = _pixels;
    if (img == null || data == null) return null;
    final bytes = data.buffer.asUint8List();
    var r = 0, g = 0, b = 0, n = 0;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final px = x + dx, py = y + dy;
        if (px < 0 || py < 0 || px >= img.width || py >= img.height) continue;
        final i = (py * img.width + px) * 4;
        if (i + 3 >= bytes.length) continue;
        r += bytes[i];
        g += bytes[i + 1];
        b += bytes[i + 2];
        n++;
      }
    }
    if (n == 0) return null;
    return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
  }

  void _onTap(Offset local, Size box) {
    final img = _image;
    if (img == null) return;
    final scale =
        math.min(box.width / img.width, box.height / img.height);
    final dw = img.width * scale, dh = img.height * scale;
    final dx = (box.width - dw) / 2, dy = (box.height - dh) / 2;
    if (local.dx < dx || local.dy < dy ||
        local.dx > dx + dw || local.dy > dy + dh) {
      return;
    }
    final px = ((local.dx - dx) / scale).floor();
    final py = ((local.dy - dy) / scale).floor();
    final c = _sampleAt(px, py);
    if (c == null) return;
    setState(() {
      _picked = c;
      _name = nameOfColor(c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('从实拍取色')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Text(
                        '在照片上点一下取色，会自动给出最接近的颜色名（可以再手动改）',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (ctx, c) => GestureDetector(
                          onTapDown: (d) =>
                              _onTap(d.localPosition, c.biggest),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withAlpha(60),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: RawImage(
                              image: _image,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_picked != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _picked,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: _name),
                                onChanged: (v) => _name = v,
                                decoration: const InputDecoration(
                                  labelText: '颜色名（可改）',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ColorChip(name: _name, size: 10),
                          ],
                        ),
                      ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('取消'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: _picked == null || _name.trim().isEmpty
                                    ? null
                                    : () => Navigator.of(context)
                                        .pop(_name.trim()),
                                child: const Text('用这个颜色'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
