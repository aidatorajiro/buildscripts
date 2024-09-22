#!/bin/bash

if [ "$(uname)" != "Darwin" ]; then
	errormsg "This buildscript requires macOS!"
fi

# abort on error
set -e

export WORKSPACE=$PWD

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../shared/import.sh

# Number of CPU
nproc=$(getconf _NPROCESSORS_ONLN)

test_ccache

if [ ! -f .patches-applied ]; then
	echo "Patching libraries"

	patches_common

	touch .patches-applied
fi

function set_build_flags() {
	# $1: Arch (either x86_64 or arm64)
	# $2: host for configure
	# $3: additional cpp flags
	CLANG=`xcrun -f --sdk macosx clang`
	CLANGXX=`xcrun -f --sdk macosx clang++`
	ARCH="-arch $1"
	SDKPATH=`xcrun -sdk macosx --show-sdk-path`
	PLATFORM_PREFIX="$WORKSPACE/$1"

	echo "Preparing for $1 arch"

	export PATH=$PLATFORM_PREFIX/bin:$PATH
	export CC="$CLANG $ARCH"
	export CXX="$CLANGXX $ARCH"
	export CFLAGS="-g -O2 -mmacosx-version-min=10.9 -isysroot $SDKPATH $3"
	export CXXFLAGS=$CFLAGS
	# ICU include is required for arm64
	export CPPFLAGS="-I$PLATFORM_PREFIX/include -I$WORKSPACE/icu/source/common"
	export LDFLAGS="-L$PLATFORM_PREFIX/lib $ARCH -mmacosx-version-min=10.9 -isysroot $SDKPATH"

	export MACOSX_DEPLOYMENT_TARGET=10.9
	export CMAKE_EXTRA_ARGS="-DCMAKE_OSX_ARCHITECTURES=$1"

	export PKG_CONFIG_PATH=$PLATFORM_PREFIX/lib/pkgconfig
	export PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH
	export TARGET_HOST="$2"

	mkdir -p $PLATFORM_PREFIX
	make_meson_cross "${TARGET_HOST}" > $PLATFORM_PREFIX/meson-cross.txt
}

function build() {
	cd "$WORKSPACE"

	install_lib_cmake $ZLIB_DIR $ZLIB_ARGS
	install_lib_cmake $LIBPNG_DIR $LIBPNG_ARGS
	install_lib_cmake $FREETYPE_DIR $FREETYPE_ARGS -DFT_DISABLE_HARFBUZZ=ON
	install_lib_meson $HARFBUZZ_DIR $HARFBUZZ_ARGS
	install_lib_cmake $FREETYPE_DIR $FREETYPE_ARGS -DFT_DISABLE_HARFBUZZ=OFF
	install_lib_meson $PIXMAN_DIR $PIXMAN_ARGS -Da64-neon=disabled
	install_lib_cmake $EXPAT_DIR $EXPAT_ARGS
	install_lib $LIBOGG_DIR $LIBOGG_ARGS
	install_lib $LIBVORBIS_DIR $LIBVORBIS_ARGS
	install_lib $MPG123_DIR $MPG123_ARGS
	install_lib $LIBSNDFILE_DIR $LIBSNDFILE_ARGS
	install_lib_cmake $LIBXMP_LITE_DIR $LIBXMP_LITE_ARGS
	install_lib $SPEEXDSP_DIR $SPEEXDSP_ARGS
	install_lib_cmake $WILDMIDI_DIR $WILDMIDI_ARGS
	install_lib $OPUS_DIR $OPUS_ARGS
	install_lib $OPUSFILE_DIR $OPUSFILE_ARGS
	install_lib_cmake $FLUIDSYNTH_DIR $FLUIDSYNTH_ARGS
	install_lib_cmake $NLOHMANNJSON_DIR $NLOHMANNJSON_ARGS
	install_lib_meson $INIH_DIR $INIH_ARGS
	install_lib $LHASA_DIR $LHASA_ARGS
	install_lib_cmake $FMT_DIR $FMT_ARGS
	install_lib_icu_cross
	icu_force_data_install
	install_lib $SDL2_DIR $SDL2_ARGS --disable-assembly
	install_lib_cmake $FREEIMAGE_DIR $FREEIMAGE_ARGS
	install_lib_liblcf
}

export MAKEFLAGS="-j${nproc:-2}"

install_lib_icu_native

set_build_flags "x86_64" "x86_64-apple-darwin"
build
set_build_flags "arm64" "aarch64-apple-darwin"
build
