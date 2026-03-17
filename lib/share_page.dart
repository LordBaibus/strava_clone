import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_min_gpl/return_code.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:video_player/video_player.dart';

class SharePage extends StatefulWidget {
  final Map<String, dynamic> activity;
  const SharePage({super.key, required this.activity});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  File? _bgImage;
  File? _bgVideo;
  VideoPlayerController? _videoCtrl;

  final GlobalKey _fullPreviewKey = GlobalKey();
  final GlobalKey _overlayOnlyKey = GlobalKey();

  late final double _distanceKm;
  late final String _avgPace;
  late final String _timeText;
  late final List<LatLng> _route;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();

    _distanceKm = (widget.activity['distanceKm'] is num)
        ? (widget.activity['distanceKm'] as num).toDouble()
        : 0.0;

    _avgPace = (widget.activity['avgPace'] is String &&
        (widget.activity['avgPace'] as String).isNotEmpty)
        ? widget.activity['avgPace'] as String
        : _calcPaceFallback(widget.activity);

    final secs = (widget.activity['durationSeconds'] is int)
        ? widget.activity['durationSeconds'] as int
        : 0;
    _timeText = _formatTime(secs);

    _route = _decodeRoute(widget.activity['route']);
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return "${seconds}s";
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    if (h > 0) {
      return "${h}h ${m.toString().padLeft(2, '0')}m";
    }
    return "${m}m ${s.toString().padLeft(2, '0')}s";
  }

  String _calcPaceFallback(Map<String, dynamic> a) {
    final dist =
    (a['distanceKm'] is num) ? (a['distanceKm'] as num).toDouble() : 0.0;
    final secs = (a['durationSeconds'] is int) ? a['durationSeconds'] as int : 0;
    if (dist <= 0 || secs <= 0) return "-:--";
    final minPerKm = (secs / 60.0) / dist;
    int mins = minPerKm.floor();
    int s = ((minPerKm - mins) * 60).round();
    if (s == 60) {
      mins += 1;
      s = 0;
    }
    return "$mins:${s.toString().padLeft(2, '0')}";
  }

  List<LatLng> _decodeRoute(dynamic raw) {
    final out = <LatLng>[];
    if (raw is! List) return out;
    for (final p in raw) {
      if (p is List && p.length >= 2) {
        out.add(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
    }
    return out;
  }

  Future<void> _pickBackground() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text("Background"),
        message: Text(
          _isDesktop
              ? "On desktop, choose a file (camera isn't supported)."
              : "Pick an image/video background.",
        ),
        actions: [
          if (!_isDesktop)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(context);
                await _pickImageMobile(ImageSource.camera);
              },
              child: const Text("Take Photo (Camera)"),
            ),
          if (!_isDesktop)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(context);
                await _pickVideoMobile(ImageSource.camera);
              },
              child: const Text("Record Video (Camera)"),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _pickImage();
            },
            child: Text(
              _isDesktop ? "Choose Photo (File)" : "Choose Photo (Gallery)",
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _pickVideo();
            },
            child: Text(
              _isDesktop ? "Choose Video (File)" : "Choose Video (Gallery)",
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      await Future.delayed(const Duration(milliseconds: 150));

      if (_isDesktop) {
        final res = await FilePicker.platform.pickFiles(type: FileType.image);
        final path = res?.files.single.path;
        if (path == null) return;
        await _setBackgroundImage(File(path));
        return;
      }

      final xf =
      await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (xf == null) return;
      await _setBackgroundImage(File(xf.path));
    } catch (e) {
      debugPrint("pick image error: $e");
      _toast("Failed to pick image.\n$e");
    }
  }

  Future<void> _pickVideo() async {
    try {
      await Future.delayed(const Duration(milliseconds: 150));

      if (_isDesktop) {
        final res = await FilePicker.platform.pickFiles(type: FileType.video);
        final path = res?.files.single.path;
        if (path == null) return;
        await _setBackgroundVideo(File(path));
        return;
      }

      final xf = await _picker.pickVideo(source: ImageSource.gallery);
      if (xf == null) return;
      await _setBackgroundVideo(File(xf.path));
    } catch (e) {
      debugPrint("pick video error: $e");
      _toast("Failed to pick video.\n$e");
    }
  }

  Future<void> _pickImageMobile(ImageSource src) async {
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      final xf = await _picker.pickImage(source: src, imageQuality: 92);
      if (xf == null) return;
      await _setBackgroundImage(File(xf.path));
    } catch (e) {
      debugPrint("camera image error: $e");
      _toast("Camera failed.\n$e");
    }
  }

  Future<void> _pickVideoMobile(ImageSource src) async {
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      final xf = await _picker.pickVideo(source: src);
      if (xf == null) return;
      await _setBackgroundVideo(File(xf.path));
    } catch (e) {
      debugPrint("camera video error: $e");
      _toast("Camera failed.\n$e");
    }
  }

  Future<void> _setBackgroundImage(File file) async {
    await _videoCtrl?.dispose();
    _videoCtrl = null;

    if (!mounted) return;
    setState(() {
      _bgVideo = null;
      _bgImage = file;
    });
  }

  Future<void> _setBackgroundVideo(File file) async {
    await _videoCtrl?.dispose();

    final c = VideoPlayerController.file(file);
    await c.initialize();
    await c.setLooping(true);
    await c.play();

    if (!mounted) {
      await c.dispose();
      return;
    }

    setState(() {
      _bgImage = null;
      _bgVideo = file;
      _videoCtrl = c;
    });
  }

  Future<String> _captureKeyToPngFile(
      GlobalKey key, {
        double pixelRatio = 2.0,
      }) async {
    await Future.delayed(const Duration(milliseconds: 80));
    await WidgetsBinding.instance.endOfFrame;

    final context = key.currentContext;
    if (context == null) {
      throw Exception("Capture failed: widget context is null.");
    }

    final renderObject = context.findRenderObject();
    if (renderObject == null || renderObject is! RenderRepaintBoundary) {
      throw Exception("Capture failed: repaint boundary not found.");
    }

    if (renderObject.debugNeedsPaint) {
      await Future.delayed(const Duration(milliseconds: 50));
      await WidgetsBinding.instance.endOfFrame;
    }

    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception("Capture failed: PNG byte data is null.");
    }

    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.png";

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      if (_isDesktop) {
        if (_bgVideo != null) {
          _toast(
            "Video export is not supported on desktop in your current build. Only PNG export works.",
          );
          return;
        }

        await Future.delayed(const Duration(milliseconds: 150));
        await WidgetsBinding.instance.endOfFrame;

        final outPng = await _captureKeyToPngFile(_fullPreviewKey);
        final downloads = await getDownloadsDirectory();
        final baseDir = downloads ?? await getApplicationDocumentsDirectory();

        final filename = "strava_share_${DateTime.now().millisecondsSinceEpoch}.png";
        final dest = File("${baseDir.path}/$filename");

        await File(outPng).copy(dest.path);
        _toast("Saved PNG:\n${dest.path}");
        return;
      }

      final permission = await pm.PhotoManager.requestPermissionExtend();
      debugPrint(
        "Photo permission -> isAuth: ${permission.isAuth}, hasAccess: ${permission.hasAccess}",
      );

      if (!(permission.isAuth || permission.hasAccess)) {
        _toast("Photos permission denied.");
        return;
      }

      if (_bgVideo == null) {
        await Future.delayed(const Duration(milliseconds: 150));
        await WidgetsBinding.instance.endOfFrame;

        final outPng =
        await _captureKeyToPngFile(_fullPreviewKey, pixelRatio: 2.0);

        final pngFile = File(outPng);
        final exists = await pngFile.exists();
        if (!exists) {
          _toast("Capture failed. PNG file was not created.");
          return;
        }

        final bytes = await pngFile.readAsBytes();
        if (bytes.isEmpty) {
          _toast("Capture failed. PNG file is empty.");
          return;
        }

        debugPrint("Captured PNG path: $outPng");
        debugPrint("Captured PNG bytes: ${bytes.length}");

        final stamp = DateTime.now().millisecondsSinceEpoch;

        try {
          final saved = await pm.PhotoManager.editor.saveImage(
            bytes,
            title: "strava_share_$stamp.png",
            filename: "strava_share_$stamp.png",
          );

          debugPrint("saveImage result: $saved");

          if (saved != null) {
            _toast("Saved image to Photos/Gallery.");
            return;
          }
        } catch (e, st) {
          debugPrint("PhotoManager saveImage error: $e");
          debugPrint("$st");
        }

        final docs = await getApplicationDocumentsDirectory();
        final fallbackPath = "${docs.path}/strava_share_$stamp.png";
        final fallbackFile = await pngFile.copy(fallbackPath);

        _toast("Gallery save failed.\nSaved locally instead:\n${fallbackFile.path}");
        return;
      }

      if (_videoCtrl != null && _videoCtrl!.value.isPlaying) {
        await _videoCtrl!.pause();
      }

      await Future.delayed(const Duration(milliseconds: 120));
      await WidgetsBinding.instance.endOfFrame;

      if (_overlayOnlyKey.currentContext == null) {
        _toast("Overlay is not ready yet. Try again.");
        return;
      }

      final overlayPng = await _captureKeyToPngFile(
        _overlayOnlyKey,
        pixelRatio: 2.0,
      );

      final inVideo = _bgVideo!.path;
      final dir = await getTemporaryDirectory();
      final outVideo = "${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.mp4";

      final cmd = '-y '
          '-i "$inVideo" '
          '-i "$overlayPng" '
          '-filter_complex "[1:v][0:v]scale2ref=flags=lanczos[ov][base];[base][ov]overlay=0:0" '
          '-map 0:v:0 -map 0:a? '
          '-c:v libx264 '
          '-preset ultrafast '
          '-crf 20 '
          '-pix_fmt yuv420p '
          '-c:a aac '
          '-b:a 128k '
          '-movflags +faststart '
          '"$outVideo"';

      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        _toast("Video export failed. FFmpeg did not finish successfully.");
        return;
      }

      final outputFile = File(outVideo);
      if (!await outputFile.exists()) {
        _toast("Video export failed. Output file was not created.");
        return;
      }

      final fileSize = await outputFile.length();
      if (fileSize <= 0) {
        _toast("Video export failed. Output file is empty.");
        return;
      }

      final savedVideo = await pm.PhotoManager.editor.saveVideo(
        outputFile,
        title: "strava_share_${DateTime.now().millisecondsSinceEpoch}.mp4",
      );

      _toast(
        savedVideo != null
            ? "Saved video to Photos/Gallery."
            : "Export succeeded, but saving to Photos failed.",
      );
    } catch (e, st) {
      debugPrint("Save error: $e");
      debugPrint("$st");
      _toast("Save failed.\n$e");
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Done"),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageBg = Color(0xFFF3F3F3);

    final overlay = _ShareOverlay(
      distanceKm: _distanceKm,
      pace: _avgPace,
      time: _timeText,
      route: _route,
    );

    return CupertinoPageScaffold(
      backgroundColor: pageBg,
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Share Activity"),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            const side = 16.0;
            const topGap = 14.0;
            const btnH = 54.0;
            const bottomPad = 18.0;
            const btnRowTopPad = 8.0;

            final maxW = math.min(420.0, c.maxWidth - side * 2);
            final maxPreviewH = math.max(
              320.0,
              c.maxHeight - (topGap + btnRowTopPad + btnH + bottomPad + 24),
            );

            final previewW = math.min(maxW, maxPreviewH * 9 / 16);
            final previewH = previewW * 16 / 9;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(side, topGap, side, bottomPad),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: c.maxHeight - topGap - bottomPad,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: SizedBox(
                        width: previewW,
                        height: previewH,
                        child: RepaintBoundary(
                          key: _fullPreviewKey,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _BackgroundView(
                                  image: _bgImage,
                                  videoCtrl: _videoCtrl,
                                ),
                                overlay,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(
                      width: 1,
                      height: 1,
                      child: OverflowBox(
                        maxWidth: previewW,
                        maxHeight: previewH,
                        child: RepaintBoundary(
                          key: _overlayOnlyKey,
                          child: SizedBox(
                            width: previewW,
                            height: previewH,
                            child: overlay,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickBackground,
                            child: Container(
                              height: btnH,
                              decoration: BoxDecoration(
                                color: CupertinoColors.black,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Center(
                                child: Text(
                                  "Background",
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isSaving ? null : _save,
                            child: Opacity(
                              opacity: _isSaving ? 0.7 : 1,
                              child: Container(
                                height: btnH,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.activeOrange,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Center(
                                  child: _isSaving
                                      ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                  )
                                      : const Text(
                                    "Save",
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BackgroundView extends StatelessWidget {
  final File? image;
  final VideoPlayerController? videoCtrl;

  const _BackgroundView({
    required this.image,
    required this.videoCtrl,
  });

  @override
  Widget build(BuildContext context) {
    if (videoCtrl != null && videoCtrl!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: videoCtrl!.value.size.width,
          height: videoCtrl!.value.size.height,
          child: VideoPlayer(videoCtrl!),
        ),
      );
    }

    if (image != null && image!.existsSync()) {
      return Image.file(image!, fit: BoxFit.cover);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF101010)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _ShareOverlay extends StatelessWidget {
  final double distanceKm;
  final String pace;
  final String time;
  final List<LatLng> route;

  const _ShareOverlay({
    required this.distanceKm,
    required this.pace,
    required this.time,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final logoTop = h * 0.035;
        final contentTop = h * 0.09;
        final routeBox = math.max(90.0, math.min(160.0, h * 0.24));
        final distanceValue = math.max(24.0, math.min(48.0, h * 0.075));
        final metricTitle = math.max(14.0, math.min(22.0, h * 0.034));
        final paceValue = math.max(24.0, math.min(44.0, h * 0.068));
        final timeValue = math.max(22.0, math.min(44.0, h * 0.068));
        final bottomBrand = math.max(18.0, math.min(34.0, h * 0.05));

        return Stack(
          children: [
            Positioned(
              top: logoTop,
              left: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.65),
                    width: 1,
                  ),
                ),
                child: const Text(
                  "STRAVA",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, contentTop, 20, 20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Distance",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: metricTitle,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "${distanceKm.toStringAsFixed(2)} km",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: distanceValue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          "Pace",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: metricTitle,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "$pace /km",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: paceValue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          "Time",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: metricTitle,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          time,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: timeValue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: routeBox,
                          height: routeBox,
                          child: CustomPaint(
                            painter: _ShareRoutePainter(route: route),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          "STRAVA",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: bottomBrand,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShareRoutePainter extends CustomPainter {
  final List<LatLng> route;
  _ShareRoutePainter({required this.route});

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;

    double minLat = route.first.latitude, maxLat = route.first.latitude;
    double minLng = route.first.longitude, maxLng = route.first.longitude;

    for (final p in route) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final safeLat = latSpan == 0 ? 1e-9 : latSpan;
    final safeLng = lngSpan == 0 ? 1e-9 : lngSpan;

    final pad = 12.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final scale = math.min(w, h);

    Offset mapPoint(LatLng p) {
      final x = (p.longitude - minLng) / safeLng;
      final y = (maxLat - p.latitude) / safeLat;
      return Offset(
        pad + x * scale + (w - scale) / 2,
        pad + y * scale + (h - scale) / 2,
      );
    }

    final path = ui.Path();
    final first = mapPoint(route.first);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < route.length; i++) {
      final o = mapPoint(route[i]);
      path.lineTo(o.dx, o.dy);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = CupertinoColors.activeOrange;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ShareRoutePainter oldDelegate) {
    return oldDelegate.route != route;
  }
}