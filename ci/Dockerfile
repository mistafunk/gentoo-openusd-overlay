FROM gentoo/portage:latest as portage

FROM gentoo/stage3:amd64-desktop-openrc

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Copy the full Gentoo ebuild repository from the dedicated portage image.
# This avoids emerge-webrsync and keeps /var/db/repos/gentoo present immediately.
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo

COPY ci/container/ /ci/

ENTRYPOINT ["/ci/entrypoint.sh"]
