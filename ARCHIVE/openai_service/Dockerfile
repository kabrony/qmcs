FROM python:3.10-slim

WORKDIR /app

# 1) Copy & install requirements
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# 2) Copy source code
COPY . /app

# 3) Launch on port 5000
EXPOSE 5000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
