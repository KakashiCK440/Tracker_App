import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.17:8000';
  static const String wsTrackUrl = 'ws://192.168.1.17:8000/ws/track';

  static WebSocketChannel? _ws;
  static Future<WebSocketChannel> getWSConnection() async {
    if (_ws == null || _ws?.closeCode != null) {
      print("Connecting to WebSocket: $wsTrackUrl");
      _ws = WebSocketChannel.connect(Uri.parse(wsTrackUrl));
    }
    return _ws!;
  }

  // Optimized batch frame processing
  static Future<List<Map<String, dynamic>>> processBatchFrames(
      List<Uint8List> frames) async {
    if (frames.isEmpty) return [];

    try {
      final ws = await getWSConnection();

      // Send frames in batches
      for (var i = 0; i < frames.length; i += 5) {
        final batch = frames.sublist(i, math.min(i + 5, frames.length));

        // Create batch message
        final batchMessage = {
          'type': 'batch_frames',
          'frames': batch.map((f) => base64Encode(f)).toList(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Send batch
        ws.sink.add(jsonEncode(batchMessage));
      }

      // TODO: Implement response handling
      return [];
    } catch (e) {
      print('Error in batch processing: $e');
      return [];
    }
  }

  // Optimized image compression before sending
  static Future<Uint8List> compressImage(Uint8List imageBytes) async {
    try {
      // Use flutter_image_compress for better compression
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        minHeight: 480,
        minWidth: 640,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      return result;
    } catch (e) {
      print('Error compressing image: $e');
      return imageBytes; // Return original if compression fails
    }
  }

  // Optimized video frame processing
  static Future<Map<String, dynamic>?> processVideoFrames(
    List<Uint8List> frames, {
    int skipFrames = 2, // Process every 3rd frame by default
    Function(double)? onProgress,
  }) async {
    try {
      final processedFrames = <Uint8List>[];

      // Compress and filter frames
      for (var i = 0; i < frames.length; i++) {
        if (i % (skipFrames + 1) == 0) {
          final compressed = await compressImage(frames[i]);
          processedFrames.add(compressed);
        }

        if (onProgress != null) {
          onProgress(i / frames.length);
        }
      }

      // Process in batches
      final results = await processBatchFrames(processedFrames);

      return {
        'frames': results,
        'processed_count': processedFrames.length,
        'total_frames': frames.length,
      };
    } catch (e) {
      print('Error processing video frames: $e');
      return null;
    }
  }

  // Send an image to the server for object detection
  static Future<Map<String, dynamic>?> detectObjects(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/detect');

      // Create a multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add the file to the request
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
      );

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Check if the request was successful
      if (response.statusCode == 200) {
        // Parse the JSON response
        return json.decode(response.body);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception during API call: $e');
      return null;
    }
  }

  // Send image bytes to the server for object detection
  static Future<Map<String, dynamic>?> detectObjectsFromBytes(
      Uint8List bytes) async {
    try {
      final uri = Uri.parse('$baseUrl/detect');

      // Create a multipart request with optimized settings
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'frame.jpg',
          contentType: null,
        ))
        ..headers.addAll({
          'Connection': 'keep-alive',
          'Accept': 'application/json',
        });

      // Send the request without timeout
      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception during API call: $e');
      return null;
    }
  }

  // Track a specific object by ID
  static Future<Map<String, dynamic>?> trackObject(
      File imageFile, int? focusId) async {
    try {
      final uri = Uri.parse('$baseUrl/detect');

      // Create a multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add the file to the request
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
      );

      // Add focus_id parameter if provided
      if (focusId != null) {
        request.fields['focus_id'] = focusId.toString();
      }

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Check if the request was successful
      if (response.statusCode == 200) {
        // Parse the JSON response
        return json.decode(response.body);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception during API call: $e');
      return null;
    }
  }

  // Process an image and return the annotated image
  static Future<Map<String, dynamic>?> processImage(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/process_image');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
      );

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        final bytes = await streamedResponse.stream.toBytes();

        // Get statistics from headers or additional response data
        final stats = {
          'Total Detections':
              streamedResponse.headers['x-total-detections'] ?? '0',
          'Average Confidence':
              streamedResponse.headers['x-avg-confidence'] ?? 'N/A',
          'Processing Time (ms)':
              streamedResponse.headers['x-processing-time'] ?? 'N/A',
        };

        return {
          'bytes': bytes,
          'statistics': stats,
        };
      } else {
        print('Error: ${streamedResponse.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception during process image API call: $e');
      return null;
    }
  }

  // Process a video and return the annotated video file
  static Future<Map<String, dynamic>?> processVideo(
    File videoFile, {
    int skipFrames = 0,
    Function(double)? onProgress,
  }) async {
    try {
      print('ApiService: Starting video processing');
      print('Video file path: ${videoFile.path}');
      print('Video file size: ${await videoFile.length()} bytes');

      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      final uri = Uri.parse('$baseUrl/process_video');
      final request = http.MultipartRequest('POST', uri);

      // Add the file to the request
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          videoFile.path,
          filename: path.basename(videoFile.path),
        ),
      );

      // Add skip frames parameter
      if (skipFrames > 0) {
        request.fields['skip_frames'] = skipFrames.toString();
      }

      print('ApiService: Sending request to server');
      final streamedResponse = await request.send();
      print(
          'ApiService: Received response with status ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final outputFile = File('${tempDir.path}/processed_video_$ts.mp4');
        final sink = outputFile.openWrite();

        try {
          await for (final chunk in streamedResponse.stream) {
            sink.add(chunk);
          }
          await sink.close();

          print('ApiService: Video saved to ${outputFile.path}');
          print(
              'ApiService: Output file size: ${await outputFile.length()} bytes');

          // Verify the output file
          if (!await outputFile.exists()) {
            throw Exception('Output file was not created');
          }

          if (await outputFile.length() < 1000) {
            throw Exception('Output file is too small');
          }

          // Get video statistics from headers
          final stats = {
            'Total Frames': streamedResponse.headers['x-total-frames'] ?? 'N/A',
            'Processed Frames':
                streamedResponse.headers['x-processed-frames'] ?? 'N/A',
            'Total Detections':
                streamedResponse.headers['x-total-detections'] ?? 'N/A',
            'Average Detections per Frame':
                streamedResponse.headers['x-avg-detections'] ?? 'N/A',
            'Processing Time (s)':
                streamedResponse.headers['x-processing-time'] ?? 'N/A',
            'Frame Rate': streamedResponse.headers['x-frame-rate'] ?? 'N/A',
          };

          print('ApiService: Processing completed with statistics: $stats');

          if (onProgress != null) {
            onProgress(1.0);
          }

          return {
            'file': outputFile,
            'statistics': stats,
          };
        } catch (e) {
          print('ApiService: Error processing video stream: $e');
          await sink.close();
          await outputFile.delete();
          rethrow;
        }
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        print(
            'ApiService: Error response ${streamedResponse.statusCode}: $errorBody');
        throw Exception(
            'Server error: ${streamedResponse.statusCode} - $errorBody');
      }
    } catch (e) {
      print('ApiService: Exception during video processing: $e');
      return null;
    }
  }

  static Future<void> cancelProcessing() async {
    try {
      final uri = Uri.parse('$baseUrl/cancel_processing');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to cancel processing: ${response.body}');
      }

      // Close WebSocket connection if it exists
    } catch (e) {
      print('Error cancelling processing: $e');
      rethrow;
    }
  }

  // Batch detection of multiple frames
  static Future<Map<String, dynamic>?> detectBatch(
      List<Uint8List> frames) async {
    try {
      final uri = Uri.parse('$baseUrl/detect_batch');
      final request = http.MultipartRequest('POST', uri);

      // Add all frames as files
      for (var i = 0; i < frames.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            frames[i],
            filename: 'frame_$i.jpg',
          ),
        );
      }

      // Send request and get response
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error in detectBatch: $e');
      return null;
    }
  }
}

// Add MediaType class for content type specification
class MediaType {
  final String primaryType;
  final String subType;

  MediaType(this.primaryType, this.subType);

  @override
  String toString() => '[39m$primaryType/$subType';
}
