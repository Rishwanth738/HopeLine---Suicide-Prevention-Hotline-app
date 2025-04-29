from fastapi import FastAPI
from pydantic import BaseModel
from transformers import pipeline
import uvicorn

# Initialize FastAPI app
app = FastAPI()

# Load sentiment-analysis model from Hugging Face
sentiment_analyzer = pipeline("sentiment-analysis")

# Create request model
class TextRequest(BaseModel):
    text: str

# Define sentiment analysis route
@app.post("/analyze-sentiment/")
async def analyze_sentiment(request: TextRequest):
    text = request.text
    sentiment = sentiment_analyzer(text)[0]
    return {"label": sentiment['label'], "score": sentiment['score']}

# Run the server
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
