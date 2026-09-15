#!/bin/sh
set -e

# Requires: a Debian/Ubuntu-family build host (uses apt-get download), plus
# git, cmake, a C/C++ toolchain, curl, and pkg-config.

ROOT="$(CDPATH='' cd "$(dirname "$0")/.." && pwd -P)"
OUT="$ROOT/priv/bin/linux"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$OUT" "$ROOT/priv/tessdata"

echo "-> fetching static ffmpeg (Linux x86_64, pinned stable release)..."
# Deliberately NOT using BtbN's "latest" build: it tracks ffmpeg git master
# (a nightly build), and a master snapshot was found to silently break the
# scene-change detection filter's score scale (see commit history). This
# build is tied to a real numbered ffmpeg release instead.
curl -sL -o "$WORK/ffmpeg.tar.xz" \
  https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar xf "$WORK/ffmpeg.tar.xz" -C "$WORK"
cp "$WORK"/ffmpeg-*-amd64-static/ffmpeg "$OUT/ffmpeg"
chmod +x "$OUT/ffmpeg"

echo "-> building whisper.cpp statically..."
git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git "$WORK/whisper.cpp"
cmake -B "$WORK/whisper.cpp/build" -S "$WORK/whisper.cpp" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
cmake --build "$WORK/whisper.cpp/build" -j"$(nproc)" --target whisper-cli
cp "$WORK/whisper.cpp/build/bin/whisper-cli" "$OUT/whisper-cli"
chmod +x "$OUT/whisper-cli"

echo "-> building tesseract statically (curl/archive support disabled)..."
# tesseract's shared-lib build pulls in ~50 libraries via libcurl (a full
# TLS/Kerberos/LDAP stack it only needs to fetch training data over the
# network -- irrelevant here). Building with DISABLE_CURL/DISABLE_ARCHIVE
# and static image libs drops that to the same base libc/libstdc++ set as
# ffmpeg and whisper-cli above.
PREFIX="$WORK/tess-prefix/usr"
mkdir -p "$WORK/tess-pkgs"
cd "$WORK/tess-pkgs"
apt-get download \
  libpng-dev libjpeg-turbo8-dev zlib1g-dev libwebp-dev libgif-dev libtiff-dev \
  libopenjp2-7-dev libjbig-dev liblzma-dev libdeflate-dev libsharpyuv-dev \
  libzstd-dev liblerc-dev >/dev/null
for f in *.deb; do dpkg -x "$f" "$WORK/tess-prefix/"; done

LIBDIR="$PREFIX/lib/x86_64-linux-gnu"
find "$LIBDIR" -name "*.so*" -delete
find "$LIBDIR" -name "*.la" -delete 2>/dev/null || true

# libwebp's CMake package only ships SHARED imported targets (no static
# variant) and hardcodes .so paths that no longer exist -- patch them to
# point at the static .a libs we kept instead of deleting the package
# outright (deleting it breaks tesseract's own find_package(Leptonica)
# resolution later, since it walks this dependency graph).
WEBP_CMAKE="$LIBDIR/cmake/WebP"
sed -i 's/SHARED IMPORTED/STATIC IMPORTED/' "$WEBP_CMAKE/WebPTargets.cmake"
sed -i -E 's|(_IMPORT_PREFIX\}/lib/x86_64-linux-gnu/lib[A-Za-z]+)\.so[0-9.]*|\1.a|g' \
  "$WEBP_CMAKE/WebPTargets-none.cmake"
sed -i '/IMPORTED_SONAME_NONE/d' "$WEBP_CMAKE/WebPTargets-none.cmake"

echo "-> building leptonica statically..."
git clone --depth 1 --branch 1.85.0 https://github.com/DanBloomberg/leptonica.git "$WORK/leptonica"
PKG_CONFIG_PATH="$LIBDIR/pkgconfig" \
  cmake -B "$WORK/leptonica/build" -S "$WORK/leptonica" -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF -DCMAKE_PREFIX_PATH="$PREFIX" -DCMAKE_FIND_LIBRARY_SUFFIXES=".a"
cmake --build "$WORK/leptonica/build" -j"$(nproc)"
cmake --install "$WORK/leptonica/build" --prefix "$PREFIX"

# find_package(Leptonica CONFIG) would find this and pull in the same
# dangling WebP::webp target reference -- remove it so tesseract's build
# falls back to the pkg-config lept.pc we fix up below instead.
rm -rf "$PREFIX/lib/cmake/leptonica"

# Rewrite lept.pc: drop Requires.private (which makes CMake try to
# synthesize targets like WebP::webp instead of just linking flags) and
# inline the fully-resolved static link flags into Libs.private instead.
LEPT_PC=$(find "$PREFIX/lib/pkgconfig" -name "lept*.pc" | head -1)
STATIC_LIBS=$(PKG_CONFIG_PATH="$LIBDIR/pkgconfig" pkg-config --static --libs \
  zlib libpng libjpeg libtiff-4 libwebp libwebpmux libopenjp2)
cat > "$LEPT_PC" <<EOF
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: leptonica
Description: An open source C library for efficient image processing and image analysis operations
Version: 1.85.0
Libs: -L\${libdir} -lleptonica
Libs.private: -L$LIBDIR $STATIC_LIBS -lgif
Cflags: -I\${includedir} -I\${includedir}/leptonica
EOF
ln -sf "$(basename "$LEPT_PC")" "$PREFIX/lib/pkgconfig/lept.pc"

# CMake's pkg_check_modules(Leptonica ...) call (unlike a plain pkg-config
# invocation) doesn't request static resolution by default, so it would
# drop everything in Libs.private above. Force it via a wrapper.
cat > "$WORK/pkg-config-static" <<'PKGEOF'
#!/bin/sh
exec /usr/bin/pkg-config --static "$@"
PKGEOF
chmod +x "$WORK/pkg-config-static"

git clone --depth 1 --branch 5.5.0 https://github.com/tesseract-ocr/tesseract.git "$WORK/tesseract"
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$LIBDIR/pkgconfig" \
  cmake -B "$WORK/tesseract/build" -S "$WORK/tesseract" -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF -DDISABLE_ARCHIVE=ON -DDISABLE_CURL=ON -DBUILD_TRAINING_TOOLS=OFF \
    -DCMAKE_PREFIX_PATH="$PREFIX" -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DPKG_CONFIG_EXECUTABLE="$WORK/pkg-config-static"
cmake --build "$WORK/tesseract/build" -j"$(nproc)" --target tesseract
cp "$WORK/tesseract/build/bin/tesseract" "$OUT/tesseract"
chmod +x "$OUT/tesseract"

echo "-> fetching English trained data..."
cd "$WORK"
apt-get download tesseract-ocr-eng >/dev/null
dpkg -x tesseract-ocr-eng*.deb "$WORK/tessdata-pkg"
cp "$WORK"/tessdata-pkg/usr/share/tesseract-ocr/*/tessdata/eng.traineddata "$ROOT/priv/tessdata/"

echo "-> done: $OUT"
echo "note: ffmpeg above is built with --enable-gpl -- if you redistribute"
echo "this binary, GPL's source-availability terms apply to it."
