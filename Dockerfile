FROM python:3.12-slim
WORKDIR /app

# Copy only requirements first to allow Docker caching
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the code
COPY . /app

# Expose the port dynamically from .env
EXPOSE ${PORT}

# Example startup command: run a Python module from src/main.py
CMD [ "python", "-m", "src.main" ]
