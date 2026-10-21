"""lumen: a thin teaching wrapper around the static build and Terraform.

This is not a product. It shells out to terraform in infra/envs/<env>.
"""

import argparse
import subprocess
import sys
from pathlib import Path

from app.build import build

ROOT = Path(__file__).resolve().parents[1]
ENVS = ROOT / "infra" / "envs"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="lumen",
        description="Build the Lumen Factory site and drive its Terraform envs.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    build_cmd = sub.add_parser("build", help="Export the static site into app/dist.")
    build_cmd.set_defaults(func=cmd_build)

    preview = sub.add_parser("preview", help="Serve the site locally on port 8000.")
    preview.add_argument("--port", type=int, default=8000, help="Local port (default 8000).")
    preview.set_defaults(func=cmd_preview)

    sites = sub.add_parser("sites", help="Plan, apply, destroy, or print a site URL.")
    sites_sub = sites.add_subparsers(dest="sites_command", required=True)

    plan = sites_sub.add_parser("plan", help="Build dist/, then terraform plan for one env.")
    _add_env(plan)
    plan.set_defaults(func=cmd_plan)

    apply = sites_sub.add_parser("apply", help="Build dist/, then terraform apply for one env.")
    _add_env(apply)
    apply.set_defaults(func=cmd_apply)

    destroy = sites_sub.add_parser(
        "destroy",
        help="terraform destroy. Prod also requires --i-mean-prod.",
    )
    _add_env(destroy)
    destroy.add_argument("--yes", action="store_true", help="Pass -auto-approve to terraform.")
    destroy.add_argument(
        "--i-mean-prod",
        action="store_true",
        help="Required together with --yes before prod can be destroyed.",
    )
    destroy.set_defaults(func=cmd_destroy)

    url = sites_sub.add_parser("url", help="Print the cloudfront_url output.")
    _add_env(url)
    url.set_defaults(func=cmd_url)

    return parser


def _add_env(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--env", required=True, choices=("dev", "prod"), help="dev or prod.")


def guard_prod_destroy(env: str, yes: bool, i_mean_prod: bool) -> None:
    """Stop destroy unless the flags match the environment."""
    if env == "prod" and not (yes and i_mean_prod):
        raise SystemExit(
            "Refusing to destroy prod. Re-run with --env prod --yes --i-mean-prod."
        )
    if not yes:
        raise SystemExit("Refusing to destroy without --yes.")


def env_dir(name: str) -> Path:
    path = ENVS / name
    if not path.is_dir():
        raise SystemExit(f"Unknown environment '{name}'. Expected a folder at {path}.")
    return path


def run(cmd: list[str], *, cwd: Path, capture: bool = False) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd))
    try:
        return subprocess.run(cmd, cwd=cwd, check=True, text=True, capture_output=capture)
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.returncode) from exc


def ensure_init(path: Path) -> None:
    if (path / ".terraform").is_dir():
        return
    backend = path / "backend.hcl"
    if not backend.is_file():
        raise SystemExit(
            f"Missing {backend.name} in {path}. "
            "Apply infra/bootstrap first, copy backend.hcl.example to backend.hcl, "
            "and fill in the state bucket. See infra/bootstrap/README.md."
        )
    run(["terraform", "init", "-input=false", "-backend-config=backend.hcl"], cwd=path)


def cmd_build(_args: argparse.Namespace) -> None:
    path = build()
    print(f"Wrote {path}")


def cmd_preview(args: argparse.Namespace) -> None:
    run(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "app.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            str(args.port),
        ],
        cwd=ROOT,
    )


def cmd_plan(args: argparse.Namespace) -> None:
    build()
    path = env_dir(args.env)
    ensure_init(path)
    run(["terraform", "plan", "-input=false"], cwd=path)


def cmd_apply(args: argparse.Namespace) -> None:
    build()
    path = env_dir(args.env)
    ensure_init(path)
    run(["terraform", "apply", "-input=false"], cwd=path)
    cmd_url(args)


def cmd_destroy(args: argparse.Namespace) -> None:
    guard_prod_destroy(args.env, args.yes, args.i_mean_prod)
    path = env_dir(args.env)
    ensure_init(path)
    run(["terraform", "destroy", "-input=false", "-auto-approve"], cwd=path)


def cmd_url(args: argparse.Namespace) -> None:
    path = env_dir(args.env)
    ensure_init(path)
    result = run(["terraform", "output", "-raw", "cloudfront_url"], cwd=path, capture=True)
    print(result.stdout.strip())


def main(argv: list[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
