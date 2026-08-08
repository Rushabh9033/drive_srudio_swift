# Drive Studio rembg HQ cutout API (CPU)
# Build:  docker build -t drive-studio-rembg .
# Run:    docker run --rm -p 8787:8787 drive-studio-rembg

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

ENV REMBG_HOME=/root/.u2net
EXPOSE 8787

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8787"]
