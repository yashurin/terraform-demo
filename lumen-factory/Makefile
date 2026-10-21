PYTHON ?= python3
export PYTHONPATH := .

.PHONY: check-python install dev build test plan-dev apply-dev destroy-dev plan-prod apply-prod

check-python:
	@$(PYTHON) -c 'import sys; sys.version_info >= (3, 11) or sys.exit("Python 3.11+ required, found %s. Example: make dev PYTHON=python3.12" % sys.version.split()[0])'

install: check-python
	$(PYTHON) -m pip install -e ".[dev]"

dev: check-python
	$(PYTHON) -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

build: check-python
	$(PYTHON) -m app.build

test: check-python
	$(PYTHON) -m pytest

plan-dev: build
	terraform -chdir=infra/envs/dev plan

apply-dev: build
	terraform -chdir=infra/envs/dev apply

destroy-dev:
	terraform -chdir=infra/envs/dev destroy

plan-prod: build
	terraform -chdir=infra/envs/prod plan

apply-prod: build
	terraform -chdir=infra/envs/prod apply
