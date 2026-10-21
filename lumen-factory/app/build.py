"""Write a complete static site to app/dist/."""

import shutil
import sys
from pathlib import Path

from app.render import APP_DIR, render

DIST = APP_DIR / "dist"

PAGES = (
    ("index.html", "index.html", "home"),
    ("about.html", "about.html", "about"),
    ("workshop.html", "workshop.html", "workshop"),
    ("404.html", "404.html", None),
)


def build(dest: Path | None = None) -> Path:
    if sys.version_info < (3, 11):
        raise SystemExit("Python 3.11+ is required to build Lumen Factory.")

    target = dest or DIST
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)
    shutil.copytree(APP_DIR / "static", target / "static")

    for filename, template, page_id in PAGES:
        html = render(template, page_id=page_id, exported=True)
        (target / filename).write_text(html, encoding="utf-8")

    return target


def main() -> None:
    path = build()
    print(f"Wrote {path}")


if __name__ == "__main__":
    main()
