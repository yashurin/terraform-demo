# App

A small FastAPI site. The local server renders Jinja2 templates. `python -m app.build` writes the same pages to `app/dist/` as static HTML. Terraform uploads that folder and nothing else.

Python 3.11 or newer is required. The default `python3` on some machines is older. Pass a newer interpreter to Make when that happens.

## Setup

```bash
cd lumen-factory
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -e ".[dev]"
```

## Local preview

```bash
make dev
```

That runs:

```bash
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Open:

- http://127.0.0.1:8000/
- http://127.0.0.1:8000/about
- http://127.0.0.1:8000/workshop

## Static build

```bash
make build
```

That runs `python -m app.build` and writes:

- `app/dist/index.html`
- `app/dist/about.html`
- `app/dist/workshop.html`
- `app/dist/404.html`
- `app/dist/static/` (CSS, JS, icon)

Open `app/dist/index.html` in a browser, or serve the folder:

```bash
python -m http.server 8080 --directory app/dist
```

Asset URLs in the export are relative (`static/css/site.css`) so they work from the file and from the bucket root. The local server uses root-relative `/static/...` instead.

## Tests

```bash
make test
```

## Factory CLI

After the editable install, the `lumen` command is on your PATH. `python -m app` is the same program.

```bash
lumen build
lumen preview
lumen sites plan --env dev
lumen sites apply --env dev
lumen sites url --env dev
lumen sites destroy --env dev --yes
```

Prod destroy is refused unless both flags are present:

```bash
lumen sites destroy --env prod --yes --i-mean-prod
```

`plan` and `apply` build `app/dist/` first, then run Terraform in `infra/envs/<env>`. Apply does not pass `-auto-approve`. You still confirm in the Terraform prompt.

The publish path for Terraform is `app/dist`.
