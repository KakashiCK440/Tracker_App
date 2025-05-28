import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';

class DetectionResultsView extends StatefulWidget {
  final File? processedFile;
  final bool isVideo;
  final Map<String, dynamic>? statistics;

  const DetectionResultsView({
    Key? key,
    required this.processedFile,
    required this.isVideo,
    this.statistics,
  }) : super(key: key);

  @override
  State<DetectionResultsView> createState() => _DetectionResultsViewState();
}

class _DetectionResultsViewState extends State<DetectionResultsView> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  String? _uniqueKey;

  @override
  void initState() {
    super.initState();
    _uniqueKey = DateTime.now().millisecondsSinceEpoch.toString();
    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant DetectionResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.processedFile?.path != widget.processedFile?.path) {
      setState(() {
        _uniqueKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }
  }

  Future<void> _initializeVideo() async {
    try {
      print(
          'Initializing video player with file: ${widget.processedFile!.path}');
      print('File exists: ${await widget.processedFile!.exists()}');
      print('File size: ${await widget.processedFile!.length()} bytes');

      _videoPlayerController =
          VideoPlayerController.file(widget.processedFile!);

      // Set better error handling
      await _videoPlayerController!.initialize().catchError((error) {
        print('Error initializing video player: $error');
        throw error;
      });

      // Add a slight delay to ensure initialization completes
      await Future.delayed(const Duration(milliseconds: 300));

      double aspectRatio = _videoPlayerController!.value.aspectRatio;
      // If aspect ratio is invalid, use a default 16:9
      if (aspectRatio.isNaN || aspectRatio <= 0) {
        aspectRatio = 16 / 9;
        print('Invalid aspect ratio, using default 16:9');
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        aspectRatio: aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error loading video: $errorMessage',
              style: const TextStyle(color: Colors.red),
            ),
          );
        },
      );

      if (mounted) setState(() {});
    } catch (e) {
      print('Failed to initialize video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video playback error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Widget _buildMediaDisplay() {
    if (widget.isVideo) {
      if (_chewieController != null) {
        return AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: Chewie(
            key: ValueKey(widget.processedFile!.path),
            controller: _chewieController!,
          ),
        );
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    } else {
      // Add a unique key to force image refresh
      return Image.file(
        widget.processedFile!,
        key: ValueKey(_uniqueKey),
        fit: BoxFit.contain,
        gaplessPlayback: false, // Disable image caching
      );
    }
  }

  Widget _buildStatisticsTable() {
    if (widget.statistics == null) return const SizedBox();

    // Format statistics for display
    Map<String, String> formattedStats = {};
    widget.statistics!.forEach((key, value) {
      String formattedValue = value.toString();

      // Format numeric values
      if (value is num) {
        if (key.contains('Time')) {
          formattedValue =
              '${value.toStringAsFixed(2)} ${key.contains('ms') ? 'ms' : 's'}';
        } else if (key.contains('Confidence')) {
          formattedValue = '${(value * 100).toStringAsFixed(1)}%';
        } else if (key.contains('Rate')) {
          formattedValue = '${value.toStringAsFixed(1)} fps';
        } else {
          formattedValue = value.toStringAsFixed(1);
        }
      }

      // Clean up key names
      String displayKey = key
          .replaceAll('x-', '')
          .replaceAll('-', ' ')
          .split(' ')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');

      formattedStats[displayKey] = formattedValue;
    });

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          dataTextStyle: const TextStyle(
            color: Colors.black54,
          ),
          columns: const [
            DataColumn(label: Text('Metric')),
            DataColumn(label: Text('Value')),
          ],
          rows: formattedStats.entries.map((entry) {
            return DataRow(
              cells: [
                DataCell(Text(entry.key)),
                DataCell(Text(entry.value)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVideo
            ? 'Video Analysis Results'
            : 'Image Analysis Results'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMediaDisplay(),
                ),
              ),
              _buildStatisticsTable(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
