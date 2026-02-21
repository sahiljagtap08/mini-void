from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from app.rag import store_text, query_text

app = FastAPI(title="Mini Knowledge Brain")


class TextInput(BaseModel):
    text: str


class QuestionInput(BaseModel):
    question: str


@app.get("/", response_class=HTMLResponse)
def ui():
    return """
<!DOCTYPE html>
<html>
<head>
  <title>Mini Knowledge Brain</title>
  <style>
    body { font-family: monospace; max-width: 700px; margin: 60px auto; padding: 0 20px; background: #0f0f0f; color: #e0e0e0; }
    h1 { color: #7c3aed; }
    textarea, input { width: 100%; padding: 10px; background: #1a1a1a; color: #e0e0e0; border: 1px solid #333; border-radius: 4px; font-family: monospace; box-sizing: border-box; }
    textarea { height: 120px; resize: vertical; }
    button { margin-top: 8px; padding: 10px 20px; background: #7c3aed; color: white; border: none; border-radius: 4px; cursor: pointer; font-family: monospace; }
    button:hover { background: #6d28d9; }
    .section { margin-bottom: 36px; }
    .label { color: #888; font-size: 12px; margin-bottom: 6px; }
    .result { margin-top: 12px; padding: 12px; background: #1a1a1a; border-left: 3px solid #7c3aed; white-space: pre-wrap; min-height: 40px; }
  </style>
</head>
<body>
  <h1>Mini Knowledge Brain</h1>

  <div class="section">
    <div class="label">STORE TEXT</div>
    <textarea id="storeText" placeholder="Paste any text here..."></textarea>
    <button onclick="store()">Store</button>
    <div class="result" id="storeResult"></div>
  </div>

  <div class="section">
    <div class="label">ASK A QUESTION</div>
    <input id="question" type="text" placeholder="What do you want to know?" onkeydown="if(event.key==='Enter') ask()" />
    <button onclick="ask()">Ask</button>
    <div class="result" id="askResult"></div>
  </div>

  <script>
    async function store() {
      const text = document.getElementById("storeText").value.trim();
      if (!text) return;
      document.getElementById("storeResult").textContent = "Storing...";
      const r = await fetch("/store", { method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({text}) });
      const d = await r.json();
      document.getElementById("storeResult").textContent = d.status === "stored" ? "Stored." : JSON.stringify(d);
    }

    async function ask() {
      const question = document.getElementById("question").value.trim();
      if (!question) return;
      document.getElementById("askResult").textContent = "Thinking...";
      const r = await fetch("/ask", { method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({question}) });
      const d = await r.json();
      document.getElementById("askResult").textContent = d.answer || JSON.stringify(d);
    }
  </script>
</body>
</html>
"""


@app.post("/store")
def store(data: TextInput):
    store_text(data.text)
    return {"status": "stored"}


@app.post("/ask")
def ask(data: QuestionInput):
    answer = query_text(data.question)
    return {"answer": answer}
