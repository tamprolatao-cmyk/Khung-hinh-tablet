import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ControlScreen(),
  ));
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FloatingPhotoWidget(),
  ));
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  String? _selectedFolder;
  double _intervalSeconds = 5;
  double _frameSize = 450;

  Future<void> _pickFolder() async {
    await [Permission.photos, Permission.storage].request();
    String? path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      setState(() => _selectedFolder = path);
    }
  }

  Future<void> _startOverlay() async {
    if (_selectedFolder == null) return;

    bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      status = await FlutterOverlayWindow.requestPermission() ?? false;
      if (!status) return;
    }

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "Khung Ảnh Nổi",
      overlayContent: "Đang trình chiếu...",
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      height: _frameSize.toInt(),
      width: _frameSize.toInt(),
    );

    await Future.delayed(const Duration(milliseconds: 600));
    await FlutterOverlayWindow.shareData({
      'folder': _selectedFolder,
      'seconds': _intervalSeconds.toInt(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khung Ảnh Nổi')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Chọn thư mục chứa ảnh'),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFolder ?? 'Chưa chọn thư mục nào',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text('Thời gian chuyển ảnh: ${_intervalSeconds.toInt()} giây'),
            Slider(
              value: _intervalSeconds,
              min: 2,
              max: 60,
              divisions: 58,
              onChanged: (val) => setState(() => _intervalSeconds = val),
            ),
            const SizedBox(height: 12),
            Text('Kích thước khung: ${_frameSize.toInt()} px'),
            Slider(
              value: _frameSize,
              min: 250,
              max: 800,
              divisions: 11,
              onChanged: (val) => setState(() => _frameSize = val),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _selectedFolder == null ? null : _startOverlay,
              child: const Text('BẬT KHUNG ẢNH NỔI'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => FlutterOverlayWindow.closeOverlay(),
              child: const Text('TẮT KHUNG ẢNH'),
            ),
          ],
        ),
      ),
    );
  }
}

class FloatingPhotoWidget extends StatefulWidget {
  const FloatingPhotoWidget({super.key});

  @override
  State<FloatingPhotoWidget> createState() => _FloatingPhotoWidgetState();
}

class _FloatingPhotoWidgetState extends State<FloatingPhotoWidget> {
  List<File> _images = [];
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        _loadImages(data['folder'], data['seconds']);
      }
    });
  }

  void _loadImages(String folderPath, int seconds) {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return;

    final files = dir.listSync().whereType<File>().where((f) {
      final ext = f.path.toLowerCase();
      return ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.png') ||
          ext.endsWith('.webp');
    }).toList();

    if (files.isEmpty) return;

    setState(() {
      _images = files;
      _currentIndex = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (_images.isNotEmpty) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _images.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onDoubleTap: () => FlutterOverlayWindow.closeOverlay(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
          ),
          clipBehavior: Clip.antiAlias,
          child: _images.isEmpty
              ? const Center(
                  child: Text(
                    'Đang tải ảnh...',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Image.file(
                    _images[_currentIndex],
                    key: ValueKey(_images[_currentIndex].path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
        ),
      ),
    );
  }
}
