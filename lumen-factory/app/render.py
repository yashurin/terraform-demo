"""Shared HTML rendering for the local server and the static export."""

from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

APP_DIR = Path(__file__).resolve().parent
TEMPLATE_DIR = APP_DIR / "templates"

NAV = (
    {"id": "home", "label": "Home", "route": "/", "file": "index.html"},
    {"id": "about", "label": "About", "route": "/about", "file": "about.html"},
    {"id": "workshop", "label": "Workshop", "route": "/workshop", "file": "workshop.html"},
)


def environment() -> Environment:
    return Environment(
        loader=FileSystemLoader(TEMPLATE_DIR),
        autoescape=select_autoescape(["html"]),
    )


def page_context(*, page_id: str | None, exported: bool) -> dict:
    """Build template variables.

    The local server uses route paths. The static export uses file names and
    relative asset URLs so the same HTML works from a browser, from S3, and
    from CloudFront without a rewrite function.
    """
    nav = []
    for item in NAV:
        nav.append(
            {
                "id": item["id"],
                "label": item["label"],
                "href": item["file"] if exported else item["route"],
                "active": item["id"] == page_id,
            }
        )
    return {
        "nav": nav,
        "asset_prefix": "static" if exported else "/static",
        "home_href": "index.html" if exported else "/",
        "page_id": page_id or "",
    }


def render(template: str, *, page_id: str | None, exported: bool) -> str:
    context = page_context(page_id=page_id, exported=exported)
    return environment().get_template(template).render(**context)
