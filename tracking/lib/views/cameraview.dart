import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Add this for Ticker
import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Add this for min/max/clamp
import 'package:image/image.dart' as imglib;
import 'package:tracking/services/api_service.dart';
import 'package:flutter/foundation.dart'; // For compute function
import 'package:web_socket_channel/web_socket_channel.dart';

// ignore: use_key_in_widget_constructors
class CameraView extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final GlobalKey _previewKey = GlobalKey(); // Add preview key
  CameraController? _cameraController;
  late Future<void> _initializeControllerFuture;
  bool _isFlashOn = false;
  bool _isProcessing = false;
  final List<Map<String, dynamic>> _detections = [];
  int? _selectedTrackId;
  int _frameCount = 0;
  static const int _processEveryNFrames = 5; // Process every 5th frame
  WebSocketChannel? _liveBoxChannel;
  bool _wsActive = false;
  int _errorCount = 0;
  bool _showDebugInfo = false;
  final int _lastFrameId = 0;
  late Ticker _ticker;

  // Batch processing state
  final List<Uint8List> _frameBuffer = [];
  static const int _batchSize = 30; // Process 30 frames at once
  final DateTime _lastBatchTime = DateTime.now();
  static const Duration _minBatchInterval = Duration(seconds: 2);

  // Box interpolation state
  Map<int, Rect> _lastBoxes = {};
  final Map<int, Rect> _currentBoxes = {};
  final Map<int, Rect> _displayBoxes = {};
  DateTime _lastUpdate = DateTime.now();

  // Stats for debug overlay
  int _receivedFrames = 0;
  int _fps = 0;
  final DateTime _lastFpsUpdate = DateTime.now();

  bool _isCameraInitialized = false; // Added for robust initialization

  @override
  void initState() {
    super.initState();
    _errorCount = 0;
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _connectLiveBoxWebSocket();

    // Drive 60fps interpolation
    _ticker = createTicker((_) {
      final now = DateTime.now();
      final t =
          (now.difference(_lastUpdate).inMilliseconds / 200.0).clamp(0.0, 1.0);

      setState(() {
        _displayBoxes.clear();
        for (var id in _currentBoxes.keys) {
          final from = _lastBoxes[id] ?? _currentBoxes[id]!;
          final to = _currentBoxes[id]!;
          _displayBoxes[id] = Rect.lerp(from, to, t)!;
        }
      });
    });
    _ticker.start();

    // FPS counter
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _fps = _receivedFrames;
          _receivedFrames = 0;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state); // Call super
    if (!mounted) return; // Ensure widget is mounted

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController?.stopImageStream();
      _liveBoxChannel?.sink.close();
      _liveBoxChannel = null; // Explicitly nullify
      _wsActive = false;
      // Potentially set _isCameraInitialized = false; if you want full re-init on resume
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize camera if it's not already initialized or if controller is null
      if (_cameraController == null || !_isCameraInitialized) {
        _initializeCamera();
      } else {
        // If already initialized, just ensure the stream is running
        if (_cameraController != null &&
            _cameraController!.value.isInitialized &&
            !_cameraController!.value.isStreamingImages) {
          _cameraController!.startImageStream(_processCameraImage);
        }
      }
      if (!_wsActive) {
        // Reconnect WebSocket if it was closed
        _connectLiveBoxWebSocket();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _cameraController = null; // Explicitly nullify
    _liveBoxChannel?.sink.close();
    _liveBoxChannel = null; // Explicitly nullify
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_isCameraInitialized &&
        _cameraController?.value.isInitialized == true) {
      // Camera is already initialized and fine
      // Optionally, restart the stream if it was stopped
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          !_cameraController!.value.isStreamingImages) {
        await _cameraController!.startImageStream(_processCameraImage);
      }
      return;
    }

    try {
      // Stop any existing stream and dispose of the old controller FIRST
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose(); // Dispose the existing controller
        _cameraController = null; // Set to null after disposal
      }
      _isCameraInitialized = false; // Reset initialization status

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras found')),
          );
        }
        return;
      }

      final firstCamera = cameras.first;
      _cameraController = CameraController(
        firstCamera,
        ResolutionPreset.medium, // Better resolution for detection
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _initializeControllerFuture = _cameraController!.initialize();
      await _initializeControllerFuture;

      if (!mounted) {
        // Check if widget is still mounted AFTER await
        await _cameraController
            ?.dispose(); // Clean up if widget got unmounted during init
        _cameraController = null;
        return;
      }

      await _cameraController!.startImageStream(_processCameraImage);
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: ${e.toString()}')),
        );
      }
      // Ensure controller is null if initialization failed
      await _cameraController?.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
      if (mounted) setState(() {}); // Update UI to reflect error state
    }
  }

  void _connectLiveBoxWebSocket() async {
    try {
      // Add try-catch for WebSocket connection
      _liveBoxChannel =
          await ApiService.getWSConnection(); // Use existing method
      _wsActive = true; // Assume active if connection is successful
      if (!mounted) return;
      setState(() {}); // Update UI

      _liveBoxChannel!.stream.listen(
        (message) {
          if (!mounted) return; // Check mounted before processing message

          try {
            // Add try-catch for robust parsing
            final data = jsonDecode(message);
            // Expect "type": "track" and "boxes": [...]
            if (data['type'] != 'track' || data['boxes'] == null) {
              print("Received_unknown_message_type_or_missing_boxes: $data");
              return;
            }

            // Ensure previewKey.currentContext is not null
            if (_previewKey.currentContext == null) {
              print("PreviewKey context is null, cannot get dimensions.");
              return;
            }
            final renderBox = _previewKey.currentContext!.findRenderObject()
                as RenderBox?; // Nullable

            if (renderBox == null || renderBox.size.isEmpty) {
              print("RenderBox is null or size is empty.");
              return;
            }
            final w = renderBox.size.width;
            final h = renderBox.size.height;

            final List frameBoxes =
                data['boxes'] as List? ?? []; // data['boxes'] is the list

            _lastBoxes = Map.from(_currentBoxes); // For interpolation
            _currentBoxes.clear();
            for (var b in frameBoxes) {
              if (b is! Map) continue; // Ensure b is a map

              final id = b['id'] as int?;
              final x1 = b['x1'] as double?;
              final y1 = b['y1'] as double?;
              final x2 = b['x2'] as double?;
              final y2 = b['y2'] as double?;
              // final conf = b['conf'] as double?; // Confidence available if needed

              if (id != null &&
                  x1 != null &&
                  y1 != null &&
                  x2 != null &&
                  y2 != null) {
                _currentBoxes[id] =
                    Rect.fromLTRB(x1 * w, y1 * h, x2 * w, y2 * h);
              }
            }
            _lastUpdate = DateTime.now(); // For interpolation
            if (mounted) setState(() {}); // Update UI
          } catch (e, s) {
            print("Error_processing_WebSocket_message: $e");
            print("Stack_trace: $s");
            // Optionally, can add logic to show an error to the user or try to handle
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          if (mounted) {
            setState(() {
              _wsActive = false;
              // Optionally show error to user or attempt reconnect
            });
          }
          _liveBoxChannel?.sink.close(); // Close on error
          _liveBoxChannel = null;
          _wsActive = false;
          // Simple reconnect delay
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && !_wsActive) _connectLiveBoxWebSocket();
          });
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _wsActive = false;
            });
          }
          print('WebSocket connection closed by server.');
          // Attempt to reconnect if not intentionally closed by client
          if (mounted) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && !_wsActive) _connectLiveBoxWebSocket();
            });
          }
        },
        cancelOnError: true, // Close stream on error
      );
    } catch (e) {
      print("Failed to connect to WebSocket: $e");
      if (mounted) {
        setState(() {
          _wsActive = false;
        });
        // Simple reconnect delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_wsActive) _connectLiveBoxWebSocket();
        });
      }
    }
  }

  // This function will be run in a separate isolate
  static Future<Uint8List> _yuvToJpegIsolate(CameraImage image) async {
    final width = image.width;
    final height = image.height;
    final img = imglib.Image(width: width, height: height);

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride =
        image.planes[1].bytesPerPixel ?? 1; // Handle null bytesPerPixel

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;

        // Ensure yIndex is within bounds for yPlane
        if (yIndex >= yPlane.length) continue;
        final yp = yPlane[yIndex];

        // Calculate UV plane coordinates, ensuring they are within bounds
        final uvx = x ~/ 2;
        final uvy = y ~/ 2;
        final uvIndex = uvy * uvRowStride + uvx * uvPixelStride;

        // Ensure uvIndex is within bounds for uPlane and vPlane
        if (uvIndex >= uPlane.length || uvIndex >= vPlane.length) continue;
        final up = uPlane[uvIndex];
        final vp = vPlane[uvIndex];

        // Convert YUV to RGB
        int r = (yp + 1.370705 * (vp - 128)).round().clamp(0, 255);
        int g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128))
            .round()
            .clamp(0, 255);
        int b = (yp + 1.732446 * (up - 128)).round().clamp(0, 255);

        img.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return Uint8List.fromList(imglib.encodeJpg(img));
  }

  void _processCameraImage(CameraImage image) async {
    if (!mounted ||
        _isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        !_isCameraInitialized) {
      return;
    }

    _frameCount++;
    if (_frameCount % _processEveryNFrames != 0) return;

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    try {
      print('[Camera] Processing frame $_frameCount');
      // Ensure camera is still available and streaming before heavy work
      if (!_cameraController!.value.isStreamingImages || !mounted) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final jpegBytes = await compute(_yuvToJpegIsolate, image);
      _receivedFrames++; // For FPS counter

      if (!mounted ||
          _cameraController == null ||
          !_cameraController!.value.isInitialized ||
          !_isCameraInitialized) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      if (_liveBoxChannel != null && _wsActive) {
        print('[Camera] Sending frame $_frameCount to server');
        _liveBoxChannel!.sink.add(jpegBytes);
      } else {
        print("[Camera] WebSocket not active, cannot send frame.");
        // Optionally, attempt to reconnect if ws is not active
        if (mounted && !_wsActive) _connectLiveBoxWebSocket();
      }
    } catch (e) {
      print(
          '[Camera] Error processing camera image or sending to WebSocket: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;

    _isFlashOn
        ? await _cameraController!.setFlashMode(FlashMode.off)
        : await _cameraController!.setFlashMode(FlashMode.torch);

    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _onDetectionTap(int trackId) {
    setState(() {
      _selectedTrackId = trackId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Camera Tracking'),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: Icon(_showDebugInfo ? Icons.info : Icons.info_outline),
            onPressed: () {
              setState(() {
                _showDebugInfo = !_showDebugInfo;
              });
            },
          ),
        ],
      ),
      body: _cameraController == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
                    children: [
                      // Camera Preview with correct aspect ratio
                      Center(
                        child: _cameraController != null &&
                                _cameraController!.value.isInitialized
                            ? AspectRatio(
                                aspectRatio:
                                    _cameraController!.value.aspectRatio,
                                child: CameraPreview(_cameraController!,
                                    key: _previewKey),
                              )
                            : const SizedBox(),
                      ),
                      // Bounding Boxes
                      CustomPaint(
                        painter: BoundingBoxPainter(
                          _displayBoxes.values.toList(),
                          previewSize: (_previewKey.currentContext
                                  ?.findRenderObject() as RenderBox?)
                              ?.size,
                        ),
                        size: Size.infinite,
                      ),
                      // Debug info overlay
                      if (_showDebugInfo)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.black54,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WebSocket: [32m${_wsActive ? "Connected" : "Disconnected"}[0m',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  'FPS: $_fps',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  'Frame ID: $_lastFrameId',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  'Active Tracks: ${_currentBoxes.length}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Processing indicator
                      if (_isProcessing)
                        const Positioned(
                          bottom: 20,
                          right: 20,
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Rect> boxes;
  final Size? previewSize;

  BoundingBoxPainter(this.boxes, {this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    if (previewSize == null || previewSize!.isEmpty) {
      for (var rect in boxes) {
        canvas.drawRect(rect, paint);
      }
      return;
    }

    final offsetX = (size.width - previewSize!.width) / 2;
    final offsetY = (size.height - previewSize!.height) / 2;

    for (var rectInPreviewCoordinates in boxes) {
      final rectInStackCoordinates =
          rectInPreviewCoordinates.translate(offsetX, offsetY);
      canvas.drawRect(rectInStackCoordinates, paint);
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) =>
      boxes != oldDelegate.boxes || previewSize != oldDelegate.previewSize;
}
