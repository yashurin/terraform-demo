"""Local preview server. The static export lives in app.build."""

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles

from app.render import APP_DIR, render

app = FastAPI(title="Lumen Factory")
app.mount("/static", StaticFiles(directory=APP_DIR / "static"), name="static")


def _page(template: str, page_id: str) -> HTMLResponse:
    return HTMLResponse(render(template, page_id=page_id, exported=False))


@app.get("/", response_class=HTMLResponse)
def home() -> HTMLResponse:
    return _page("index.html", "home")


@app.get("/about", response_class=HTMLResponse)
def about() -> HTMLResponse:
    return _page("about.html", "about")


@app.get("/workshop", response_class=HTMLResponse)
def workshop() -> HTMLResponse:
    return _page("workshop.html", "workshop")


@app.exception_handler(404)
def missing(_request: Request, _exc: Exception) -> HTMLResponse:
    body = render("404.html", page_id=None, exported=False)
    return HTMLResponse(body, status_code=404)
