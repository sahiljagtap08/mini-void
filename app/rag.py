import faiss
import numpy as np
from openai import OpenAI
from app.db import SessionLocal, Chunk

client = OpenAI()

dimension = 1536
index = faiss.IndexFlatL2(dimension)


def embed(text: str) -> np.ndarray:
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=text,
    )
    return np.array(response.data[0].embedding).astype("float32")


def store_text(text: str) -> None:
    vector = embed(text)
    index.add(np.array([vector]))

    db = SessionLocal()
    db.add(Chunk(content=text))
    db.commit()
    db.close()


def query_text(question: str) -> str:
    if index.ntotal == 0:
        return "No documents stored yet. Use /store to add some text first."

    q_vector = embed(question)
    D, I = index.search(np.array([q_vector]), k=min(3, index.ntotal))

    db = SessionLocal()
    chunks = db.query(Chunk).all()
    db.close()

    context = "\n\n".join([chunks[i].content for i in I[0] if i < len(chunks)])

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "Answer based only on the provided context. If the answer isn't in the context, say so."},
            {"role": "user", "content": f"Context:\n{context}\n\nQuestion:\n{question}"},
        ],
    )
    return response.choices[0].message.content
