#!/usr/bin/env bash
set -euo pipefail

: "${OPENUSD_CASE:?OPENUSD_CASE is required}"
: "${OPENUSD_USE_FLAGS?OPENUSD_USE_FLAGS is required}"

require_path() {
	local path="$1" desc="$2"
	if [[ ! -e "${path}" ]]; then
		echo "Expected ${desc} at ${path} (missing)" >&2
		exit 2
	fi
}

copy_tree() {
	local src="$1" dst="$2"
	if [[ ! -d "${src}" ]]; then
		echo "Missing directory: ${src}" >&2
		exit 2
	fi
	mkdir -p "${dst}"
	cp -a "${src}/." "${dst}/"
}

main() {
	require_path /overlay "overlay checkout (mounted at /overlay)"
	require_path /var/db/repos/openusd-overlay "overlay repo (mounted at /var/db/repos/openusd-overlay)"
	require_path /var/db/repos/gentoo "gentoo ebuild repo"

	# Install CI portage snippets (scoped keywording, overlay repos.conf, env).
	mkdir -p /etc/portage
	copy_tree /overlay/ci/portage/repos.conf /etc/portage/repos.conf
	copy_tree /overlay/ci/portage/package.accept_keywords /etc/portage/package.accept_keywords
	copy_tree /overlay/ci/portage/package.license /etc/portage/package.license
	copy_tree /overlay/ci/portage/package.env /etc/portage/package.env
	copy_tree /overlay/ci/portage/env /etc/portage/env

	# Merge make.conf overrides at the end (keep it minimal).
	cat /overlay/ci/portage/make.conf >> /etc/portage/make.conf

	# Ensure cache dirs exist even if volumes are empty.
	mkdir -p /var/cache/distfiles /var/cache/binpkgs

	# for draco
	emerge --usepkg app-eselect/eselect-repository
	eselect repository add waebbl git https://github.com/waebbl/waebbl-gentoo
	emerge --sync waebbl
	echo "media-libs/draco ~amd64" >> /etc/portage/package.accept_keywords/waebbl

	/ci/run-one-case.sh "${OPENUSD_CASE}" "${OPENUSD_USE_FLAGS}"
}

main
