import subprocess

import pytest

from app.cli import guard_prod_destroy, main


HELP_COMMANDS = [
    ["--help"],
    ["build", "--help"],
    ["preview", "--help"],
    ["sites", "--help"],
    ["sites", "plan", "--help"],
    ["sites", "apply", "--help"],
    ["sites", "destroy", "--help"],
    ["sites", "url", "--help"],
]


@pytest.mark.parametrize("argv", HELP_COMMANDS)
def test_every_command_has_help(argv):
    with pytest.raises(SystemExit) as exc:
        main(argv)
    assert exc.value.code == 0


@pytest.mark.parametrize(
    "argv",
    [
        ["sites", "destroy", "--env", "prod"],
        ["sites", "destroy", "--env", "prod", "--yes"],
        ["sites", "destroy", "--env", "prod", "--i-mean-prod"],
        ["sites", "destroy", "--env", "dev"],
    ],
)
def test_destroy_guard_refuses_incomplete_flags(argv, monkeypatch):
    def explode(*_args, **_kwargs):
        raise AssertionError("terraform must not run")

    monkeypatch.setattr(subprocess, "run", explode)
    with pytest.raises(SystemExit) as exc:
        main(argv)
    assert "Refusing" in str(exc.value)


def test_guard_message_names_the_prod_flag():
    with pytest.raises(SystemExit) as exc:
        guard_prod_destroy("prod", yes=True, i_mean_prod=False)
    assert "i-mean-prod" in str(exc.value)


def test_dev_destroy_with_yes_calls_terraform(monkeypatch):
    calls = []

    def fake_run(cmd, **_kwargs):
        calls.append(cmd)

        class Result:
            returncode = 0
            stdout = ""

        return Result()

    monkeypatch.setattr("app.cli.run", fake_run)
    monkeypatch.setattr("app.cli.ensure_init", lambda _path: None)
    main(["sites", "destroy", "--env", "dev", "--yes"])
    assert calls == [["terraform", "destroy", "-input=false", "-auto-approve"]]


def test_prod_destroy_with_both_flags_calls_terraform(monkeypatch):
    calls = []

    def fake_run(cmd, **_kwargs):
        calls.append(list(cmd))

        class Result:
            returncode = 0
            stdout = ""

        return Result()

    monkeypatch.setattr("app.cli.run", fake_run)
    monkeypatch.setattr("app.cli.ensure_init", lambda _path: None)
    main(["sites", "destroy", "--env", "prod", "--yes", "--i-mean-prod"])
    assert calls[0][:2] == ["terraform", "destroy"]


def test_plan_builds_then_plans(monkeypatch, tmp_path):
    calls = []

    def fake_build():
        calls.append("build")
        return tmp_path

    def fake_run(cmd, **_kwargs):
        calls.append(list(cmd))

        class Result:
            returncode = 0
            stdout = "https://example.cloudfront.net"

        return Result()

    monkeypatch.setattr("app.cli.build", fake_build)
    monkeypatch.setattr("app.cli.run", fake_run)
    monkeypatch.setattr("app.cli.ensure_init", lambda _path: None)
    main(["sites", "plan", "--env", "dev"])
    assert calls[0] == "build"
    assert calls[1] == ["terraform", "plan", "-input=false"]
