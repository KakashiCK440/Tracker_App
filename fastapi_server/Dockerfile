# Use a minimal base image
FROM python:3.13-slim

# Install required system dependencies for OpenCV and FFmpeg
RUN apt-get update && \
    apt-get install -y libgl1-mesa-glx libglib2.0-0 ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application files (code + model)
COPY . .

# Set default port
ENV PORT=8000

# Expose FastAPI's port
EXPOSE ${PORT}

# Run the FastAPI app via Uvicorn
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --reload