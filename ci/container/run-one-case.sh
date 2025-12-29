#!/usr/bin/env bash
set -euo pipefail

case_name="${1:?case name required}"
# Allow empty USE flags (baseline case). Still error if the argument is missing.
use_flags="${2?use flags required}"

pkg="media-gfx/openusd"

# Keep this list in sync with IUSE in the ebuild.
all_iuse=(alembic draco embree hdf5 materialx ocio oiio osl ptex usdview)

enabled=()
read -r -a enabled <<<"${use_flags}"

declare -A enabled_set=()
for f in "${enabled[@]}"; do
	enabled_set["${f}"]=1
	done

# Build a strict USE line that disables everything else.
use_line=("${pkg}")
for f in "${all_iuse[@]}"; do
	if [[ -n "${enabled_set[${f}]:-}" ]]; then
		use_line+=("${f}")
	else
		use_line+=("-${f}")
	fi
	done

mkdir -p /etc/portage/package.use
printf '%s\n' "${use_line[*]}" > "/etc/portage/package.use/openusd-${case_name}"

echo "=== Case: ${case_name}" >&2
echo "USE: ${use_flags}" >&2

# Allow cached binpkgs for dependencies, but always rebuild OpenUSD from source
# so rerunning test cases is deterministic.
emerge -1v --usepkg --usepkg-exclude="${pkg}" --buildpkg-exclude="${pkg}" "${pkg}"
