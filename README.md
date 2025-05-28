# AI Tracking System

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)

## Project Overview

This graduation project delivers a comprehensive real-time object detection and tracking system, combining a Flutter mobile application with a high-performance FastAPI backend. The system employs cutting-edge computer vision algorithms (YOLOv12n and DeepSORT) to accurately detect and track people in both static images and dynamic video streams.

### Key Technical Components

- **Computer Vision Pipeline**: YOLOv12n for efficient object detection + DeepSORT for reliable object tracking
- **Real-time Processing**: WebSocket communication for low-latency tracking updates
- **Cloud Integration**: Supabase for authentication, storage, and user management
- **Cross-platform Frontend**: Flutter application supporting both Android and iOS devices

## Core Features

- **Real-time Object Detection**: High-accuracy detection of people in images and videos
- **Live Tracking**: Track objects with real-time camera feed using optimized tracking algorithms
- **User Authentication**: Secure login and registration with Supabase authentication
- **Profile Management**: User profiles with customizable avatars and personal information
- **Dark/Light Mode**: Adaptive UI for different lighting conditions and user preferences
- **WebSocket Integration**: Bi-directional communication for real-time tracking updates
- **Video Processing**: Intelligent processing of uploaded videos with detection statistics
- **History View**: Track and view detection history for previously processed media

## System Architecture

### Frontend (Flutter)
- **tracking/**: Flutter mobile application
  - `lib/`: Core application source code
  - `widgets/`: Reusable UI components (buttons, text fields, video containers)
  - `views/`: Application screens (login, register, home, camera, settings)
  - `services/`: API services and backend communication layer
  - `models/`: Data models for structured information handling
  - `cubits/`: State management using BLoC pattern

### Backend (FastAPI)
- **fastapi_server/**: Python-based backend server
  - `app/`: Server source code
  - `app/detector.py`: YOLO object detection implementation with PyTorch
  - `app/deepsort_tracker.py`: DeepSORT tracking algorithm with motion prediction
  - `app/router.py`: RESTful and WebSocket API endpoints
  - `app/schemas.py`: Pydantic data validation models
  - `app/main.py`: Application entry point with dependency management

## Installation Guide

### Prerequisites
- Flutter SDK (2.10 or higher)
- Python 3.8+ with pip
- Supabase account for authentication and storage
- GPU recommended for optimal performance (CUDA-compatible for PyTorch acceleration)

### Backend Server Setup
1. Clone the repository and navigate to the FastAPI server directory:
   ```bash
   git clone https://github.com/yourusername/ai-tracking-system.git
   cd ai-tracking-system/fastapi_server
   ```

2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   # On Windows:
   venv\Scripts\activate
   # On macOS/Linux:
   source venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Start the server:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

5. The server will be available at `http://localhost:8000` with interactive API documentation at `/docs`

### Flutter App Setup
1. Navigate to the Flutter app directory:
   ```bash
   cd ../tracking
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Update the server URL in `lib/services/api_service.dart` to match your server address:
   ```dart
   static const String baseUrl = 'http://your-server-ip:8000';
   static const String wsTrackUrl = 'ws://your-server-ip:8000/ws/track';
   ```

4. Run the application:
   ```bash
   # For development:
   flutter run
   
   # For production build:
   flutter build apk --release  # Android
   flutter build ios --release  # iOS
   ```

## API Documentation

### REST Endpoints
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/detect` | POST | Detect objects in uploaded images, returns normalized bounding boxes |
| `/process_image` | POST | Process and annotate images with detection visualization |
| `/process_video` | POST | Process and annotate videos with tracking visualization |
| `/cancel_processing` | POST | Cancel an ongoing video processing job |

### WebSocket Endpoints
| Endpoint | Description |
|----------|-------------|
| `/ws/track` | Real-time object tracking stream for camera feed |
| `/ws/batch` | Batch processing of multiple frames for efficient processing |

## Performance Optimizations

- **Frame Skipping**: Configurable frame processing rate for balancing performance and accuracy
- **Client-side Compression**: Intelligent image compression before transmission
- **WebSocket Communication**: Persistent connections to minimize latency overhead
- **Batch Processing**: Group processing for multiple frames to optimize GPU utilization
- **Adaptive Resolution**: Dynamic resolution adjustment based on device capabilities
- **Box Smoothing**: Temporal smoothing of detection boxes for stable tracking visualization
- **Memory Management**: Explicit garbage collection and resource cleanup

## Troubleshooting

### Common Issues
- **WebSocket Connection Failures**: Ensure the server IP is correctly configured and accessible from the device network
- **Slow Video Processing**: Try increasing the frame skip parameter for faster (but less accurate) processing
- **Authentication Errors**: Verify Supabase configuration and network connectivity
- **Memory Issues**: For large videos, reduce resolution or process in smaller segments

## Future Enhancements
- Multi-object type detection beyond people
- Cloud deployment with containerization
- Advanced analytics dashboard
- Integration with home security systems

## Contributors
- Ahmed Mohamed Hashim

## License
[MIT License](LICENSE)

---
*This project was developed as a graduation project and demonstrates advanced computer vision and mobile development capabilities.* 
