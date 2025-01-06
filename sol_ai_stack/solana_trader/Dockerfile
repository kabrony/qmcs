FROM python:3.10-slim

WORKDIR /app

RUN apt-get update &&     apt-get install -y --no-install-recommends build-essential curl &&     rm -rf /var/lib/apt/lists/*

# Example: might need some Solana python libs, requests, etc.
RUN pip install --no-cache-dir requests

COPY . /app

EXPOSE 4500

CMD ["python", "trader.py"]
