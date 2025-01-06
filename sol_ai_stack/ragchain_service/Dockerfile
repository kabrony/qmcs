FROM python:3.10-slim

WORKDIR /app

RUN apt-get update &&     apt-get install -y --no-install-recommends build-essential curl &&     rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir motor fastapi uvicorn tenacity

COPY . /app

EXPOSE 5000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
