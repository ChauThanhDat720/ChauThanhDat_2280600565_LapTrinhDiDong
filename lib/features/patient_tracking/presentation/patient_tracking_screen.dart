import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/tracked_object.dart';

class PatientTrackingScreen extends StatefulWidget {
  const PatientTrackingScreen({super.key});

  @override
  State<PatientTrackingScreen> createState() => _PatientTrackingScreenState();
}

class _PatientTrackingScreenState extends State<PatientTrackingScreen>
    with WidgetsBindingObserver {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );

  CameraController? _cameraController;
  CameraDescription? _camera;
  List<TrackedObject> _trackedObjects = const [];
  List<TrackedObject> _previousPeople = const [];
  int _nextPersonId = 1;
  Size? _imageSize;
  bool _isProcessing = false;
  bool _initializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCameras = cameras.where(
        (item) => item.lensDirection == CameraLensDirection.back,
      );
      _camera = backCameras.isNotEmpty
          ? backCameras.first
          : cameras.isEmpty
          ? null
          : cameras.first;
      if (_camera == null) {
        throw CameraException('camera_not_found', 'Không tìm thấy camera.');
      }

      final controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      await controller.startImageStream(_processCameraImage);
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _initializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = error.code == 'CameraAccessDenied'
            ? 'Ứng dụng cần quyền camera để theo dõi đối tượng.'
            : 'Không thể mở camera. Vui lòng thử lại.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = 'Không thể mở camera. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || !mounted) return;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;

    _isProcessing = true;
    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (!mounted) return;

      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        _trackedObjects = _peopleFromPoses(poses);
        _previousPeople = _trackedObjects;
      });
    } catch (_) {
      // Frames can be dropped while the camera is changing state.
    } finally {
      _isProcessing = false;
    }
  }

  List<TrackedObject> _peopleFromPoses(List<Pose> poses) {
    final people = <TrackedObject>[];

    for (final pose in poses) {
      final landmarks = pose.landmarks.values
          .where((landmark) => landmark.likelihood >= 0.45)
          .toList();
      // A few isolated landmarks are not enough to form a reliable person box.
      if (landmarks.length < 4) continue;

      final minX = landmarks.map((landmark) => landmark.x).reduce(_min);
      final maxX = landmarks.map((landmark) => landmark.x).reduce(_max);
      final minY = landmarks.map((landmark) => landmark.y).reduce(_min);
      final maxY = landmarks.map((landmark) => landmark.y).reduce(_max);
      final bodyHeight = maxY - minY;
      final bodyWidth = maxX - minX;
      if (bodyHeight < 40 || bodyWidth < 18) continue;

      // Pose landmarks sit inside the body. Padding makes the rectangle cover
      // the person without expanding enough to include nearby objects.
      final paddingX = bodyWidth * 0.20 + 12;
      final paddingY = bodyHeight * 0.10 + 10;
      final imageSize = _imageSize;
      final box = Rect.fromLTRB(
        (minX - paddingX).clamp(0.0, imageSize?.width ?? minX).toDouble(),
        (minY - paddingY).clamp(0.0, imageSize?.height ?? minY).toDouble(),
        (maxX + paddingX).clamp(0.0, imageSize?.width ?? maxX).toDouble(),
        (maxY + paddingY).clamp(0.0, imageSize?.height ?? maxY).toDouble(),
      );

      people.add(
        TrackedObject(id: _idFor(box), boundingBox: box, label: 'Người'),
      );
    }
    return people;
  }

  int _idFor(Rect candidate) {
    final center = candidate.center;
    TrackedObject? closest;
    var closestDistance = double.infinity;
    for (final person in _previousPeople) {
      final distance = (person.boundingBox.center - center).distance;
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = person;
      }
    }

    final threshold = candidate.longestSide * 0.70 + 80;
    return closest != null && closestDistance < threshold
        ? closest.id
        : _nextPersonId++;
  }

  double _min(double left, double right) => left < right ? left : right;

  double _max(double left, double right) => left > right ? left : right;

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_camera == null || image.planes.length != 1) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || format != InputImageFormat.nv21) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      _camera!.sensorOrientation,
    );
    if (rotation == null) return null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Theo dõi đối tượng',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PrivacyNotice(),
            const SizedBox(height: 18),
            Expanded(child: _buildCameraContent()),
            const SizedBox(height: 14),
            Text(
              _trackedObjects.isEmpty
                  ? 'Chưa phát hiện người trong khung hình'
                  : 'Đang theo dõi ${_trackedObjects.length} người',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildCameraContent() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _CameraError(message: _errorMessage!, onRetry: _initializeCamera);
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          // Give the preview and painter identical bounds. This prevents the
          // overlay from being stretched when a device has a different ratio.
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                if (_imageSize != null)
                  CustomPaint(
                    painter: _TrackingOverlayPainter(
                      objects: _trackedObjects,
                      imageSize: _imageSize!,
                      rotation: InputImageRotationValue.fromRawValue(
                        _camera!.sensorOrientation,
                      )!,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFE4F4F5),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Chỉ dùng khi bệnh nhân đã đồng ý. Camera chỉ khoanh vùng cơ thể người, không nhận diện khuôn mặt. Khung và ID là tạm thời; không lưu hay gửi dữ liệu.',
            style: TextStyle(height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_off_rounded, size: 64),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

class _TrackingOverlayPainter extends CustomPainter {
  const _TrackingOverlayPainter({
    required this.objects,
    required this.imageSize,
    required this.rotation,
  });

  final List<TrackedObject> objects;
  final Size imageSize;
  final InputImageRotation rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final object in objects) {
      final box = _mapBox(object.boundingBox, size);
      canvas.drawRect(box, borderPaint);

      final label = 'ID ${object.id} • ${object.label}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      final labelTop = (box.top - textPainter.height - 6)
          .clamp(0.0, size.height)
          .toDouble();
      final labelRect = Rect.fromLTWH(
        box.left.clamp(0.0, size.width - textPainter.width - 10).toDouble(),
        labelTop,
        textPainter.width + 10,
        textPainter.height + 6,
      );
      canvas.drawRect(labelRect, Paint()..color = const Color(0xFF00E5FF));
      textPainter.paint(canvas, Offset(labelRect.left + 5, labelRect.top + 3));
    }
  }

  Rect _mapBox(Rect box, Size canvasSize) {
    final corners = [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ].map(_rotatePoint).map((point) => _scalePoint(point, canvasSize)).toList();
    final left = corners.map((point) => point.dx).reduce(_min);
    final right = corners.map((point) => point.dx).reduce(_max);
    final top = corners.map((point) => point.dy).reduce(_min);
    final bottom = corners.map((point) => point.dy).reduce(_max);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Offset _rotatePoint(Offset point) => switch (rotation) {
    InputImageRotation.rotation0deg => point,
    InputImageRotation.rotation90deg => Offset(
      imageSize.height - point.dy,
      point.dx,
    ),
    InputImageRotation.rotation180deg => Offset(
      imageSize.width - point.dx,
      imageSize.height - point.dy,
    ),
    InputImageRotation.rotation270deg => Offset(
      point.dy,
      imageSize.width - point.dx,
    ),
  };

  Offset _scalePoint(Offset point, Size canvasSize) {
    final rotatedSize = switch (rotation) {
      InputImageRotation.rotation0deg ||
      InputImageRotation.rotation180deg => imageSize,
      InputImageRotation.rotation90deg || InputImageRotation.rotation270deg =>
        Size(imageSize.height, imageSize.width),
    };
    return Offset(
      point.dx * canvasSize.width / rotatedSize.width,
      point.dy * canvasSize.height / rotatedSize.height,
    );
  }

  double _min(double left, double right) => left < right ? left : right;

  double _max(double left, double right) => left > right ? left : right;

  @override
  bool shouldRepaint(_TrackingOverlayPainter oldDelegate) =>
      oldDelegate.objects != objects ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.rotation != rotation;
}
