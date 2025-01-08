FROM python:3.12-slim

WORKDIR /app

# Copy and install requirements into the virtual environment
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir --upgrade pip

# Copy the rest of the code
COPY . /app

# Use python from within the virtual environment
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
