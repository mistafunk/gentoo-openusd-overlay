EAPI=8

PYTHON_COMPAT=( python3_{10..13} )

inherit cmake multilib python-single-r1

DESCRIPTION="Pixar's Universal Scene Description (OpenUSD)"
HOMEPAGE="https://github.com/PixarAnimationStudios/OpenUSD"
MY_PN="OpenUSD"
SRC_URI="https://github.com/PixarAnimationStudios/OpenUSD/archive/refs/tags/v${PV}.tar.gz -> ${MY_PN}-${PV}.tar.gz"

S="${WORKDIR}/${MY_PN}-${PV}"

LICENSE="TOSL-1.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="alembic draco embree materialx ocio oiio osl ptex usdview"

PATCHES=(
	"${FILESDIR}/${P}-install-layout.patch"
	"${FILESDIR}/${P}-boost-python-strip-ndebug.patch"
	"${FILESDIR}/${P}-cmake-cmp0072.patch"
)

# NOTE: The following flags are only meaningful when building the viewer/imaging
# stack and are therefore restricted to USE=usdview: embree, ocio, oiio, ptex,
# materialx,
# (vulkan support is disabled in this ebuild).

REQUIRED_USE="
	usdview? ( ${PYTHON_REQUIRED_USE} )
	embree? ( usdview )
	materialx? ( usdview )
	ocio? ( usdview )
	oiio? ( usdview )
	ptex? ( usdview )
"

BDEPEND="
	>=dev-build/cmake-3.26
	virtual/pkgconfig
"

RDEPEND="
	dev-cpp/tbb:=
	usdview? ( virtual/opengl x11-libs/libX11 media-libs/opensubdiv dev-qt/qttools:6 )
	materialx? ( media-libs/materialx:= )
	ptex? ( media-libs/ptex )
	oiio? ( media-libs/openimageio dev-libs/imath media-libs/openexr )
	ocio? ( media-libs/opencolorio dev-libs/imath media-libs/openexr )
	embree? ( media-libs/embree )
	alembic? ( media-gfx/alembic dev-libs/imath media-libs/openexr )
	draco? ( media-libs/draco )
	osl? ( media-libs/osl dev-libs/imath dev-libs/libfmt media-libs/openimageio media-libs/openexr )
	usdview? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
			dev-python/jinja2[${PYTHON_USEDEP}]
			dev-python/pyside[${PYTHON_USEDEP}]
			dev-python/pyopengl[${PYTHON_USEDEP}]
		')
	)
"

DEPEND="${RDEPEND}"

pkg_setup() {
	use usdview && python-single-r1_pkg_setup
}

src_prepare() {
	cmake_src_prepare
}

src_configure() {
	use usdview && python_setup

	local mycmakeargs=(
		-DCMAKE_INSTALL_LIBDIR="$(get_libdir)"
		-DBUILD_SHARED_LIBS=ON
		-DPython3_EXECUTABLE="${PYTHON}"
		-DPYTHON_EXECUTABLE="${PYTHON}"
		-DPYSIDEUICBINARY="${EPREFIX}/usr/$(get_libdir)/qt6/libexec/uic"
		-DPXR_ENABLE_PYTHON_SUPPORT=$(usex usdview ON OFF)
		-DPXR_BUILD_IMAGING=$(usex usdview ON OFF)
		-DPXR_BUILD_USD_IMAGING=$(usex usdview ON OFF)
		-DPXR_ENABLE_GL_SUPPORT=$(usex usdview ON OFF)
		-DPXR_BUILD_USDVIEW=$(usex usdview ON OFF)
		-DPXR_ENABLE_OPENVDB_SUPPORT=OFF
		-DPXR_BUILD_OPENIMAGEIO_PLUGIN=$(usex oiio ON OFF)
		-DPXR_BUILD_OPENCOLORIO_PLUGIN=$(usex ocio ON OFF)
		-DPXR_ENABLE_PTEX_SUPPORT=$(usex ptex ON OFF)
		-DPXR_BUILD_EMBREE_PLUGIN=$(usex embree ON OFF)
		-DPXR_BUILD_ALEMBIC_PLUGIN=$(usex alembic ON OFF)
		-DPXR_BUILD_DRACO_PLUGIN=$(usex draco ON OFF)
		-DPXR_ENABLE_MATERIALX_SUPPORT=$(usex materialx ON OFF)
		-DPXR_ENABLE_OSL_SUPPORT=$(usex osl ON OFF)
		-DPXR_ENABLE_VULKAN_SUPPORT=OFF
		-DPXR_BUILD_DOCUMENTATION=OFF
		-DPXR_BUILD_TESTS=OFF
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	if use usdview; then
		python_setup

		local py_root="${ED}/usr/$(get_libdir)/python"

		# Move the installed pxr package to the multilib-correct location.
		local pxr_src="${ED}/usr/lib/python/pxr"
		local pxr_dst="${py_root}/pxr"
		if [[ -d "${pxr_src}" && "${pxr_src}" != "${pxr_dst}" ]]; then
			mkdir -p "${pxr_dst}" || die
			shopt -s dotglob nullglob
			mv "${pxr_src}"/* "${pxr_dst}"/ || die
			shopt -u dotglob nullglob
			rmdir "${pxr_src}" 2>/dev/null || true
			rmdir "${ED}/usr/lib/python" 2>/dev/null || true
		fi

		local pth_file="${T}/openusd.pth"
		# After the relocation above, a single multilib-correct root is sufficient.
		printf '%s\n' \
			"${EPREFIX}/usr/$(get_libdir)/python" \
			> "${pth_file}" || die

		insinto "$(python_get_sitedir)"
		doins "${pth_file}"

		[[ -d "${py_root}" ]] && python_optimize "${py_root}"
	fi
}
