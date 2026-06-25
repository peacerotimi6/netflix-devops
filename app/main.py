from fastapi import FastAPI

app = FastAPI()

movies = [
    {"id": 1, "title": "Interstellar", "poster": "https://image.tmdb.org/t/p/w500/7WsyChQLEftFiDOVTGkv3hFpyyt.jpg"},
    {"id": 2, "title": "Inception", "poster": "https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg"},
    {"id": 3, "title": "Avengers: Endgame", "poster": "https://image.tmdb.org/t/p/w500/or06FN3Dka5tukK1e9sl16pB3iy.jpg"}
]

@app.get("/")
def root():
    return {"message": "Netflix API running"}

@app.get("/movies")
def get_movies():
    return movies