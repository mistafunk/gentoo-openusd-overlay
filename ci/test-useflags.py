#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
from typing import Optional
from pathlib import Path


def _quote_for_shell(arg: str) -> str:
	# Print a copy/paste-safe shell command.
	# For env assignments, prefer KEY="value" form so empty values show up as "".
	if arg.startswith("OPENUSD_") and "=" in arg:
		key, value = arg.split("=", 1)
		# Escape for double-quoted POSIX shell string.
		value = (
			value.replace("\\", "\\\\")
			.replace('"', '\\"')
			.replace("$", "\\$")
			.replace("`", "\\`")
		)
		return f'{key}="{value}"'
	return shlex.quote(arg)


def run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
	# Intentionally inherit stdout/stderr so emerge output is visible.
	# Note: we print a shell-escaped representation for debugging/copy-paste.
	print(" ".join(_quote_for_shell(part) for part in cmd))
	return subprocess.run(cmd, check=check)


def ensure_cache_dirs(root: Path) -> tuple[Path, Path]:
	cache_root = root / "ci" / "cache"
	distfiles = cache_root / "distfiles"
	binpkgs = cache_root / "binpkgs"
	distfiles.mkdir(parents=True, exist_ok=True)
	binpkgs.mkdir(parents=True, exist_ok=True)
	return distfiles, binpkgs


def build_image_if_missing(image: str, root: Path, *, force_rebuild: bool) -> None:
	inspect = subprocess.run(
		["docker", "image", "inspect", image],
		stdout=subprocess.DEVNULL,
		stderr=subprocess.DEVNULL,
	)
	if inspect.returncode == 0 and not force_rebuild:
		return

	print(f"Building docker image: {image}", file=sys.stderr)
	cmd = [
		"docker",
		"build",
		"--pull",
		"-t",
		image,
		"-f",
		str(root / "ci" / "Dockerfile"),
		str(root),
	]
	run(cmd)


def run_case(*, image: str, root: Path, case_name: str, use_flags: str) -> None:
	print(f"--- Running {case_name}: {use_flags}", file=sys.stderr)

	distfiles, binpkgs = ensure_cache_dirs(root)

	cmd = [
		"docker",
		"run",
		"--rm",
		"-t",
		"-e",
		f"OPENUSD_CASE={case_name}",
		"-e",
		f"OPENUSD_USE_FLAGS={use_flags}",
		"-v",
		f"{root}:/overlay:ro",
		"-v",
		f"{root}:/var/db/repos/openusd-overlay:ro",
		"-v",
		f"{distfiles}:/var/cache/distfiles",
		"-v",
		f"{binpkgs}:/var/cache/binpkgs",
		image,
	]
	run(cmd)


def main(argv: list[str]) -> int:
	parser = argparse.ArgumentParser(
		prog="ci/test-useflags.sh",
		description="Runs media-gfx/openusd builds inside Docker for a fixed USE matrix.",
	)
	parser.add_argument("--case", dest="case", help="Run a single case")
	parser.add_argument(
		"--rebuild-image",
		action="store_true",
		help="Force rebuilding the Docker image",
	)
	args = parser.parse_args(argv)

	root = (Path(__file__).resolve().parent / "..").resolve()
	image = os.environ.get("OPENUSD_DOCKER_IMAGE", "openusd-useflags-test:local")

	# Fixed explicit matrix (minimal valid sets).
	cases: dict[str, str] = {
		"baseline": "",
		"alembic": "alembic",
		"draco": "draco",
		"materialx": "usdview materialx",
		"osl": "osl",
		"usdview": "usdview",
		"embree": "usdview embree",
		"ocio": "usdview ocio",
		"oiio": "usdview oiio",
		"ptex": "usdview ptex",
		"all": "usdview embree materialx ocio oiio ptex alembic draco osl",
	}

	order = [
		"baseline",
		"alembic",
		"draco",
		"materialx",
		"osl",
		"usdview",
		"embree",
		"ocio",
		"oiio",
		"ptex",
		"all",
	]

	build_image_if_missing(image, root, force_rebuild=args.rebuild_image)

	if args.case:
		if args.case not in cases:
			print(f"Unknown case: {args.case}", file=sys.stderr)
			print("Available: " + " ".join(sorted(cases.keys())), file=sys.stderr)
			return 2
		run_case(
			image=image,
			root=root,
			case_name=args.case,
			use_flags=cases[args.case],
		)
		return 0

	for case_name in order:
		run_case(
			image=image,
			root=root,
			case_name=case_name,
			use_flags=cases[case_name],
		)

	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
