import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:tracking/services/api_service.dart';

class Videoimagecont extends StatefulWidget {
  const Videoimagecont({super.key});

  @override
  _VideoimagecontState createState() => _VideoimagecontState();
}

class _VideoimagecontState extends State<Videoimagecont> {
  File? _selectedFile;
  bool _isProcessing = false;
  Widget? _processedContent;
  String? _processingError;
  int _skipFrames = 0; // Default to process all frames
  double _processingProgress = 0.0; // Track processing progress
  bool _isCancelled = false; // Track if processing was cancelled
  String? _errorMessage;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<bool> _isValidVideoFile(File file) async {
    try {
      print('Validating video file: ${file.path}');

      // Check if file exists
      if (!await file.exists()) {
        print('Video file does not exist');
        return false;
      }

      // Check file size
      final fileSize = await file.length();
      if (fileSize == 0) {
        print('Video file is empty');
        return false;
      }

      print('Video file is valid ($fileSize bytes)');
      return true;
    } catch (e) {
      print('Error validating video file: $e');
      return false;
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? videoFile =
        await picker.pickVideo(source: ImageSource.gallery);

    if (videoFile != null) {
      final file = File(videoFile.path);

      // Validate the video file before processing
      if (!await _isValidVideoFile(file)) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid video file. Please try another video.';
          });
        }
        return;
      }

      setState(() {
        _selectedFile = file;
        _processedContent = null;
        _processingError = null;
        _errorMessage = null;
      });

      // Process the video
      await _processVideo(_selectedFile!);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imageFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (imageFile != null) {
      setState(() {
        _selectedFile = File(imageFile.path);
        _processedContent = null;
        _processingError = null;
      });

      // Process the image
      await _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_selectedFile == null) return;

    setState(() {
      _isProcessing = true;
      _processingError = null;
    });

    try {
      final bytes = await ApiService.processImage(_selectedFile!);

      if (bytes != null && mounted) {
        setState(() {
          _processedContent = Image.memory(
            bytes,
            fit: BoxFit.contain,
          );
          _isProcessing = false;
        });
      } else {
        setState(() {
          _processingError = 'Failed to process image';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processingError = 'Error: $e';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processVideo(File videoFile) async {
    if (_isProcessing) return;

    // Clean up previous controllers
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _errorMessage = null;
      _isCancelled = false;
      _processedContent = null;
    });

    try {
      print('Starting video processing in Videoimagecont');

      // Show processing indicator with current skip frame setting
      setState(() {
        _processedContent = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              'Processing video${_skipFrames > 0 ? ' (Processing every ${_skipFrames + 1} frames)' : ''}...',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        );
      });

      final processedFile = await ApiService.processVideo(
        videoFile,
        onProgress: (progress) {
          if (_isCancelled) return;
          setState(() {
            _processingProgress = progress;
          });
        },
        skipFrames: _skipFrames,
      );

      if (_isCancelled) {
        print('Video processing was cancelled');
        _handleError('Processing cancelled by user');
        return;
      }

      if (processedFile == null) {
        _handleError('Failed to process video - no file returned');
        return;
      }

      print('Video processed successfully, initializing player');

      // Verify the file exists and is readable
      if (!await processedFile.exists()) {
        _handleError(
            'Processed video file not found at: ${processedFile.path}');
        return;
      }

      // Check if video file is valid (not empty)
      if (await processedFile.length() < 1000) {
        _handleError('Processed video is too small or invalid.');
        return;
      }

      // Initialize video player with error handling
      VideoPlayerController controller;
      try {
        print('Creating VideoPlayerController...');
        controller = VideoPlayerController.file(processedFile);
        print('Initializing VideoPlayerController...');
        await controller.initialize();
        print('VideoPlayerController initialized successfully');
      } catch (e) {
        print('⚠️ Video player initialization failed: $e');
        _handleError('Failed to initialize video player',
            exception: e as Exception);
        return;
      }

      if (!mounted) {
        print('Widget not mounted, disposing controller');
        controller.dispose();
        return;
      }

      // Create Chewie controller with error handling
      ChewieController chewieController;
      try {
        print('Creating ChewieController...');
        chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: true,
          aspectRatio: controller.value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                'Error: $errorMessage',
                style: const TextStyle(color: Colors.red),
              ),
            );
          },
        );
        print('ChewieController created successfully');
      } catch (e) {
        print('⚠️ ChewieController creation failed: $e');
        controller.dispose();
        _handleError('Failed to create video player UI',
            exception: e as Exception);
        return;
      }

      // Always clear the loading state, even if initialization failed
      if (mounted) {
        setState(() {
          _videoPlayerController = controller;
          _chewieController = chewieController;
          _processedContent = Chewie(controller: chewieController);
          _isProcessing = false;
          _errorMessage = null;
        });
        print('Video player setup complete');
      }
    } catch (e, stackTrace) {
      print('Error processing video: $e');
      print('Stack trace: $stackTrace');
      _handleError(
          'Error processing video: ${e.toString().replaceAll('Exception: ', '')}',
          exception: e is Exception ? e : Exception(e.toString()));
    } finally {
      // Ensure processing state is always cleared
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _cancelProcessing() async {
    print('Cancelling video processing');

    // Set cancelled state first
    setState(() {
      _isCancelled = true;
      _isProcessing =
          true; // Keep showing processing state until cleanup is done
    });

    // Clean up resources
    try {
      print('Disposing video player controllers');
      _videoPlayerController?.dispose();
      _chewieController?.dispose();
      _videoPlayerController = null;
      _chewieController = null;
    } catch (e) {
      print('Error disposing controllers: $e');
    }

    // Try to cancel the processing on the server side
    try {
      print('Sending cancel request to server');
      await ApiService.cancelProcessing();
      print('Server cancellation successful');
    } catch (e) {
      print('Error cancelling processing on server: $e');
      // Continue with cleanup even if server cancellation fails
    }

    // Final cleanup in UI
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _processingProgress = 0.0;
        _errorMessage = 'Processing cancelled by user';
        _processedContent = null;
      });
      print('Processing cancellation complete');
    }
  }

  void _handleError(String message, {Exception? exception}) {
    print('Error: $message');
    if (exception != null) {
      print('Exception: $exception');
    }

    // Clean up resources
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;

    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isProcessing = false;
        _processedContent = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Selection buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSelectionButton(
                  icon: Icons.image,
                  label: 'Pick Image',
                  onTap: _pickImage,
                ),
                _buildSelectionButton(
                  icon: Icons.videocam,
                  label: 'Pick Video',
                  onTap: _pickVideo,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Skip frames slider (only show when a video is selected)
            if (_selectedFile != null &&
                _selectedFile!.path.toLowerCase().endsWith('.mp4'))
              Column(
                children: [
                  const Text('Processing Speed:'),
                  Row(
                    children: [
                      const Text('All Frames'),
                      Expanded(
                        child: Slider(
                          value: _skipFrames.toDouble(),
                          min: 0,
                          max: 5,
                          divisions: 5,
                          label: _skipFrames == 0
                              ? 'All Frames'
                              : 'Every ${_skipFrames + 1} Frames',
                          onChanged: (value) {
                            setState(() {
                              _skipFrames = value.toInt();
                            });
                          },
                        ),
                      ),
                      const Text('Every 6th Frame'),
                    ],
                  ),
                  Text(
                    _skipFrames == 0
                        ? 'Processing all frames (slower, better quality)'
                        : 'Processing every ${_skipFrames + 1} frames (faster, lower quality)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                ],
              ),

            // Processing indicator
            if (_isProcessing)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      value:
                          _processingProgress > 0 ? _processingProgress : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _processingProgress > 0
                          ? 'Processing: ${(_processingProgress * 100).toInt()}%'
                          : 'Processing...',
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _cancelProcessing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _processedContent = null;
                        });
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),

            // Selected file info
            if (_selectedFile != null && !_isProcessing)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Selected: ${_selectedFile!.path.split('/').last}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),

            // Processed content display
            if (_processedContent != null)
              Expanded(
                child: Center(
                  child: _processedContent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xffeb5757),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: Colors.white,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GalleryView extends StatefulWidget {
  final File selectedFile;

  const GalleryView({super.key, required this.selectedFile});

  @override
  _GalleryViewState createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedFile.path.endsWith('.mp4') ||
        widget.selectedFile.path.endsWith('.mov')) {
      _videoPlayerController = VideoPlayerController.file(widget.selectedFile);
      _videoPlayerController!.initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            autoPlay: true,
            looping: false,
          );
          _isVideoInitialized = true;
        });
      }).catchError((error) {
        print("Failed to initialize video: $error");
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // الرجوع دون إرجاع أي بيانات
          },
        ),
      ),
      body: Center(
        child: _isVideoInitialized
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
