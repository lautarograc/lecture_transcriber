#!/bin/sh
set -e

ROOT="$(CDPATH='' cd "$(dirname "$0")/.." && pwd -P)"
OUT="$ROOT/priv/bin/linux"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$OUT"

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

echo "-> done: $OUT"
echo "note: tesseract is NOT bundled (its dependency chain isn't worth"
echo "vendoring by hand) -- install tesseract-ocr on the target system,"
echo "or pass --tesseract-bin to point at your own build."
