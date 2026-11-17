import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../data/services/photo_service.dart';

/// 内置相机拍照页（camera 包，不使用 image_picker）。
///
/// 返回值：压缩后的 JPEG 字节（`Uint8List?`，取消则为 null）。
/// 照片只留在内存里传回上一页，由调用方决定存到哪个私有目录，
/// 因此**不会**出现在系统相册。
class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _index = 0;
  bool _initializing = true;
  bool _taking = false;
  String? _error;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切到后台必须释放相机，否则回前台会黑屏 / 报错
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final c = _controller;
      _controller = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _setup();
    }
  }

  Future<void> _setup() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) {
          setState(() {
            _error = '这台设备没有可用摄像头。\n可以改用「从相册选择」发给 AI。';
            _initializing = false;
          });
        }
        return;
      }
      _cameras = cams;
      if (_index >= cams.length) _index = 0;
      await _open(_index);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _error = _describe(e);
          _initializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '相机初始化失败：$e';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _open(int index) async {
    final old = _controller;
    _controller = null;
    await old?.dispose();

    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      try {
        await controller.setFlashMode(_flash);
      } catch (_) {
        // 前置摄像头通常没有闪光灯，忽略
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } on CameraException catch (e) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _error = _describe(e);
          _initializing = false;
        });
      }
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _taking) return;

    setState(() => _taking = true);
    try {
      final xfile = await c.takePicture();
      final raw = await xfile.readAsBytes();
      // 立刻压缩，避免大图在页面间传递时占内存
      final compressed = PhotoService.instance.compressJpeg(
        raw,
        maxSide: 1600,
        quality: 85,
      );
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(compressed);
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败：${e.description ?? e.code}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await c.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {
      // 该摄像头不支持闪光灯
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _index = (_index + 1) % _cameras.length;
    await _open(_index);
  }

  String _describe(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return '相机权限被拒绝。\n请到「系统设置 → 应用 → 计件助手 → 权限」里允许使用相机。';
      case 'cameraPermission':
        return '缺少相机权限。';
      default:
        return '相机错误（${e.code}）：${e.description ?? "未知原因"}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: _buildPreview()),
            // 顶部关闭
            Positioned(
              top: 6,
              left: 6,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withAlpha(70),
                ),
              ),
            ),
            // 底部操作条
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white54, size: 46),
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.6),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _initializing = true;
                  });
                  _setup();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final c = _controller;
    if (_initializing || c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    final previewSize = c.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(c);
    }

    // 竖屏：previewSize 的宽高需要交换后再等比裁切铺满
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(c),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final ready = _controller?.value.isInitialized ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _CircleIconButton(
          icon: _flash == FlashMode.off
              ? Icons.flash_off_rounded
              : Icons.flash_on_rounded,
          onTap: ready ? _toggleFlash : null,
        ),
        // 快门
        GestureDetector(
          onTap: ready && !_taking ? _capture : null,
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _taking ? Colors.white38 : Colors.white,
              ),
              child: _taking
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
        ),
        _CircleIconButton(
          icon: Icons.cameraswitch_outlined,
          onTap: ready && _cameras.length > 1 ? _switchCamera : null,
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withAlpha(90),
        ),
        child: Icon(
          icon,
          color: onTap == null ? Colors.white24 : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
