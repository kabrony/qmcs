FROM python:3.10-slim

WORKDIR /app

RUN apt-get update &&     apt-get install -y --no-install-recommends build-essential curl &&     rm -rf /var/lib/apt/lists/*

# Possibly install some performance or ML libs
RUN pip install --no-cache-dir requests fastapi uvicorn numpy pandas

COPY . /app

EXPOSE 7000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7000"]
