EAPI=8

inherit cmake multilib

DESCRIPTION="MaterialX is an open standard for material and look-development content"
HOMEPAGE="https://github.com/AcademySoftwareFoundation/MaterialX"
SRC_URI="https://github.com/AcademySoftwareFoundation/MaterialX/archive/refs/tags/v${PV}.tar.gz -> MaterialX-${PV}.tar.gz"

S="${WORKDIR}/MaterialX-${PV}"

LICENSE="Apache-2.0"
SLOT="0/1"
KEYWORDS="~amd64"

PATCHES=(
	"${FILESDIR}/${P}-install-layout.patch"
)

BDEPEND="
	>=dev-build/cmake-3.26
"

RDEPEND="
	virtual/opengl
	x11-libs/libX11
"

DEPEND="${RDEPEND}"

DOCS=(
	CHANGELOG.md
	README.md
	THIRD-PARTY.md
	LICENSE
)

src_configure() {
	local mycmakeargs=(
		# Match OpenUSD build_usd.py defaults
		-DMATERIALX_BUILD_SHARED_LIBS=ON
		-DMATERIALX_BUILD_TESTS=OFF

		# Gentoo install layout
		-DMATERIALX_INSTALL_LIB_PATH="$(get_libdir)"
		-DMATERIALX_INSTALL_STDLIB_PATH="share/materialx/libraries"
		-DMATERIALX_INSTALL_RESOURCES_PATH="share/materialx/resources"

		# Avoid extra components we don't need for OpenUSD
		-DMATERIALX_BUILD_PYTHON=OFF
		-DMATERIALX_BUILD_VIEWER=OFF
		-DMATERIALX_BUILD_GRAPH_EDITOR=OFF
		-DMATERIALX_BUILD_DOCS=OFF
		-DMATERIALX_BUILD_JS=OFF
		-DMATERIALX_BUILD_BENCHMARK_TESTS=OFF
		-DMATERIALX_TEST_RENDER=OFF
	)

	cmake_src_configure
}
