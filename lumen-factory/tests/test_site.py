from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.build import DIST, build
from app.main import app

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as test_client:
        yield test_client


def test_home_route(client: TestClient):
    response = client.get("/")
    assert response.status_code == 200
    assert "Lumen Factory" in response.text
    assert "Terraform publishes" in response.text
    assert 'href="/static/css/site.css"' in response.text


def test_about_route_lists_learning_goals(client: TestClient):
    response = client.get("/about")
    assert response.status_code == 200
    body = response.text
    for goal in ("Providers", "State", "Modules", "Environments"):
        assert goal in body


def test_workshop_route_has_the_form(client: TestClient):
    response = client.get("/workshop")
    assert response.status_code == 200
    assert "Site name" in response.text
    assert "Tagline" in response.text
    assert "launch-card" in response.text
    assert 'src="/static/js/workshop.js"' in response.text


def test_unknown_route_is_the_404_page(client: TestClient):
    response = client.get("/no-such-filament")
    assert response.status_code == 404
    assert "Page not found" in response.text
    assert "filament burned out" in response.text


def test_static_assets_are_served(client: TestClient):
    css = client.get("/static/css/site.css")
    script = client.get("/static/js/workshop.js")
    icon = client.get("/static/favicon.svg")
    assert css.status_code == 200
    assert "--ink" in css.text
    assert "fonts.googleapis" not in css.text
    assert script.status_code == 200
    assert "launch-form" in script.text
    assert icon.status_code == 200


def test_static_export_contains_every_page(tmp_path: Path):
    dest = build(dest=tmp_path)
    expected = {
        "index.html": "Lumen Factory",
        "about.html": "Modules",
        "workshop.html": "Tagline",
        "404.html": "Page not found",
    }
    for name, needle in expected.items():
        text = (dest / name).read_text(encoding="utf-8")
        assert needle in text
        assert 'href="static/css/site.css"' in text

    assert (dest / "static" / "css" / "site.css").is_file()
    assert (dest / "static" / "js" / "workshop.js").is_file()
    assert (dest / "static" / "favicon.svg").is_file()
    workshop = (dest / "workshop.html").read_text(encoding="utf-8")
    assert 'src="static/js/workshop.js"' in workshop


def test_default_build_writes_app_dist():
    dest = build()
    assert dest == DIST
    assert (ROOT / "app" / "dist" / "index.html").is_file()
    assert "Lumen Factory" in (dest / "index.html").read_text(encoding="utf-8")
