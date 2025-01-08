from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def hello():
    return {"status": "Quant Service running on port 7000"}

# Add your quant logic, performance algos, etc. here
