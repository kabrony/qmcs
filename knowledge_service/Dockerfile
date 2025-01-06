FROM python:3.11-slim-buster

WORKDIR /app

RUN pip install --no-cache-dir \
    fastapi uvicorn pydantic python-dotenv requests httpx \
    weaviate-client==3.20.2

COPY ./app /app
COPY ./../utils /utils

ENV PYTHONPATH="/:/utils"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
