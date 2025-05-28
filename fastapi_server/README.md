# FastAPI Server with YOLOv12n + DeepSORT

## 🔧 Local Development

1. Install requirements:
```bash
pip install -r requirements.txt
```

2. Run FastAPI server:
```bash
uvicorn app.main:app --reload
```

## 🐳 Docker Setup

1. Build the Docker image:
```bash
docker build -t tracking-server .
```

2. Run the container:
```bash
docker run -p 8000:8000 tracking-server
```

## 📝 API Endpoints

- `POST /detect`: Upload image for object detection
- `POST /process_image`: Process and annotate image
- `POST /process_video`: Process and annotate video
- `WS /ws/track`: WebSocket endpoint for real-time tracking

For detailed API documentation, visit `http://localhost:8000/docs` after starting the server.