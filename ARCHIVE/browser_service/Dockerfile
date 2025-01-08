FROM python:3.11-slim-buster

WORKDIR /app

RUN pip install --no-cache-dir \
    fastapi uvicorn httpx pydantic python-dotenv requests \
    openai playwright langchain==0.0.304

RUN apt-get update && apt-get install -y \
    libnss3 libx11-6 libgbm-dev libxss1 libatk1.0-0 libatk-bridge2.0-0 \
    libx11-xcb1 libxcb-dri3-0 libdrm2 libxcomposite1 libxdamage1 libxfixes3 \
    libxrandr2 libgbm-dev libasound2 gstreamer1.0-libav gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good && rm -rf /var/lib/apt/lists/*

RUN playwright install --with-deps chromium

COPY app/ /app
COPY utils/ /utils

ENV PYTHONPATH="/:/utils"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
